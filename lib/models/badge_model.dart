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
      default: return '\u{26A1}';
    }
  }

  static List<BadgeModel> defaultBadges = [
    BadgeModel(id: 'power_tv', name: 'Maitre de la tele', icon: 'tv', description: 'Choisis les dessins animes et films de la journee', requiredPoints: 50, powerType: 'tv'),
    BadgeModel(id: 'power_no_chores', name: 'Pas de corvees', icon: 'no_chores', description: 'Pas de taches menageres pour la journee', requiredPoints: 80, powerType: 'no_chores'),
    BadgeModel(id: 'power_dessert', name: 'Super Dessert', icon: 'dessert', description: 'Choisis le dessert de ton choix', requiredPoints: 30, powerType: 'dessert'),
    BadgeModel(id: 'power_late_bed', name: 'Couche-tard', icon: 'late_bed', description: 'Se coucher 30 minutes plus tard', requiredPoints: 60, powerType: 'late_bed'),
    BadgeModel(id: 'power_game', name: 'Roi du jeu', icon: 'game', description: '30 minutes de jeu video en bonus', requiredPoints: 100, powerType: 'game'),
    BadgeModel(id: 'power_outing', name: 'Sortie speciale', icon: 'outing', description: 'Choisis une sortie en famille', requiredPoints: 150, powerType: 'outing'),
  ];
}
