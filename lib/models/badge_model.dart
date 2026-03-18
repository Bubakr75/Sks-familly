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
      case 'tv': return '\u{1F4FA}';
      case 'no_chores': return '\u{1F9F9}';
      case 'dessert': return '\u{1F370}';
      case 'late_bed': return '\u{1F319}';
      case 'game': return '\u{1F3AE}';
      case 'outing': return '\u{1F3E0}';
      case 'star': return '\u{2B50}';
      case 'school': return '\u{1F393}';
      case 'thumb_up': return '\u{1F44D}';
      case 'home': return '\u{1F3E0}';
      case 'emoji_events': return '\u{1F3C6}';
      case 'military_tech': return '\u{1F396}';
      case 'gift': return '\u{1F381}';
      default: return '\u{26A1}';
    }
  }

  static List<BadgeModel> defaultBadges = [
    // ~3 jours de bon comportement
    BadgeModel(
      id: 'power_dessert',
      name: 'Super Dessert',
      icon: 'dessert',
      description: 'Choisis le dessert de ton choix',
      requiredPoints: 25,
      powerType: 'dessert',
    ),
    // ~1 semaine
    BadgeModel(
      id: 'power_tv',
      name: 'Maitre de la tele',
      icon: 'tv',
      description: 'Choisis les dessins animes et films de la journee',
      requiredPoints: 50,
      powerType: 'tv',
    ),
    // ~10 jours
    BadgeModel(
      id: 'power_late_bed',
      name: 'Couche-tard',
      icon: 'late_bed',
      description: 'Se coucher 30 minutes plus tard',
      requiredPoints: 80,
      powerType: 'late_bed',
    ),
    // ~2 semaines
    BadgeModel(
      id: 'power_game',
      name: 'Roi du jeu',
      icon: 'game',
      description: '30 minutes de jeu video en bonus',
      requiredPoints: 120,
      powerType: 'game',
    ),
    // ~3 semaines
    BadgeModel(
      id: 'power_no_chores',
      name: 'Pas de corvees',
      icon: 'no_chores',
      description: 'Pas de taches menageres pour la journee',
      requiredPoints: 180,
      powerType: 'no_chores',
    ),
    // ~3-4 semaines
    BadgeModel(
      id: 'power_outing',
      name: 'Sortie speciale',
      icon: 'outing',
      description: 'Choisis une sortie en famille',
      requiredPoints: 250,
      powerType: 'outing',
    ),
    // Niveau MAX = cadeau
    BadgeModel(
      id: 'power_gift',
      name: 'Cadeau surprise',
      icon: 'gift',
      description: 'Bravo ! Tu as atteint le niveau MAX et tu gagnes un cadeau !',
      requiredPoints: 300,
      powerType: 'gift',
    ),
  ];
}
