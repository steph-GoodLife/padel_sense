import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth/auth_gate.dart';

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
