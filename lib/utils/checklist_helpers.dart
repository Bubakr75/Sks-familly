// lib/utils/checklist_helpers.dart
//
// Helpers testables pour les requestKeys de checklist et le montant réel.
// Extraits de ChecklistScreen et PointActionPanel pour être testés unitairement.

import '../models/chore_model.dart';

/// Construit une requestKey stable et précise pour une validation de checklist.
/// Inclut : type, childId, date YYYY-MM-DD, tâches done triées, montant total.
String buildChecklistRequestKey({
  required String childId,
  required String dateStr,
  required List<ChoreModel> chores,
  required Map<String, String> doneStates,
}) {
  final doneKeys = <String>[];
  int donePts = 0;
  const allSlots = ['matin', 'midi', 'soir'];
  for (final c in chores) {
    final slots = c.timeSlots ?? allSlots;
    for (final slot in slots) {
      final key = '$childId|${c.id}|$slot';
      if (doneStates[key] == 'done') {
        doneKeys.add('${c.id}:$slot');
        donePts += c.points;
      }
    }
  }
  doneKeys.sort();
  return 'chore_checklist|$childId|$dateStr|${doneKeys.join(",")}|$donePts';
}

/// Date du jour au format YYYY-MM-DD (mois/jour sur 2 chiffres).
String todayDateStr() {
  final t = DateTime.now();
  return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
}

/// Calcule le montant réel d'une pénalité : min(demandé, solde) ou 0 si solde ≤ 0.
/// Pour un bonus, retourne toujours le montant demandé.
int actualPenaltyAmount(
    {required int requested, required int balance, required bool isBonus}) {
  if (isBonus) return requested;
  if (balance <= 0) return 0;
  return requested.clamp(1, balance);
}

/// Tente de parser le résultat de Gemini (int, double, ou String numérique).
/// Retourne null si invalide.
int? parseGeminiPoints(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) {
    if (value.isNaN || value.isInfinite) return null;
    return value.round();
  }
  if (value is String) {
    final parsed = int.tryParse(value.trim());
    return parsed;
  }
  return null;
}

/// Valide le type retourné par Gemini.
/// Accepte 'bonus', 'penalty', 'pénalité' (insensible à la casse).
/// Retourne true si c'est un bonus, false si pénalité, null si invalide.
bool? parseGeminiType(String? type) {
  if (type == null) return null;
  final lower = type.toLowerCase().trim();
  if (lower == 'bonus') return true;
  if (lower == 'penalty' || lower == 'pénalité') return false;
  return null;
}
