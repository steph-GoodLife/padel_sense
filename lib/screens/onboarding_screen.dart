import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../auth/auth_gate.dart';

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