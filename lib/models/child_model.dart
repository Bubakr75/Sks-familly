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

  // ── Données journalières ──
  int?          bonusCount;
  int?          penaltyCount;
  int?          activePunishments;
  int?          usableImmunities;
  List<String>? recentReasons;

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
    this.bonusCount,
    this.penaltyCount,
    this.activePunishments,
    this.usableImmunities,
    this.recentReasons,
  })  : badgeIds  = badgeIds  ?? [],
        createdAt = createdAt ?? DateTime.now();

  bool get hasPhoto => photoBase64.isNotEmpty;

  /// True si la photo est une URL Firebase Storage (commence par http).
  bool get isPhotoUrl => photoBase64.startsWith('http');

  /// True si la bannière est une URL Firebase Storage.
  bool get isBannerUrl =>
      bannerBase64 != null && bannerBase64!.startsWith('http');

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
    int?          bonusCount,
    int?          penaltyCount,
    int?          activePunishments,
    int?          usableImmunities,
    List<String>? recentReasons,
  }) {
    return ChildModel(
      id:                id                ?? this.id,
      name:              name              ?? this.name,
      avatar:            avatar            ?? this.avatar,
      photoBase64:       photoBase64       ?? this.photoBase64,
      points:            points            ?? this.points,
      level:             level             ?? this.level,
      badgeIds:          badgeIds          ?? List<String>.from(this.badgeIds),
      createdAt:         createdAt         ?? this.createdAt,
      bannerBase64:      bannerBase64      ?? this.bannerBase64,
      sloganText:        sloganText        ?? this.sloganText,
      accentColorHex:    accentColorHex    ?? this.accentColorHex,
      streakDays:        streakDays        ?? this.streakDays,
      previousPhotos:    previousPhotos    ?? this.previousPhotos,
      bonusCount:        bonusCount        ?? this.bonusCount,
      penaltyCount:      penaltyCount      ?? this.penaltyCount,
      activePunishments: activePunishments ?? this.activePunishments,
      usableImmunities:  usableImmunities  ?? this.usableImmunities,
      recentReasons:     recentReasons     ?? this.recentReasons,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'id':          id,
      'name':        name,
      'avatar':      avatar,
      'photoBase64': photoBase64,
      'points':      points,
      'level':       level,
      'badgeIds':    badgeIds,
      'createdAt':   createdAt.toIso8601String(),
    };
    if (bannerBase64      != null) map['bannerBase64']      = bannerBase64;
    if (sloganText        != null) map['sloganText']        = sloganText;
    if (accentColorHex    != null) map['accentColorHex']    = accentColorHex;
    if (streakDays        != null) map['streakDays']        = streakDays;
    if (previousPhotos    != null) map['previousPhotos']    = previousPhotos;
    if (bonusCount        != null) map['bonusCount']        = bonusCount;
    if (penaltyCount      != null) map['penaltyCount']      = penaltyCount;
    if (activePunishments != null) map['activePunishments'] = activePunishments;
    if (usableImmunities  != null) map['usableImmunities']  = usableImmunities;
    if (recentReasons     != null) map['recentReasons']     = recentReasons;
    return map;
  }

  factory ChildModel.fromMap(Map<String, dynamic> map) {
    final pts   = (map['points'] as num?)?.toInt() ?? 0;
    final child = ChildModel(
      id:                map['id']          as String? ?? '',
      name:              map['name']        as String? ?? '',
      avatar:            map['avatar']      as String? ?? '',
      photoBase64:       map['photoBase64'] as String? ?? '',
      points:            pts,
      level:             (map['level']      as num?)?.toInt() ?? 1,
      badgeIds:          List<String>.from(map['badgeIds'] ?? []),
      createdAt:         map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      bannerBase64:      map['bannerBase64']   as String?,
      sloganText:        map['sloganText']     as String?,
      accentColorHex:    map['accentColorHex'] as String?,
      streakDays:        (map['streakDays']    as num?)?.toInt(),
      previousPhotos:    map['previousPhotos'] != null
          ? List<String>.from(map['previousPhotos'])
          : null,
      bonusCount:        (map['bonusCount']        as num?)?.toInt(),
      penaltyCount:      (map['penaltyCount']      as num?)?.toInt(),
      activePunishments: (map['activePunishments'] as num?)?.toInt(),
      usableImmunities:  (map['usableImmunities']  as num?)?.toInt(),
      recentReasons:     map['recentReasons'] != null
          ? List<String>.from(map['recentReasons'])
          : null,
    );
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
