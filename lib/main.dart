import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: BluetoothScreen(),
    );
  }
}

class BluetoothScreen extends StatefulWidget {
  const BluetoothScreen({super.key});

  @override
  State<BluetoothScreen> createState() => _BluetoothScreenState();
}

class _BluetoothScreenState extends State<BluetoothScreen> {
  final Map<String, ScanResult> _filteredDevices = {};
  final String targetUuid = "0000ffe0-0000-1000-8000-00805f9b34fb"; // UUID WT901 BLE

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  void _startScan() async {
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

    FlutterBluePlus.scanResults.listen((results) {
      for (var result in results) {
        final id = result.device.remoteId.str;
        final uuids = result.advertisementData.serviceUuids;

        // Affiche tous les périphériques pour debug
        print('🔍 ${result.device.name} - $id - UUIDs: $uuids');

        // Garde uniquement ceux qui annoncent l'UUID cible
        if (uuids.contains(targetUuid)) {
          _filteredDevices[id] = result;
        }
      }
      setState(() {});
    });
  }

  void _connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect();
      print("✅ Connecté à ${device.platformName}");
      // ici tu peux ajouter une navigation ou lecture des services/caractéristiques
    } catch (e) {
      print("❌ Erreur de connexion : $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan WT901 BLE')),
      body: _filteredDevices.isEmpty
          ? const Center(child: Text("Aucun périphérique trouvé..."))
          : ListView(
              children: _filteredDevices.values.map((r) {
                return ListTile(
                  title: Text(r.device.name.isNotEmpty ? r.device.name : "(inconnu)"),
                  subtitle: Text(r.device.remoteId.str),
                  trailing: ElevatedButton(
                    onPressed: () => _connectToDevice(r.device),
                    child: const Text("Connecter"),
                  ),
                );
              }).toList(),
            ),
    );
  }
}
