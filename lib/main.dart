import 'package:flutter/material.dart';
import 'package:flutter/animation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';
import 'dart:typed_data';

void main() {
  runApp(const PadalyticsApp());
}

class PadalyticsApp extends StatelessWidget {
  const PadalyticsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashScreen(),
    );
  }
}

// ---------------------------
// Splash Screen avec animation
// ---------------------------

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();

    Timer(const Duration(seconds: 3), () {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const HomeScreen(),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: FadeTransition(
          opacity: _animation,
          child: Image.asset('assets/splash.png', width: 250),
        ),
      ),
    );
  }
}

// ---------------------------
// Home Screen
// ---------------------------

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Padalytics')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BluetoothRealScreen()),
                );
              },
              child: const Text('🔍 Scanner ma raquette'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SessionHistoryScreen()),
                );
              },
              child: const Text('📈 Historique des sessions'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------
// Bluetooth Real Screen (Scan BLE réel)
// ---------------------------

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

// ---------------------------
// Session History Screen (mocked)
// ---------------------------

class SessionHistoryScreen extends StatelessWidget {
  const SessionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> fakeSessions = [
      {"date": "26/04/2025", "frappes": "120", "puissance": "54 km/h"},
      {"date": "25/04/2025", "frappes": "98", "puissance": "49 km/h"},
      {"date": "24/04/2025", "frappes": "110", "puissance": "52 km/h"},
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Historique Sessions')),
      body: ListView.builder(
        itemCount: fakeSessions.length,
        itemBuilder: (context, index) {
          final session = fakeSessions[index];
          return ListTile(
            title: Text('Date : ${session['date']}'),
            subtitle: Text('Frappes : ${session['frappes']} | Puissance : ${session['puissance']}'),
          );
        },
      ),
    );
  }
}

// ---------------------------
// Device Data Screen (lecture données BLE)
// ---------------------------

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
  int lastHitTime = 0;
  double lastAccZ = 0;
  final double threshold = 3.5;

  List<double> sessionSpeeds = [];

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
              }

              lastAccZ = newAccZ;

              setState(() {
                accZ = newAccZ;
                speed = (accZ * 9.81) * 3.6;
                sessionSpeeds.add(speed);
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
    return "Z"; // À affiner plus tard selon heuristique
  }

  int calculateScore() {
    return (calculateAverageSpeed() / 80 * 100).clamp(0, 100).toInt();
  }

  void endSession() {
    final session = SessionData(
      date: DateTime.now(),
      frappes: hitCount,
      vitesseMoyenne: calculateAverageSpeed(),
      zoneImpact: mostFrequentZone(),
      scorePerformance: calculateScore(),
      vitesses: sessionSpeeds,
    );

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SessionRecapScreen(session: session)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Session en direct')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('🎾 Frappes détectées : $hitCount', style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 20),
            Text('📐 Accélération Z : ${accZ.toStringAsFixed(2)} G', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 20),
            Text('🚀 Vitesse estimée : ${speed.toStringAsFixed(1)} km/h', style: const TextStyle(fontSize: 16)),
            const Spacer(),
            Center(
              child: ElevatedButton(
                onPressed: endSession,
                child: const Text('⏹ Terminer la session'),
              ),
            )
          ],
        ),
      ),
    );
  }
}

//------------------------------------------
// stockage en memoire d'une session
//------------------------------------------

class SessionData {
  final DateTime date;
  final int frappes;
  final double vitesseMoyenne;
  final String zoneImpact;
  final int scorePerformance;
  final List<double> vitesses;

  SessionData({
    required this.date,
    required this.frappes,
    required this.vitesseMoyenne,
    required this.zoneImpact,
    required this.scorePerformance,
    required this.vitesses,
  });
}

//-----------------------------------------
// nouvelles page - moyenne de la session
//-----------------------------------------

class SessionRecapScreen extends StatelessWidget {
  final SessionData session;

  const SessionRecapScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Résumé de la session')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📅 ${session.date.toLocal()}'),
            const SizedBox(height: 10),
            Text('🎾 Frappes : ${session.frappes}'),
            Text('⚡ Vitesse moyenne : ${session.vitesseMoyenne.toStringAsFixed(1)} km/h'),
            Text('🎯 Zone impact : ${session.zoneImpact}'),
            Text('📈 Score : ${session.scorePerformance}%'),
            const SizedBox(height: 20),
            const Text('📊 Détail des vitesses :'),
            ...session.vitesses.map((v) => Text('• ${v.toStringAsFixed(1)} km/h')).toList(),
          ],
        ),
      ),
    );
  }
}