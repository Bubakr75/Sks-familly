class ChildModel {
  String id;
  String name;
  String avatar;
  String photoBase64;
  int points;
  int level;
  List<String> badgeIds;
  DateTime createdAt;

  ChildModel({
    required this.id,
    required this.name,
    this.avatar = '',
    this.photoBase64 = '',
    this.points = 0,
    this.level = 1,
    List<String>? badgeIds,
    DateTime? createdAt,
  })  : badgeIds = badgeIds ?? [],
        createdAt = createdAt ?? DateTime.now();

  bool get hasPhoto => photoBase64.isNotEmpty;

  String get levelTitle {
    if (points >= 1000) return 'Champion';
    if (points >= 500) return 'Expert';
    if (points >= 200) return 'Confirme';
    if (points >= 100) return 'Apprenti';
    if (points >= 50) return 'Debutant';
    return 'Novice';
  }

  double get levelProgress {
    if (points >= 1000) return 1.0;
    if (points >= 500) return (points - 500) / 500;
    if (points >= 200) return (points - 200) / 300;
    if (points >= 100) return (points - 100) / 100;
    if (points >= 50) return (points - 50) / 50;
    return points / 50;
  }

  int get nextLevelPoints {
    if (points >= 1000) return 1000;
    if (points >= 500) return 1000;
    if (points >= 200) return 500;
    if (points >= 100) return 200;
    if (points >= 50) return 100;
    return 50;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'avatar': avatar,
        'photoBase64': photoBase64,
        'points': points,
        'level': level,
        'badgeIds': badgeIds,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ChildModel.fromMap(Map<String, dynamic> map) => ChildModel(
        id: map['id'] ?? '',
        name: map['name'] ?? '',
        avatar: map['avatar'] ?? '',
        photoBase64: map['photoBase64'] ?? '',
        points: map['points'] ?? 0,
        level: map['level'] ?? 1,
        badgeIds: List<String>.from(map['badgeIds'] ?? []),
        createdAt: map['createdAt'] != null
            ? DateTime.parse(map['createdAt'])
            : DateTime.now(),
      );
}
