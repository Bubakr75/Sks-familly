// lib/models/child_model.dart

class ChildModel {
  String  id;
  String  name;
  String  avatar;
  String  photoBase64;
  int     points;
  int     level;
  List<String> badgeIds;
  DateTime createdAt;

  String? bannerBase64;
  String? sloganText;
  String? accentColorHex;
  int?    streakDays;
  List<String>? previousPhotos;

  ChildModel({
    required this.id,
    required this.name,
    this.avatar          = '',
    this.photoBase64     = '',
    this.points          = 0,
    this.level           = 1,
    List<String>? badgeIds,
    DateTime?     createdAt,
    this.bannerBase64,
    this.sloganText,
    this.accentColorHex,
    this.streakDays,
    this.previousPhotos,
  })  : badgeIds  = badgeIds  ?? [],
        createdAt = createdAt ?? DateTime.now();

  bool get hasPhoto => photoBase64.isNotEmpty;

  String get levelTitle {
    if (points >= 300) return 'Niveau MAX ⭐';
    if (points >= 220) return 'Niveau 5';
    if (points >= 150) return 'Niveau 4';
    if (points >= 90)  return 'Niveau 3';
    if (points >= 40)  return 'Niveau 2';
    return 'Niveau 1';
  }

  bool get isMaxLevel => points >= 300;

  double get levelProgress {
    if (points >= 300) return 1.0;
    if (points >= 220) return (points - 220) / 80.0;
    if (points >= 150) return (points - 150) / 70.0;
    if (points >= 90)  return (points - 90)  / 60.0;
    if (points >= 40)  return (points - 40)  / 50.0;
    return (points / 40.0).clamp(0.0, 1.0);
  }

  int get nextLevelPoints {
    if (points >= 300) return 300;
    if (points >= 220) return 300;
    if (points >= 150) return 220;
    if (points >= 90)  return 150;
    if (points >= 40)  return 90;
    return 40;
  }

  int get currentLevelNumber {
    if (points >= 300) return 6;
    if (points >= 220) return 5;
    if (points >= 150) return 4;
    if (points >= 90)  return 3;
    if (points >= 40)  return 2;
    return 1;
  }

  ChildModel copyWith({
    String?       id,
    String?       name,
    String?       avatar,
    String?       photoBase64,
    int?          points,
    int?          level,
    List<String>? badgeIds,
    DateTime?     createdAt,
    String?       bannerBase64,
    String?       sloganText,
    String?       accentColorHex,
    int?          streakDays,
    List<String>? previousPhotos,
  }) {
    return ChildModel(
      id:             id             ?? this.id,
      name:           name           ?? this.name,
      avatar:         avatar         ?? this.avatar,
      photoBase64:    photoBase64    ?? this.photoBase64,
      points:         points         ?? this.points,
      level:          level          ?? this.level,
      badgeIds:       badgeIds       ?? List<String>.from(this.badgeIds),
      createdAt:      createdAt      ?? this.createdAt,
      bannerBase64:   bannerBase64   ?? this.bannerBase64,
      sloganText:     sloganText     ?? this.sloganText,
      accentColorHex: accentColorHex ?? this.accentColorHex,
      streakDays:     streakDays     ?? this.streakDays,
      previousPhotos: previousPhotos ?? this.previousPhotos,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'id':          id,
      'name':        name,
      'avatar':      avatar,
      'photoBase64': photoBase64,
      'points':      points,
      'level':       currentLevelNumber,
      'badgeIds':    badgeIds,
      'createdAt':   createdAt.toIso8601String(),
    };
    if (bannerBase64   != null) map['bannerBase64']   = bannerBase64;
    if (sloganText     != null) map['sloganText']     = sloganText;
    if (accentColorHex != null) map['accentColorHex'] = accentColorHex;
    if (streakDays     != null) map['streakDays']     = streakDays;
    if (previousPhotos != null) map['previousPhotos'] = previousPhotos;
    return map;
  }

  factory ChildModel.fromMap(Map<String, dynamic> map) {
    final pts   = (map['points'] as num?)?.toInt() ?? 0;
    final child = ChildModel(
      id:             map['id']          as String? ?? '',
      name:           map['name']        as String? ?? '',
      avatar:         map['avatar']      as String? ?? '',
      photoBase64:    map['photoBase64'] as String? ?? '',
      points:         pts,
      level:          (map['level']      as num?)?.toInt() ?? 1,
      badgeIds:       List<String>.from(map['badgeIds'] ?? []),
      createdAt:      map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      bannerBase64:   map['bannerBase64']   as String?,
      sloganText:     map['sloganText']     as String?,
      accentColorHex: map['accentColorHex'] as String?,
      streakDays:     (map['streakDays']    as num?)?.toInt(),
      previousPhotos: map['previousPhotos'] != null
          ? List<String>.from(map['previousPhotos'])
          : null,
    );
    child.level = child.currentLevelNumber;
    return child;
  }

  @override
  String toString() =>
      'ChildModel(id: $id, name: $name, points: $points, level: $level)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is ChildModel && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
