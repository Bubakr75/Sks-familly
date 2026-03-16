class ImmunityLines {
  String id;
  String childId;
  String text;
  int totalLines;
  int completedLines;
  int usedLines;
  DateTime createdAt;
  DateTime? expiresAt;
  String immunityType;

  ImmunityLines({
    required this.id,
    required this.childId,
    required this.text,
    required this.totalLines,
    this.completedLines = 0,
    this.usedLines = 0,
    DateTime? createdAt,
    this.expiresAt,
    this.immunityType = 'custom',
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isCompleted => completedLines >= totalLines;
  double get progress => totalLines > 0 ? completedLines / totalLines : 0;
  int get availableLines {
    final earned = completedLines - usedLines;
    return earned > 0 ? earned : 0;
  }

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  bool get isUsable => !isExpired && availableLines > 0;

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

  String get expiresLabel {
    if (expiresAt == null) return 'Pas d\'expiration';
    if (isExpired) return 'Expiree';
    final diff = expiresAt!.difference(DateTime.now());
    if (diff.inDays > 0) return 'Expire dans ${diff.inDays}j';
    if (diff.inHours > 0) return 'Expire dans ${diff.inHours}h';
    return 'Expire bientot';
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'childId': childId,
        'text': text,
        'totalLines': totalLines,
        'completedLines': completedLines,
        'usedLines': usedLines,
        'createdAt': createdAt.toIso8601String(),
        'expiresAt': expiresAt?.toIso8601String(),
        'immunityType': immunityType,
      };

  factory ImmunityLines.fromMap(Map<String, dynamic> map) => ImmunityLines(
        id: map['id'] ?? '',
        childId: map['childId'] ?? '',
        text: map['text'] ?? '',
        totalLines: map['totalLines'] ?? 0,
        completedLines: map['completedLines'] ?? 0,
        usedLines: map['usedLines'] ?? 0,
        createdAt: map['createdAt'] != null
            ? DateTime.parse(map['createdAt'])
            : DateTime.now(),
        expiresAt: map['expiresAt'] != null
            ? DateTime.parse(map['expiresAt'])
            : null,
        immunityType: map['immunityType'] ?? 'custom',
      );
}
