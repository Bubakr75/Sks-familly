# Skill: Audit Design SKS Family

## Quand utiliser
Quand on demande une amélioration visuelle, un audit design, ou avant une présentation.

## Ce que tu fais
1. Vérifie la cohérence des couleurs (toujours utiliser EmeraldPalette, pas de couleurs hardcodées)
2. Vérifie que tous les écrans utilisent le thème actif (pas de `Color(0xFF0A0E21)` hardcodé)
3. Cherche les `withOpacity` (déprécié) → doit être `withValues(alpha:)`
4. Vérifie les espacements (padding/margin cohérents)
5. Vérifie les tailles de texte (hiérarchie visuelle claire)
6. Cherche les widgets sans `errorBuilder` pour les images
7. Vérifie que les boutons ont un retour tactile (HapticFeedback)
8. Propose des améliorations visuelles concrètes

## Palette du projet
- Fond : EmeraldPalette.background (#051410)
- Surface : EmeraldPalette.surface (#0F2620)
- Accent : EmeraldPalette.emerald (#00E676)
- Or : EmeraldPalette.gold (#D4AF37)
- Texte : EmeraldPalette.textPrimary (#F5F1E8)

## Style
- Design "Emerald Premium" inspiré Apple Fitness + Stripe
- Cartes avec ombres + bordures
- Animations fluides (Curves.easeOutCubic)
- Glassmorphism léger
