class PunishmentLines {
  String id;
  String childId;
  String text;
  int totalLines;
  int completedLines;
  DateTime createdAt;
  List<String> photoUrls;
  bool pendingValidation;

  PunishmentLines({
    required this.id,
    required this.childId,
    required this.text,
    required this.totalLines,
    this.completedLines = 0,
    DateTime? createdAt,
    List<String>? photoUrls,
    this.pendingValidation = false,
  })  : createdAt = createdAt ?? DateTime.now(),
        photoUrls = photoUrls ?? [];

  bool get isCompleted => completedLines >= totalLines;
  double get progress => totalLines > 0 ? completedLines / totalLines : 0;
  bool get hasPhotos => photoUrls.isNotEmpty;

  Map<String, dynamic> toMap() => {
        'id': id,
        'childId': childId,
        'text': text,
        'totalLines': totalLines,
        'completedLines': completedLines,
        'createdAt': createdAt.toIso8601String(),
        'photoUrls': photoUrls,
        'pendingValidation': pendingValidation,
      };

  factory PunishmentLines.fromMap(Map<String, dynamic> map) => PunishmentLines(
        id: map['id'] ?? '',
        childId: map['childId'] ?? '',
        text: map['text'] ?? '',
        totalLines: map['totalLines'] ?? 0,
        completedLines: map['completedLines'] ?? 0,
        createdAt: map['createdAt'] != null
            ? DateTime.parse(map['createdAt'])
            : DateTime.now(),
        photoUrls: List<String>.from(map['photoUrls'] ?? []),
        pendingValidation: map['pendingValidation'] ?? false,
      );
}
