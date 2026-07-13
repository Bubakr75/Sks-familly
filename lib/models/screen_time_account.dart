// lib/models/screen_time_account.dart
//
// Compte de minutes d'écran par enfant.
// L'enfant accumule des minutes (achats boutique + bonus parent).
// Il démarre/arrête le chrono quand il veut. Le solde diminue.

class ScreenTimeAccount {
  String childId;
  int balanceMinutes;        // Solde de minutes disponibles
  int totalEarned;           // Total gagné (pour stats)
  int totalUsed;             // Total consommé (pour stats)
  DateTime? sessionStart;    // Début de la session en cours (null = pas en cours)
  int sessionMinutes;        // Minutes au début de la session
  List<ScreenTimeTransaction> history;

  ScreenTimeAccount({
    required this.childId,
    this.balanceMinutes = 0,
    this.totalEarned = 0,
    this.totalUsed = 0,
    this.sessionStart,
    this.sessionMinutes = 0,
    List<ScreenTimeTransaction>? history,
  }) : history = history ?? [];

  bool get isRunning => sessionStart != null;

  /// Minutes restantes dans la session en cours
  int get sessionRemaining {
    if (sessionStart == null) return 0;
    final elapsed = DateTime.now().difference(sessionStart!).inMinutes;
    return (sessionMinutes - elapsed).clamp(0, sessionMinutes);
  }

  /// Minutes écoulées dans la session
  int get sessionElapsed {
    if (sessionStart == null) return 0;
    return DateTime.now().difference(sessionStart!).inMinutes;
  }

  Map<String, dynamic> toMap() {
    return {
      'childId': childId,
      'balanceMinutes': balanceMinutes,
      'totalEarned': totalEarned,
      'totalUsed': totalUsed,
      'sessionStart': sessionStart?.toIso8601String(),
      'sessionMinutes': sessionMinutes,
      'history': history.map((t) => t.toMap()).toList(),
    };
  }

  factory ScreenTimeAccount.fromMap(Map<String, dynamic> map) {
    return ScreenTimeAccount(
      childId: map['childId'] ?? '',
      balanceMinutes: map['balanceMinutes'] ?? 0,
      totalEarned: map['totalEarned'] ?? 0,
      totalUsed: map['totalUsed'] ?? 0,
      sessionStart: map['sessionStart'] != null ? DateTime.parse(map['sessionStart']) : null,
      sessionMinutes: map['sessionMinutes'] ?? 0,
      history: (map['history'] as List<dynamic>?)
          ?.map((t) => ScreenTimeTransaction.fromMap(Map<String, dynamic>.from(t)))
          .toList() ?? [],
    );
  }
}

class ScreenTimeTransaction {
  final int minutes;
  final String type;        // 'earned' (achat/bonus) ou 'used' (consommé)
  final String reason;
  final DateTime date;

  ScreenTimeTransaction({
    required this.minutes,
    required this.type,
    required this.reason,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'minutes': minutes,
      'type': type,
      'reason': reason,
      'date': date.toIso8601String(),
    };
  }

  factory ScreenTimeTransaction.fromMap(Map<String, dynamic> map) {
    return ScreenTimeTransaction(
      minutes: map['minutes'] ?? 0,
      type: map['type'] ?? 'earned',
      reason: map['reason'] ?? '',
      date: map['date'] != null ? DateTime.parse(map['date']) : DateTime.now(),
    );
  }
}
