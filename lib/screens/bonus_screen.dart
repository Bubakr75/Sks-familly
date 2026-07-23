// lib/screens/bonus_screen.dart
//
// Écran Bonus moderne — utilise PointActionPanel avec configuration bonus.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/emerald_theme.dart';
import '../widgets/point_action_panel.dart';

class BonusScreen extends StatelessWidget {
  const BonusScreen({super.key});

  static const _config = PointActionConfig(
    title: '✨ Bonus',
    subtitle: 'Récompense une bonne action',
    buttonText: 'Attribuer le bonus',
    category: 'Bonus',
    isBonus: true,
    primaryColor: Color(0xFF10B981),
    accentColor: Color(0xFF6EE7B7),
    backgroundColor: Color(0xFF0F2620),
    buttonIcon: Icons.star_rounded,
    successMessage: '✅ Bonus de {amount} pts attribué à {name} !',
    motifs: [
      ActionMotif('bonus_menage', '🧹', 'Ménage', 5),
      ActionMotif('bonus_devoirs', '📚', 'Devoirs', 10),
      ActionMotif('bonus_entraide', '🤝', 'Entraide', 5),
      ActionMotif('bonus_comportement', '😊', 'Bon comportement', 10),
      ActionMotif('bonus_cuisine', '🍳', 'Aide en cuisine', 5),
      ActionMotif('bonus_chambre', '🛏️', 'Chambre rangée', 5),
      ActionMotif('bonus_effort', '✏️', 'Effort scolaire', 10),
      ActionMotif('bonus_attitude', '🌟', 'Bonne attitude', 5),
      ActionMotif(
        'bonus_autre',
        '✨',
        'Autre bonne action',
        5,
        isOther: true,
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EmeraldPalette.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('✨ Bonus',
            style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
      ),
      body: const PointActionPanel(config: _config),
    );
  }
}
