import 'package:flutter/material.dart';

import '../models/session_data.dart';
import 'settings_screen.dart';

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