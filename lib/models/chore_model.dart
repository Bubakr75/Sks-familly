// lib/models/chore_model.dart
//
// Modèle pour les tâches ménagères personnalisables de la Checklist du jour.
// Le parent crée/modifie les tâches, les enfants les cochent chaque matin.

class ChoreModel {
  String id;
  String label;       // Ex: "Ranger ma chambre"
  String emoji;       // Ex: "🛏️"
  int points;         // Points gagnés (Ex: 10)
  bool isActive;      // Si la tâche est active
  int order;          // Ordre d'affichage

  ChoreModel({
    required this.id,
    required this.label,
    this.emoji = '✅',
    required this.points,
    this.isActive = true,
    this.order = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'label': label,
      'emoji': emoji,
      'points': points,
      'isActive': isActive,
      'order': order,
    };
  }

  factory ChoreModel.fromMap(Map<String, dynamic> map) {
    return ChoreModel(
      id: map['id'] ?? '',
      label: map['label'] ?? 'Tâche',
      emoji: map['emoji'] ?? '✅',
      points: map['points'] ?? 5,
      isActive: map['isActive'] ?? true,
      order: map['order'] ?? 0,
    );
  }

  /// Tâches par défaut
  static List<ChoreModel> get defaultChores => [
    ChoreModel(id: 'chore_bedroom', label: 'Ranger ma chambre', emoji: '🛏️', points: 10, order: 0),
    ChoreModel(id: 'chore_bed', label: 'Faire mon lit', emoji: '🛌', points: 5, order: 1),
    ChoreModel(id: 'chore_dishes', label: 'Débarrasser la table', emoji: '🍽️', points: 8, order: 2),
    ChoreModel(id: 'chore_teeth', label: 'Brosser mes dents', emoji: '🪥', points: 3, order: 3),
    ChoreModel(id: 'chore_homework', label: 'Faire mes devoirs', emoji: '📚', points: 12, order: 4),
    ChoreModel(id: 'chore_toys', label: 'Ranger mes jouets', emoji: '🧸', points: 6, order: 5),
    ChoreModel(id: 'chore_trash', label: 'Sortir les poubelles', emoji: '🗑️', points: 7, order: 6),
    ChoreModel(id: 'chore_pets', label: 'Nourrir les animaux', emoji: '🐕', points: 8, order: 7),
  ];
}
