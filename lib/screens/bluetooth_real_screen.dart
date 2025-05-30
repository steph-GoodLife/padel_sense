import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'device_data_screen.dart';

class BluetoothRealScreen extends StatefulWidget {
  const BluetoothRealScreen({super.key});

  @override
  State<BluetoothRealScreen> createState() => _BluetoothRealScreenState();
}

class _BluetoothRealScreenState extends State<BluetoothRealScreen> {
  final List<ScanResult> scanResults = [];

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  void _startScan() async {
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
    FlutterBluePlus.scanResults.listen((results) {
      setState(() {
        scanResults.clear();
        scanResults.addAll(results);
      });
    });
  }

  void _connectToDevice(BluetoothDevice device) async {
    await FlutterBluePlus.stopScan(); // Stop le scan
    await device.connect(); // Essaie de se connecter
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DeviceDataScreen(device: device)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan BLE (Réel)')),
      body: ListView.builder(
        itemCount: scanResults.length,
        itemBuilder: (context, index) {
          final result = scanResults[index];
          return ListTile(
            title: Text(result.device.name.isNotEmpty ? result.device.name : '(Inconnu)'),
            subtitle: Text(result.device.id.id),
            trailing: Text('${result.rssi} dBm'),
            onTap: () => _connectToDevice(result.device),
          );
        },
      ),
    );
  }
}