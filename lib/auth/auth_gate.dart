import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/splash_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/home_screen.dart';
import '../screens/welcome_screen.dart';

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