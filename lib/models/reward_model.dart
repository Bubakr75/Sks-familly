// lib/models/reward_model.dart
//
// Modèle pour les récompenses de la Boutique SKS Family.
// Les parents créent des récompenses (ex: "15 min de console = 50 pts").
// Les enfants les achètent avec leurs points bonus.

class RewardModel {
  String id;
  String title;          // Ex: "15 min de console"
  String description;    // Ex: "Tu peux jouer 15 min de plus sur ta console"
  int cost;              // Coût en points (ex: 50)
  String icon;           // Emoji ou icône (ex: "🎮")
  String category;       // 'privilege', 'treat', 'chore_pass', 'custom'
  bool isActive;         // Si la récompense est disponible à l'achat
  int? maxPerWeek;       // Limite d'achat par semaine (null = illimité)
  DateTime createdAt;

  RewardModel({
    required this.id,
    required this.title,
    this.description = '',
    required this.cost,
    this.icon = '🎁',
    this.category = 'custom',
    this.isActive = true,
    this.maxPerWeek,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'cost': cost,
      'icon': icon,
      'category': category,
      'isActive': isActive,
      'maxPerWeek': maxPerWeek,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory RewardModel.fromMap(Map<String, dynamic> map) {
    return RewardModel(
      id: map['id'] ?? '',
      title: map['title'] ?? 'Récompense',
      description: map['description'] ?? '',
      cost: map['cost'] ?? 0,
      icon: map['icon'] ?? '🎁',
      category: map['category'] ?? 'custom',
      isActive: map['isActive'] ?? true,
      maxPerWeek: map['maxPerWeek'],
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
    );
  }

  /// Récompenses par défaut (pré-remplies quand une famille démarre)
  static List<RewardModel> get defaultRewards => [
    RewardModel(
      id: 'default_screen_time',
      title: '15 min d\'écran',
      description: '15 minutes supplémentaires de console, tablette ou TV',
      cost: 50,
      icon: '🎮',
      category: 'privilege',
      maxPerWeek: 4,
    ),
    RewardModel(
      id: 'default_bedtime',
      title: 'Coucher tardif',
      description: 'Se coucher 30 min plus tard le week-end',
      cost: 80,
      icon: '🌙',
      category: 'privilege',
      maxPerWeek: 1,
    ),
    RewardModel(
      id: 'default_meal_choice',
      title: 'Choix du repas',
      description: 'Tu choisis le repas d\'un soir de cette semaine',
      cost: 100,
      icon: '🍕',
      category: 'privilege',
      maxPerWeek: 1,
    ),
    RewardModel(
      id: 'default_chore_pass',
      title: 'Joker corvée',
      description: 'Échapper à une tâche ménagère de ton choix',
      cost: 150,
      icon: '🃏',
      category: 'chore_pass',
      maxPerWeek: 1,
    ),
    RewardModel(
      id: 'default_treat',
      title: 'Petite gourmandise',
      description: 'Une petite gourmandise au choix',
      cost: 60,
      icon: '🍫',
      category: 'treat',
    ),
    RewardModel(
      id: 'default_movie_choice',
      title: 'Choix du film',
      description: 'Tu choisis le film du vendredi soir',
      cost: 120,
      icon: '🎬',
      category: 'privilege',
      maxPerWeek: 1,
    ),
  ];
}
