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
    if (points >= 300) return 'Niveau MAX';
    if (points >= 220) return 'Niveau 5';
    if (points >= 150) return 'Niveau 4';
    if (points >= 90) return 'Niveau 3';
    if (points >= 40) return 'Niveau 2';
    return 'Niveau 1';
  }

  bool get isMaxLevel => points >= 300;

  double get levelProgress {
    if (points >= 300) return 1.0;
    if (points >= 220) return (points - 220) / 80;
    if (points >= 150) return (points - 150) / 70;
    if (points >= 90) return (points - 90) / 60;
    if (points >= 40) return (points - 40) / 50;
    return points / 40;
  }

  int get nextLevelPoints {
    if (points >= 300) return 300;
    if (points >= 220) return 300;
    if (points >= 150) return 220;
    if (points >= 90) return 150;
    if (points >= 40) return 90;
    return 40;
  }

  int get currentLevelNumber {
    if (points >= 300) return 6;
    if (points >= 220) return 5;
    if (points >= 150) return 4;
    if (points >= 90) return 3;
    if (points >= 40) return 2;
    return 1;
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
