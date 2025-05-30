import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final user = FirebaseAuth.instance.currentUser;
  String? profileImageUrl;
  String? displayName;
  bool isLoading = true;
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();

      if (doc.exists) {
        final data = doc.data()!;
        profileImageUrl = data['profileImage'];
        displayName = data['displayName'];
        _nameController.text = displayName ?? '';
      }
    } catch (e) {
      debugPrint("❌ Erreur lors du chargement des données utilisateur : $e");
    }

    setState(() => isLoading = false);
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile == null) {
      print("❌ Aucune image sélectionnée.");
      return;
    }

    final file = File(pickedFile.path);
    final ref = FirebaseStorage.instance.ref().child('profile_images/${user!.uid}.jpg');

    try {
      print("⬆️ Tentative d'envoi à Firebase Storage...");
      await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
      print("✅ Fichier uploadé avec succès");

      final url = await ref.getDownloadURL();
      print("🔗 URL obtenue : $url");

      await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
        'profileImage': url,
      }, SetOptions(merge: true));

      setState(() {
        profileImageUrl = url;
      });

      print("✅ URL enregistrée dans Firestore");
    } catch (e) {
      print("❌ Erreur d'upload Firebase Storage : $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Erreur lors de l'upload de l'image")),
      );
    }
  }

  Future<void> _deleteProfileImage() async {
    if (user == null) return;

    try {
      final ref = FirebaseStorage.instance.ref().child('profile_images/${user!.uid}.jpg');
      await ref.delete();
    } catch (e) {
      debugPrint("⚠️ Suppression échouée (peut-être image déjà supprimée) : $e");
    }

    await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
      'profileImage': FieldValue.delete(),
    });

    setState(() {
      profileImageUrl = null;
    });
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Changer la photo'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadImage();
              },
            ),
            if (profileImageUrl != null)
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Supprimer la photo'),
                onTap: () {
                  Navigator.pop(context);
                  _deleteProfileImage();
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateDisplayName() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty || user == null) return;

    await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
      'displayName': newName,
    }, SetOptions(merge: true));

    setState(() {
      displayName = newName;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("✅ Nom mis à jour")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mon profil")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _showPhotoOptions,
                    child: CircleAvatar(
                      radius: 50,
                      backgroundImage: profileImageUrl != null
                          ? NetworkImage(profileImageUrl!)
                          : const AssetImage('assets/default_profil.png') as ImageProvider,
                      child: profileImageUrl == null
                          ? const Icon(Icons.camera_alt, size: 30, color: Colors.white70)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    displayName != null
                        ? "Nom actuel : $displayName"
                        : "Nom non défini",
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 20),

                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: "Modifier le nom",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),

                  ElevatedButton.icon(
                    onPressed: _updateDisplayName,
                    icon: const Icon(Icons.save),
                    label: const Text("Enregistrer le nom"),
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> requestPermission() async {
    final status = await Permission.photos.request();
    print("📷 Permission galerie : $status");
  }
}