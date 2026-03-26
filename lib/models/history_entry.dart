class HistoryEntry {
  String id;
  String childId;
  int points;
  String reason;
  String category;
  DateTime date;
  bool isBonus;
  String? proofPhotoBase64;
  String? actionBy;

  HistoryEntry({
    required this.id,
    required this.childId,
    required this.points,
    required this.reason,
    this.category = 'Bonus',
    DateTime? date,
    this.isBonus = true,
    this.proofPhotoBase64,
    this.actionBy,
  }) : date = date ?? DateTime.now();

  bool get hasProofPhoto => proofPhotoBase64 != null && proofPhotoBase64!.isNotEmpty;

  Map<String, dynamic> toMap() => {
        'id': id,
        'childId': childId,
        'points': points,
        'reason': reason,
        'category': category,
        'date': date.toIso8601String(),
        'isBonus': isBonus,
        'proofPhotoBase64': proofPhotoBase64,
        'actionBy': actionBy,
      };

  factory HistoryEntry.fromMap(Map<String, dynamic> map) => HistoryEntry(
        id: map['id'] ?? '',
        childId: map['childId'] ?? '',
        points: map['points'] ?? 0,
        reason: map['reason'] ?? '',
        category: map['category'] ?? 'Bonus',
        date: map['date'] != null ? DateTime.parse(map['date']) : DateTime.now(),
        isBonus: map['isBonus'] ?? true,
        proofPhotoBase64: map['proofPhotoBase64'],
        actionBy: map['actionBy'],
      );
}
