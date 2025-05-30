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

  Map<String, dynamic> toMap() {
    return {
      'date': date.toIso8601String(),
      'frappes': frappes,
      'vitesseMoyenne': vitesseMoyenne,
      'zoneImpact': zoneImpact,
      'scorePerformance': scorePerformance,
      'vitesses': vitesses,
      'coupsDroit': coupsDroit,
      'revers': revers,
    };
  }
}