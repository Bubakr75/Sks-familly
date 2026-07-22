// lib/screens/penalty_screen.dart
//
// Écran Pénalité moderne — utilise PointActionPanel avec configuration pénalité.
// Style corail/rouge doux, présentation calme et parentale.

import 'package:flutter/material.dart';
import '../config/emerald_theme.dart';
import '../widgets/point_action_panel.dart';

class PenaltyScreen extends StatelessWidget {
  const PenaltyScreen({super.key});

  static const _config = PointActionConfig(
    title: '⚠️ Pénalité',
    subtitle: 'Corrige un mauvais comportement',
    buttonText: 'Appliquer la pénalité',
    category: 'Pénalité',
    isBonus: false,
    primaryColor: Color(0xFFF87171),
    accentColor: Color(0xFFFCA5A5),
    backgroundColor: Color(0xFF0F2620),
    buttonIcon: Icons.warning_amber_rounded,
    successMessage: '⚠️ Pénalité de {amount} pts appliquée à {name}',
    motifs: [
      ActionMotif('😤', 'Insolence', 10),
      ActionMotif('🥊', 'Bagarre', 15),
      ActionMotif('📱', 'Écran interdit', 5),
      ActionMotif('🙅', 'Désobéissance', 10),
      ActionMotif('🤬', 'Gros mot', 5),
      ActionMotif('😈', 'Bêtise', 5),
      ActionMotif('🤥', 'Mensonge', 10),
      ActionMotif('🧦', 'Désordre', 5),
      ActionMotif(
        '🔎',
        'Autre comportement',
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
        title: const Text('⚠️ Pénalité',
            style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
      ),
      body: const PointActionPanel(config: _config),
    );
  }
}
