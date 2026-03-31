// lib/models/history_entry.dart

class HistoryEntry {
  String id;
  String childId;
  int points;
  String description;
  String emoji;
  String category;
  DateTime date;
  String? proofPhotoBase64;
  String? actionBy;
  Map<String, dynamic>? metadata;

  HistoryEntry({
    required this.id,
    required this.childId,
    required this.points,
    required this.description,
    this.emoji = '⭐',
    this.category = 'Bonus',
    DateTime? date,
    this.proofPhotoBase64,
    this.actionBy,
    this.metadata,
  }) : date = date ?? DateTime.now();

  bool get hasProofPhoto =>
      proofPhotoBase64 != null && proofPhotoBase64!.isNotEmpty;

  bool get isBonus => points >= 0;

  Map<String, dynamic> toMap() => {
        'id': id,
        'childId': childId,
        'points': points,
        'description': description,
        'emoji': emoji,
        'category': category,
        'date': date.toIso8601String(),
        'proofPhotoBase64': proofPhotoBase64,
        'actionBy': actionBy,
        'metadata': metadata,
      };

  factory HistoryEntry.fromMap(Map<String, dynamic> map) => HistoryEntry(
        id: map['id'] ?? '',
        childId: map['childId'] ?? '',
        points: map['points'] ?? 0,
        description: map['description'] ?? map['reason'] ?? '',
        emoji: map['emoji'] ?? '⭐',
        category: map['category'] ?? 'Bonus',
        date: map['date'] != null
            ? DateTime.tryParse(map['date']) ?? DateTime.now()
            : DateTime.now(),
        proofPhotoBase64: map['proofPhotoBase64'],
        actionBy: map['actionBy'],
        metadata: map['metadata'] != null
            ? Map<String, dynamic>.from(map['metadata'])
            : null,
      );
}
