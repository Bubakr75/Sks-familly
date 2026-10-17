import '../widgets/sks_brand_logo.dart';
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
    title: 'Pénalité',
    subtitle: 'Une règle claire, un suivi simple.',
    buttonText: 'Appliquer la pénalité',
    category: 'Pénalité',
    isBonus: false,
    primaryColor: EmeraldPalette.penalty,
    accentColor: EmeraldPalette.penalty,
    backgroundColor: EmeraldPalette.surface,
    buttonIcon: Icons.remove_circle_outline,
    successMessage: '⚠️ Pénalité de {amount} pts appliquée à {name}',
    motifs: [
      ActionMotif('penalty_insolence', '😤', 'Insolence', 1),
      ActionMotif('penalty_bagarre', '🥊', 'Bagarre', 1),
      ActionMotif('penalty_ecran', '📱', 'Écran interdit', 1),
      ActionMotif('penalty_desobeissance', '🙅', 'Désobéissance', 1),
      ActionMotif('penalty_grosmot', '🤬', 'Gros mot', 1),
      ActionMotif('penalty_betise', '😈', 'Bêtise', 1),
      ActionMotif('penalty_mensonge', '🤥', 'Mensonge', 1),
      ActionMotif('penalty_desordre', '🧦', 'Désordre', 1),
      ActionMotif(
        'penalty_autre',
        '🔎',
        'Autre comportement',
        1,
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
        title: const SksPageTitle('Pénalité'),
      ),
      body: const PointActionPanel(config: _config),
    );
  }
}
