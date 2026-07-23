// lib/utils/motif_helpers.dart
//
// Helpers testables pour les motifs personnalisés (Autre) et les raisons.

/// Normalise et trim un texte saisi pour un motif "Autre".
/// Retourne null si vide ou composé uniquement d'espaces.
String? normalizeCustomText(String? input) {
  if (input == null) return null;
  final trimmed = input.trim();
  if (trimmed.isEmpty) return null;
  return trimmed;
}

/// Valide un motif "Autre" : le texte doit être non vide après trim.
bool isValidCustomText(String? input) {
  return normalizeCustomText(input) != null;
}

/// Calcule la raison réellement enregistrée dans l'historique.
/// Pour un motif classique : retourne "emoji label".
/// Pour un motif "Autre" : retourne "emoji texte_saisi" (sans doublon d'emoji).
/// - isOther : true si le motif sélectionné est "Autre".
/// - emoji : l'emoji du motif (ex: "✨" ou "🔎").
/// - label : le label du motif classique, ou null/igné si Autre.
/// - customText : le texte saisi pour le motif Autre.
String buildReason({
  required bool isOther,
  required String emoji,
  String? label,
  String? customText,
}) {
  if (!isOther) {
    return '$emoji $label';
  }
  final text = normalizeCustomText(customText);
  if (text == null) return '$emoji Autre';
  // Éviter de doubler l'emoji si le texte en contient déjà un au début
  if (text.startsWith(emoji)) return text;
  return '$emoji $text';
}
