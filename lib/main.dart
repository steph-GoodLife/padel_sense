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
  String hitType = '-'; // "Coup droit" ou "Revers"
  List<String> allHits = []; // Pour récap éventuel
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
              int rawX = _toSignedInt16(value[0], value[1]);
              int rawY = _toSignedInt16(value[2], value[3]);
              int rawZ = _toSignedInt16(value[4], value[5]);

              double newAccZ = rawZ / 32768.0 * 16;
              double newAccY = rawY / 32768.0 * 16;

              final now = DateTime.now().millisecondsSinceEpoch;

              if ((newAccZ - lastAccZ).abs() > threshold && now - lastHitTime > 500) {
                hitCount++;
                lastHitTime = now;

                sessionSpeeds.add(speed); // Ajout à chaque frappe

                // Classification simple selon l'axe
                if (newAccZ > 0) {
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
      coupsDroit: coupsDroit,
      revers: revers,
    );

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

            // Vitesse estimée
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

            const Spacer(),

            Center(
              child: ElevatedButton.icon(
                onPressed: () {
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

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SessionRecapScreen(session: session),
                    ),
                  );
                },
                icon: const Icon(Icons.stop),
                label: const Text("Terminer la session"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 16),
                  textStyle: const TextStyle(fontSize: 18),
                ),
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
  final int coupsDroit;
  final int revers;

  SessionData({
    required this.date,
    required this.frappes,
    required this.vitesseMoyenne,
    required this.zoneImpact,
    required this.scorePerformance,
    required this.vitesses,
    required this.coupsDroit,
    required this.revers,
  });
}

//-----------------------------------------
// nouvelles page - moyenne de la session
//-----------------------------------------

// class SessionRecapScreen extends StatelessWidget {
//   final SessionData session;

//   const SessionRecapScreen({super.key, required this.session});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Résumé de la session')),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text('📅 Date : ${session.date.toLocal()}',
//                 style: const TextStyle(fontSize: 18)),
//             const SizedBox(height: 10),
//             Text('🎾 Frappes totales : ${session.frappes}',
//                 style: const TextStyle(fontSize: 18)),
//             Text('👉 Coup droit : ${session.coupsDroit}',
//                 style: const TextStyle(fontSize: 16)),
//             Text('👈 Revers : ${session.revers}',
//                 style: const TextStyle(fontSize: 16)),
//             const SizedBox(height: 20),
//             Text('⚡ Vitesse moyenne : ${session.vitesseMoyenne.toStringAsFixed(1)} km/h',
//                 style: const TextStyle(fontSize: 18)),
//             Text('🎯 Zone impact : ${session.zoneImpact}',
//                 style: const TextStyle(fontSize: 16)),
//             Text('📈 Score de performance : ${session.scorePerformance}%',
//                 style: const TextStyle(fontSize: 16)),
//             const SizedBox(height: 20),
//             const Text('📊 Détail des vitesses :',
//                 style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//             const SizedBox(height: 10),
//             Expanded(
//               child: ListView.builder(
//                 itemCount: session.vitesses.length,
//                 itemBuilder: (context, index) {
//                   return Text('• ${session.vitesses[index].toStringAsFixed(1)} km/h');
//                 },
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

class SessionRecapScreen extends StatelessWidget {
  final SessionData session;

  const SessionRecapScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Image de fond
          SizedBox.expand(
            child: Image.asset(
              'assets/bg-resume.png',
              fit: BoxFit.cover,
            ),
          ),
          // Contenu semi-transparent au-dessus
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🔙 Bouton retour
                  Align(
                    alignment: Alignment.topLeft,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                  ),
                  const Text(
                    "Résumé de la session",
                    style: TextStyle(
                      fontSize: 26,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _statCard("📅 Date", session.date.toLocal().toString().split(' ')[0]),
                  _statCard("🎾 Frappes", session.frappes.toString()),
                  _statCard("💥 Coups droits", session.coupsDroit.toString()),
                  _statCard("↩️ Revers", session.revers.toString()),
                  _statCard("🎯 Zone impact", session.zoneImpact),
                  _statCard("🚀 Vitesse moyenne", "${session.vitesseMoyenne.toStringAsFixed(1)} km/h"),

                  const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("📊 Moyenne par 5 frappes :",
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          ...calculateGroupedAverages(session.vitesses, 5).asMap().entries.map(
                            (entry) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text(
                                "Frappes ${entry.key * 5 + 1}-${(entry.key + 1) * 5} : ${entry.value.toStringAsFixed(1)} km/h",
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

//Calcul par 5 coups
  List<double> calculateGroupedAverages(List<double> speeds, int groupSize) {
  List<double> averages = [];
  for (int i = 0; i < speeds.length; i += groupSize) {
    final group = speeds.skip(i).take(groupSize).toList();
    if (group.isNotEmpty) {
      final avg = group.reduce((a, b) => a + b) / group.length;
      averages.add(avg);
    }
  }
  return averages;
}

  Widget _statCard(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white, fontSize: 16)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}