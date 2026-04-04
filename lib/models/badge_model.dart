// lib/models/badge_model.dart

class BadgeModel {
  String id;
  String name;
  String icon;
  String description;
  int requiredPoints;
  String powerType;
  bool isCustom;

  BadgeModel({
    required this.id,
    required this.name,
    required this.icon,
    required this.description,
    required this.requiredPoints,
    this.powerType = 'custom',
    this.isCustom = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'icon': icon,
        'description': description,
        'requiredPoints': requiredPoints,
        'powerType': powerType,
        'isCustom': isCustom,
      };

  factory BadgeModel.fromMap(Map<String, dynamic> map) => BadgeModel(
        id: map['id'] ?? '',
        name: map['name'] ?? '',
        icon: map['icon'] ?? '',
        description: map['description'] ?? '',
        requiredPoints: map['requiredPoints'] ?? 0,
        powerType: map['powerType'] ?? 'custom',
        isCustom: map['isCustom'] ?? false,
      );

  String get powerEmoji {
    switch (powerType) {
      case 'tv':             return '📺';
      case 'no_chores':      return '🧹';
      case 'dessert':        return '🎂';
      case 'late_bed':       return '🌙';
      case 'game':           return '🎮';
      case 'outing':         return '🏠';
      case 'star':           return '⭐';
      case 'school':         return '🎓';
      case 'thumb_up':       return '👍';
      case 'home':           return '🏠';
      case 'emoji_events':   return '🏆';
      case 'military_tech':  return '🎖️';
      case 'gift':           return '🎁';
      default:               return '⚡';
    }
  }

  static List<BadgeModel> defaultBadges = [
    BadgeModel(
      id:             'power_dessert',
      name:           'Super Dessert',
      icon:           'dessert',
      description:    'Choisis le dessert de ton choix',
      requiredPoints: 25,
      powerType:      'dessert',
    ),
    BadgeModel(
      id:             'power_tv',
      name:           'Maitre de la tele',
      icon:           'tv',
      description:    'Choisis les dessins animés et films de la journée',
      requiredPoints: 50,
      powerType:      'tv',
    ),
    BadgeModel(
      id:             'power_late_bed',
      name:           'Couche-tard',
      icon:           'late_bed',
      description:    'Se coucher 30 minutes plus tard',
      requiredPoints: 80,
      powerType:      'late_bed',
    ),
    BadgeModel(
      id:             'power_game',
      name:           'Roi du jeu',
      icon:           'game',
      description:    '30 minutes de jeu vidéo en bonus',
      requiredPoints: 120,
      powerType:      'game',
    ),
    BadgeModel(
      id:             'power_no_chores',
      name:           'Pas de corvées',
      icon:           'no_chores',
      description:    'Pas de tâches ménagères pour la journée',
      requiredPoints: 180,
      powerType:      'no_chores',
    ),
    BadgeModel(
      id:             'power_outing',
      name:           'Sortie spéciale',
      icon:           'outing',
      description:    'Choisis une sortie en famille',
      requiredPoints: 250,
      powerType:      'outing',
    ),
    BadgeModel(
      id:             'power_gift',
      name:           'Cadeau surprise',
      icon:           'gift',
      description:    'Bravo ! Tu as atteint le niveau MAX et tu gagnes un cadeau !',
      requiredPoints: 300,
      powerType:      'gift',
    ),
  ];
}
