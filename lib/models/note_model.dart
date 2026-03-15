class NoteModel {
  String id;
  String childId;
  String text;
  String authorName;
  DateTime createdAt;
  bool isPinned;

  NoteModel({
    required this.id,
    required this.childId,
    required this.text,
    this.authorName = 'Parent',
    DateTime? createdAt,
    this.isPinned = false,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'childId': childId,
        'text': text,
        'authorName': authorName,
        'createdAt': createdAt.toIso8601String(),
        'isPinned': isPinned,
      };

  factory NoteModel.fromMap(Map<String, dynamic> map) => NoteModel(
        id: map['id'] ?? '',
        childId: map['childId'] ?? '',
        text: map['text'] ?? '',
        authorName: map['authorName'] ?? 'Parent',
        createdAt: map['createdAt'] != null
            ? DateTime.parse(map['createdAt'])
            : DateTime.now(),
        isPinned: map['isPinned'] ?? false,
      );
}
