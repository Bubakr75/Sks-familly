class ImmunityLines {
  String id;
  String childId;
  String text;
  int totalLines;
  int completedLines;
  DateTime createdAt;
  String immunityType; // 'corvee', 'punition', 'devoir', 'custom'

  ImmunityLines({
    required this.id,
    required this.childId,
    required this.text,
    required this.totalLines,
    this.completedLines = 0,
    DateTime? createdAt,
    this.immunityType = 'custom',
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isCompleted => completedLines >= totalLines;
  double get progress => totalLines > 0 ? completedLines / totalLines : 0;

  String get immunityLabel {
    switch (immunityType) {
      case 'corvee':
        return 'Immunite corvee';
      case 'punition':
        return 'Immunite punition';
      case 'devoir':
        return 'Immunite devoir';
      default:
        return 'Immunite speciale';
    }
  }

  String get immunityEmoji {
    switch (immunityType) {
      case 'corvee':
        return '\u{1F9F9}';
      case 'punition':
        return '\u{1F6E1}';
      case 'devoir':
        return '\u{1F4DA}';
      default:
        return '\u{2B50}';
    }
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'childId': childId,
        'text': text,
        'totalLines': totalLines,
        'completedLines': completedLines,
        'createdAt': createdAt.toIso8601String(),
        'immunityType': immunityType,
      };

  factory ImmunityLines.fromMap(Map<String, dynamic> map) => ImmunityLines(
        id: map['id'] ?? '',
        childId: map['childId'] ?? '',
        text: map['text'] ?? '',
        totalLines: map['totalLines'] ?? 0,
        completedLines: map['completedLines'] ?? 0,
        createdAt: map['createdAt'] != null
            ? DateTime.parse(map['createdAt'])
            : DateTime.now(),
        immunityType: map['immunityType'] ?? 'custom',
      );
}
