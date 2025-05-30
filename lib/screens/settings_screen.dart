import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'login_screen.dart';
import 'user_profile_screen.dart';
// TODO : importer et utiliser l’écran profil utilisateur quand il sera créé
// TODO : gérer le retour à la session en cours

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Options")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },
              child: const Text("Se déconnecter"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UserProfileScreen()),
                );
              },
              child: const Text("Mon profil"),
            ),
            ElevatedButton(
              onPressed: () {
                //TODO Navigator.of(context).push(
                 //MaterialPageRoute(builder: (_) => const DeviceDataScreen(device: /* ton device actuel ici */)),
                //);
              },
              child: const Text("Retour à la session en cours"),
            ),
          ],
        ),
      ),
    );
  }
}

// test test test enregistrement session isolé... pourra être effacé si ok
// class FirestoreTestScreen extends StatelessWidget {
//   const FirestoreTestScreen({super.key});

//   Future<void> saveFakeSessionToFirestore() async {
//     final user = FirebaseAuth.instance.currentUser;
//     if (user == null) {
//       print("❌ Aucun utilisateur connecté");
//       return;
//     }

//     print("🧪 Tentative d’enregistrement d’une session de test...");

//     await FirebaseFirestore.instance.collection('sessions').add({
//       'userId': user.uid,
//       'date': Timestamp.now(),
//       'frappes': 10,
//       'vitesseMoyenne': 55.2,
//       'zoneImpact': 'Z',
//       'scorePerformance': 88,
//       'vitesses': [45.0, 55.0, 65.0],
//       'coupsDroit': 6,
//       'revers': 4,
//     });

//     print("✅ Session test enregistrée avec succès");
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text("Test Firestore")),
//       body: Center(
//         child: ElevatedButton(
//           onPressed: saveFakeSessionToFirestore,
//           child: const Text("Enregistrer une session test"),
//         ),
//       ),
//     );
//   }
// }