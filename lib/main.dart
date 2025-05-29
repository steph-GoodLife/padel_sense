import 'package:flutter/material.dart';
import 'package:flutter/animation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('onboarding_seen', false);

  runApp(const PadalyticsApp());
}

class PadalyticsApp extends StatelessWidget {
  const PadalyticsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Padalytics',
      home: const AuthGate(), // 👈 ici uniquement AuthGate
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleNavigation();
    });
  }

  Future<void> _handleNavigation() async {
    await _askPermissions();
    await Future.delayed(const Duration(seconds: 2));

    final prefs = await SharedPreferences.getInstance();
    final onboardingSeen = prefs.getBool('onboarding_seen') ?? false;
    final currentUser = FirebaseAuth.instance.currentUser;

    if (!mounted) return; // ✅ très important

    Widget nextScreen;
    if (!onboardingSeen) {
      nextScreen = const OnboardingScreen();
    } else {
      nextScreen = currentUser != null ? const HomeScreen() : const WelcomeScreen();
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => nextScreen),
    );
  }

  Future<void> _askPermissions() async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
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
            const Text(
              '🏠 Bienvenue sur HomeScreen',
              style: TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 20),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          );
        },
        child: const Icon(Icons.settings),
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
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Center(child: Text("Utilisateur non connecté"));
    }

    return Scaffold(
      backgroundColor: const Color(0xFF101010),
      appBar: AppBar(
        title: const Text('🏅 Mes sessions'),
        backgroundColor: Colors.black,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('sessions')
            .where('userId', isEqualTo: user.uid)
            .orderBy('date', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text("😕 Aucune session trouvée",
                  style: TextStyle(color: Colors.white70)),
            );
          }

          final sessions = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final session = sessions[index];
              final data = session.data() as Map<String, dynamic>;

              final date = data['date'].toDate();
              final dateString =
                  "${date.day}/${date.month}/${date.year}";

              return GestureDetector(
                onTap: () {
                  final sessionData = SessionData(
                    date: data['date'].toDate(),
                    frappes: data['frappes'],
                    vitesseMoyenne: data['vitesseMoyenne'],
                    zoneImpact: data['zoneImpact'],
                    scorePerformance: data['scorePerformance'],
                    vitesses: List<double>.from(
                      data['vitesses'].map((v) => v.toDouble()),
                    ),
                    coupsDroit: data['coupsDroit'],
                    revers: data['revers'],
                  );

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          SessionRecapScreen(session: sessionData),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "📅 $dateString",
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _infoBadge("🎾 ${data['frappes']} frappes"),
                          const SizedBox(width: 10),
                          _infoBadge("🚀 ${data['vitesseMoyenne'].toStringAsFixed(1)} km/h"),
                          const SizedBox(width: 10),
                          _infoBadge("💯 ${data['scorePerformance']} pts"),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _infoBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white),
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

  factory SessionData.fromMap(Map<String, dynamic> data) {
    return SessionData(
      date: DateTime.parse(data['date']),
      frappes: data['frappes'],
      vitesseMoyenne: (data['vitesseMoyenne'] as num).toDouble(),
      zoneImpact: data['zoneImpact'],
      scorePerformance: data['scorePerformance'],
      vitesses: List<double>.from((data['vitesses'] as List).map((v) => (v as num).toDouble())),
      coupsDroit: data['coupsDroit'],
      revers: data['revers'],
    );
  }
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          );
        },
        child: const Icon(Icons.settings),
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


//-------------------------------------------------------
// CREATION DE COMPTE - USER PROFIL
//-------------------------------------------------------

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    setState(() {
    _isLoading = true;
    _errorMessage = null;
    });

    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (!mounted) return;
      Navigator.pop(context); // ✅ AuthGate prend le relais et redirige automatiquement
       // ou naviguer vers une page principale
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Créer un compte")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: "Adresse email"),
            ),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: "Mot de passe"),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            _isLoading
            ? const CircularProgressIndicator()
            : ElevatedButton(
                onPressed: _signUp,
                child: const Text("Créer un compte"),
              ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ),
    );
  }
}

//---------------------------------
// SIGN UP SCREEN
//---------------------------------

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Bienvenue sur Padalytics"),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.logout),
                        tooltip: 'Se déconnecter',
                        onPressed: () async {
                          await FirebaseAuth.instance.signOut();
                        },
                      )
                    ],
              ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Bienvenue !",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SignUpScreen()),
                );
              },
              child: const Text("Créer un compte"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
              child: const Text("Se connecter"),
            ),
          ],
        ),
      ),
    );
  }
}

//------------------------
// AUTH GATE
//------------------------
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<bool> _hasSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('onboarding_seen') ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _hasSeenOnboarding(),
      builder: (context, onboardingSnapshot) {
        if (onboardingSnapshot.connectionState != ConnectionState.done) {
          return const SplashScreen(); // ✅ un seul loader cohérent
        }

        final onboardingSeen = onboardingSnapshot.data ?? false;

        return StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, authSnapshot) {
            if (authSnapshot.connectionState != ConnectionState.active) {
              return const SplashScreen(); // ✅ même loader
            }

            final user = authSnapshot.data;

            debugPrint("🧭 Onboarding vu : $onboardingSeen");
            debugPrint("👤 Utilisateur connecté : ${user != null}");

            if (!onboardingSeen) {
              return const OnboardingScreen();
            } else if (user != null) {
              return const HomeScreen();
            } else {
              return const WelcomeScreen();
            }
          },
        );
      },
    );
  }
}

//---------------------------------
// LOGIN SCREEN
//---------------------------------

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (!mounted) return;

      // ✅ On revient au WelcomeScreen → AuthGate voit que l'utilisateur est connecté → affiche HomeScreen
      Navigator.pop(context);

      /// ✅ ferme l'écran actuel → `AuthGate` reconstruit en HomeScreen
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message ?? "Erreur lors de la connexion.";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Connexion")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: "Adresse email"),
            ),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: "Mot de passe"),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            _isLoading
              ? const CircularProgressIndicator()
              : ElevatedButton(
                  onPressed: _login,
                  child: const Text("Se connecter"),
                ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ),
    );
  }
}

//--------------------
// SETTING SCREEN
//--------------------

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
                // TODO: Naviguer vers profil utilisateur
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

//---------------------------------------
// SLIDER ONBOARDING
//---------------------------------------
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  bool _isLastPage = false;

  final List<Map<String, String>> pages = [
    {
      "title": "Bienvenue dans Padalytics",
      "description": "Votre assistant intelligent pour analyser vos frappes au padel !",
      "image": "assets/accueil-padalytics-screen-app.png"
    },
    {
      "title": "Analyse en temps réel",
      "description": "Suivez vos coups droits, revers, et la vitesse de chaque frappe.",
      "image": "assets/detect-frappe.png"
    },
    {
      "title": "Historique & progression",
      "description": "Visualisez votre historique de sessions et progressez plus vite.",
      "image": "assets/historique.png"
    },
    {
      "title": "Connectez votre capteur",
      "description": "Assurez-vous que votre capteur BLE est allumé et à proximité.",
      "image": "assets/scan-raquette.png"
    },
  ];

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_seen', true);

    if (!mounted) return;

    // ⬇️ On déclenche la redirection via AuthGate
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AuthGate()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: pages.length,
                onPageChanged: (index) {
                  setState(() {
                    _isLastPage = index == pages.length - 1;
                  });
                },
                itemBuilder: (context, index) {
                  final page = pages[index];
                  return Padding(
                    padding: const EdgeInsets.all(30),
                    child: Column(
                      children: [
                        Image.asset(page["image"]!, height: 250),
                        const SizedBox(height: 30),
                        Text(
                          page["title"]!,
                          style: const TextStyle(
                            fontSize: 24,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 15),
                        Text(
                          page["description"]!,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white70,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SmoothPageIndicator(
                    controller: _controller,
                    count: pages.length,
                    effect: const WormEffect(
                      dotColor: Colors.white24,
                      activeDotColor: Colors.white,
                      dotHeight: 10,
                      dotWidth: 10,
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _isLastPage ? _finishOnboarding : () {
                      _controller.nextPage(
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: Text(_isLastPage ? "Commencer" : "Suivant"),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}



