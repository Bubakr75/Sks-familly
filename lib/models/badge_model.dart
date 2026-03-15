class BadgeModel {
  String id;
  String name;
  String icon;
  String description;
  int requiredPoints;

  BadgeModel({
    required this.id,
    required this.name,
    required this.icon,
    required this.description,
    required this.requiredPoints,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'icon': icon,
        'description': description,
        'requiredPoints': requiredPoints,
      };

  factory BadgeModel.fromMap(Map<String, dynamic> map) => BadgeModel(
        id: map['id'] ?? '',
        name: map['name'] ?? '',
        icon: map['icon'] ?? '',
        description: map['description'] ?? '',
        requiredPoints: map['requiredPoints'] ?? 0,
      );

  static List<BadgeModel> defaultBadges = [
    BadgeModel(id: 'first_points', name: 'Première Étoile', icon: 'star', description: 'Gagne tes premiers points', requiredPoints: 10),
    BadgeModel(id: 'top_50', name: 'Apprenti', icon: 'school', description: 'Atteins 50 points', requiredPoints: 50),
    BadgeModel(id: 'top_100', name: 'Bon Comportement', icon: 'thumb_up', description: 'Atteins 100 points', requiredPoints: 100),
    BadgeModel(id: 'top_200', name: 'Assistant(e) du Foyer', icon: 'home', description: 'Atteins 200 points', requiredPoints: 200),
    BadgeModel(id: 'top_500', name: 'Expert', icon: 'emoji_events', description: 'Atteins 500 points', requiredPoints: 500),
    BadgeModel(id: 'top_1000', name: 'Champion', icon: 'military_tech', description: 'Atteins 1000 points', requiredPoints: 1000),
  ];
}
