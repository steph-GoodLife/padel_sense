import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/session_data.dart';
import 'session_recap_screen.dart';

class DeviceDataScreen extends StatefulWidget {
  final BluetoothDevice device;

  const DeviceDataScreen({super.key, required this.device});

  @override
  State<DeviceDataScreen> createState() => _DeviceDataScreenState();
}

class _DeviceDataScreenState extends State<DeviceDataScreen> {
  int hitCount = 0;
  double accZ = 0;
  double speed = 0;
  String hitType = '-';
  int lastHitTime = 0;
  double lastAccZ = 0;
  final double threshold = 3.5;

  List<double> sessionSpeeds = [];
  int coupsDroit = 0;
  int revers = 0;

  @override
  void initState() {
    super.initState();
    _listenToData();
  }

  void _listenToData() async {
    List<BluetoothService> services = await widget.device.discoverServices();
    for (var service in services) {
      for (var charac in service.characteristics) {
        if (charac.properties.notify) {
          await charac.setNotifyValue(true);
          charac.value.listen((value) {
            if (value.length >= 6) {
              int rawZ = _toSignedInt16(value[4], value[5]);
              double newAccZ = rawZ / 32768.0 * 16;

              final now = DateTime.now().millisecondsSinceEpoch;

              if ((newAccZ - lastAccZ).abs() > threshold && now - lastHitTime > 500) {
                hitCount++;
                lastHitTime = now;
                sessionSpeeds.add(speed);

                if (rawZ > 0) {
                  coupsDroit++;
                  hitType = "Coup droit";
                } else {
                  revers++;
                  hitType = "Revers";
                }
              }

              lastAccZ = newAccZ;

              setState(() {
                accZ = newAccZ;
                speed = (accZ * 9.81) * 3.6;
              });
            }
          });
        }
      }
    }
  }

  int _toSignedInt16(int low, int high) {
    int value = (high << 8) | low;
    return value >= 0x8000 ? value - 0x10000 : value;
  }

  double calculateAverageSpeed() {
    if (sessionSpeeds.isEmpty) return 0;
    return sessionSpeeds.reduce((a, b) => a + b) / sessionSpeeds.length;
  }

  String mostFrequentZone() {
    return "Z"; // À affiner plus tard si besoin
  }

  int calculateScore() {
    return (calculateAverageSpeed() / 80 * 100).clamp(0, 100).toInt();
  }

  Future<void> saveSessionToFirestore(SessionData session) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    print("📝 Enregistrement de la session en cours...");
    await FirebaseFirestore.instance.collection('sessions').add({
      'userId': user.uid,
      'date': Timestamp.fromDate(session.date),
      'frappes': session.frappes,
      'vitesseMoyenne': session.vitesseMoyenne,
      'zoneImpact': session.zoneImpact,
      'scorePerformance': session.scorePerformance,
      'vitesses': session.vitesses,
      'coupsDroit': session.coupsDroit,
      'revers': session.revers,
    });
    print("✅ Session enregistrée avec succès");
  }

  Future<void> endSession() async {
    print("📍 Bouton 'Terminer la session' déclenché");

    final session = SessionData(
      date: DateTime.now(),
      frappes: hitCount,
      vitesseMoyenne: calculateAverageSpeed(),
      zoneImpact: mostFrequentZone(),
      scorePerformance: calculateScore(),
      vitesses: sessionSpeeds,
      coupsDroit: coupsDroit,
      revers: revers,
    );

    await saveSessionToFirestore(session);

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SessionRecapScreen(session: session)),
    );
  }

  Color getSpeedColor(double speed) {
    if (speed < 40) return Colors.green;
    if (speed < 65) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101010),
      appBar: AppBar(
        title: const Text('Session en direct'),
        backgroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('🎾 Frappes détectées : $hitCount',
                style: const TextStyle(fontSize: 22, color: Colors.white)),
            const SizedBox(height: 20),
            Text('📐 Accélération Z : ${accZ.toStringAsFixed(2)} G',
                style: const TextStyle(fontSize: 18, color: Colors.white70)),
            const SizedBox(height: 30),
            Center(
              child: Column(
                children: [
                  Text('🚀 ${speed.toStringAsFixed(1)} km/h',
                      style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: LinearProgressIndicator(
                      value: (speed / 100).clamp(0.0, 1.0),
                      minHeight: 20,
                      valueColor: AlwaysStoppedAnimation<Color>(getSpeedColor(speed)),
                      backgroundColor: Colors.white24,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Text('🧭 Dernier coup détecté : $hitType',
                style: const TextStyle(fontSize: 18, color: Colors.white70)),
            const SizedBox(height: 40),
            SafeArea(
              child: Center(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await endSession();
                  },
                  icon: const Icon(Icons.stop),
                  label: const Text("Terminer la session"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 16),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      // floatingActionButton: FloatingActionButton(
      //   onPressed: () {
      //     Navigator.push(
      //       context,
      //       MaterialPageRoute(builder: (_) => const SettingsScreen()),
      //     );
      //   },
      //   child: const Icon(Icons.settings),
      // ),
    );
  }
}