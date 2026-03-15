class GoalModel {
  String id;
  String childId;
  String title;
  int targetPoints;
  bool completed;
  DateTime createdAt;

  GoalModel({
    required this.id,
    required this.childId,
    required this.title,
    required this.targetPoints,
    this.completed = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'childId': childId,
        'title': title,
        'targetPoints': targetPoints,
        'completed': completed,
        'createdAt': createdAt.toIso8601String(),
      };

  factory GoalModel.fromMap(Map<String, dynamic> map) => GoalModel(
        id: map['id'] ?? '',
        childId: map['childId'] ?? '',
        title: map['title'] ?? '',
        targetPoints: map['targetPoints'] ?? 100,
        completed: map['completed'] ?? false,
        createdAt: map['createdAt'] != null
            ? DateTime.parse(map['createdAt'])
            : DateTime.now(),
      );
}
