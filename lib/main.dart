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
  List<int> receivedData = [];

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
            setState(() {
              receivedData = value;
            });
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Données reçues')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => LiveSessionScreen(device: widget.device)),
                );
              },
              child: const Text("🎾 Démarrer la session"),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: receivedData.isEmpty
                  ? const Center(child: Text('⏳ En attente de données...'))
                  : ListView.builder(
                      itemCount: receivedData.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          title: Text('Octet $index'),
                          trailing: Text('${receivedData[index]}'),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class LiveSessionScreen extends StatefulWidget {
  final BluetoothDevice device;

  const LiveSessionScreen({super.key, required this.device});

  @override
  State<LiveSessionScreen> createState() => _LiveSessionScreenState();
}

class _LiveSessionScreenState extends State<LiveSessionScreen> {
  int hitCount = 0;
  double maxPower = 0;
  String lastAxis = '-';
  DateTime lastHitTime = DateTime.now().subtract(const Duration(seconds: 1));

  @override
  void initState() {
    super.initState();
    _startTracking();
  }

  void _startTracking() async {
    List<BluetoothService> services = await widget.device.discoverServices();
    for (var service in services) {
      for (var charac in service.characteristics) {
        if (charac.properties.notify) {
          await charac.setNotifyValue(true);
          charac.value.listen((value) {
            if (value.length >= 6) {
              final data = ByteData.sublistView(Uint8List.fromList(value));

              int accX = data.getInt16(0, Endian.little);
              int accY = data.getInt16(2, Endian.little);
              int accZ = data.getInt16(4, Endian.little);

              double power = accX.abs().toDouble() + accY.abs().toDouble() + accZ.abs().toDouble();

              if (power > 5000) {
                final now = DateTime.now();
                if (now.difference(lastHitTime).inMilliseconds > 300) {
                  setState(() {
                    hitCount++;
                    lastHitTime = now;

                    if (power > maxPower) {
                      maxPower = power;
                    }

                    if (accX.abs() > accY.abs() && accX.abs() > accZ.abs()) {
                      lastAxis = "X";
                    } else if (accY.abs() > accX.abs() && accY.abs() > accZ.abs()) {
                      lastAxis = "Y";
                    } else {
                      lastAxis = "Z";
                    }
                  });
                }
              }
            }
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("📊 Session en cours")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Frappes détectées : $hitCount", style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 12),
            Text("Puissance max (approx.) : ${maxPower.toInt()}", style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 12),
            Text("Dernier axe impacté : $lastAxis", style: const TextStyle(fontSize: 18)),
            const Spacer(),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("⏹ Terminer la session"),
            ),
          ],
        ),
      ),
    );
  }
}
