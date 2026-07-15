// lib/models/wheel_segment.dart
//
// 🎡 Segment personnalisable de la roue de la fortune.
// Le parent crée ses propres gains : points, desserts, activités...

import 'package:flutter/material.dart';

class WheelSegment {
  String id;
  String label;       // Ex: "Dessert", "5 pts", "1h de jeu"
  String emoji;       // Ex: "🍰", "⭐", "🎮"
  int? points;        // Si null = récompense texte (ex: dessert)
  String? rewardText; // Texte de la récompense si non-points
  Color color;        // Couleur du segment

  WheelSegment({
    required this.id,
    required this.label,
    required this.emoji,
    this.points,
    this.rewardText,
    required this.color,
  });

  /// True si c'est des points
  bool get isPoints => points != null;

  /// Description de la récompense
  String get description => isPoints ? '$points pts' : (rewardText ?? label);

  Map<String, dynamic> toMap() => {
    'id': id,
    'label': label,
    'emoji': emoji,
    'points': points,
    'rewardText': rewardText,
    'color': color.toARGB32(),
  };

  factory WheelSegment.fromMap(Map<String, dynamic> map) => WheelSegment(
    id: map['id'] ?? '',
    label: map['label'] ?? 'Gain',
    emoji: map['emoji'] ?? '🎁',
    points: map['points'] != null ? (map['points'] as num).toInt() : null,
    rewardText: map['rewardText'],
    color: Color(map['color'] as int? ?? 0xFF2E7D32),
  );

  /// Segments par défaut (6 récompenses variées)
  static List<WheelSegment> defaults() => [
    WheelSegment(id: 'w1', label: '5 pts', emoji: '⭐', points: 5, color: const Color(0xFF2E7D32)),
    WheelSegment(id: 'w2', label: 'Dessert', emoji: '🍰', rewardText: 'Un dessert au choix', color: const Color(0xFFD4AF37)),
    WheelSegment(id: 'w3', label: '2 pts', emoji: '✨', points: 2, color: const Color(0xFF1565C0)),
    WheelSegment(id: 'w4', label: '10 pts', emoji: '🏆', points: 10, color: const Color(0xFF6A1B9A)),
    WheelSegment(id: 'w5', label: '30 min écran', emoji: '🎮', rewardText: '30 min d\'écran bonus', color: const Color(0xFF00838F)),
    WheelSegment(id: 'w6', label: 'Re-tente', emoji: '🔄', color: const Color(0xFF455A64)),
  ];
}
