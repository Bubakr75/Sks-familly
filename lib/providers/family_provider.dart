// ════════════════════════════════════════════════════════
//  PUNISHMENT SUBMISSION (enfant soumet, parent valide)
// ════════════════════════════════════════════════════════

/// Enfant soumet des lignes avec photo de preuve
void submitPunishmentLines({
  required String childId,
  required String punishmentId,
  required int linesSubmitted,
  required String proofPhotoBase64,
}) {
  final punishments = getPunishments(childId);
  final index = punishments.indexWhere((p) => p['id'] == punishmentId);
  if (index == -1) return;

  final punishment = Map<String, dynamic>.from(punishments[index]);
  punishment['pendingSubmission'] = {
    'linesSubmitted': linesSubmitted,
    'proofPhotoBase64': proofPhotoBase64,
    'submittedAt': DateTime.now().toIso8601String(),
  };
  punishment['lastRejection'] = null; // Effacer le dernier rejet

  _savePunishment(childId, punishmentId, punishment);
  notifyListeners();
}

/// Parent valide les lignes soumises
void validatePunishmentSubmission({
  required String childId,
  required String punishmentId,
  required int linesValidated,
  String? parentNote,
}) {
  final punishments = getPunishments(childId);
  final index = punishments.indexWhere((p) => p['id'] == punishmentId);
  if (index == -1) return;

  final punishment = Map<String, dynamic>.from(punishments[index]);
  final currentCompleted = punishment['completedLines'] ?? 0;
  final total = punishment['totalLines'] ?? 0;
  punishment['completedLines'] = (currentCompleted + linesValidated).clamp(0, total);
  punishment['pendingSubmission'] = null;

  // Historique de validations
  final validations = List<Map<String, dynamic>>.from(punishment['validationHistory'] ?? []);
  validations.add({
    'linesValidated': linesValidated,
    'parentNote': parentNote,
    'validatedAt': DateTime.now().toIso8601String(),
  });
  punishment['validationHistory'] = validations;

  _savePunishment(childId, punishmentId, punishment);

  addHistoryEntry(
    childId: childId,
    points: 0,
    reason: '✅ $linesValidated lignes de punition validées par le parent',
    category: 'punishment_validated',
    isBonus: false,
  );

  notifyListeners();
}

/// Parent refuse les lignes soumises
void rejectPunishmentSubmission({
  required String childId,
  required String punishmentId,
  String? parentNote,
}) {
  final punishments = getPunishments(childId);
  final index = punishments.indexWhere((p) => p['id'] == punishmentId);
  if (index == -1) return;

  final punishment = Map<String, dynamic>.from(punishments[index]);
  punishment['lastRejection'] = {
    'parentNote': parentNote,
    'rejectedAt': DateTime.now().toIso8601String(),
  };
  punishment['pendingSubmission'] = null;

  _savePunishment(childId, punishmentId, punishment);
  notifyListeners();
}

// ════════════════════════════════════════════════════════
//  IMMUNITY USE REQUEST (enfant demande, parent valide)
// ════════════════════════════════════════════════════════

/// Enfant demande à utiliser une immunité sur une punition
void requestImmunityUse({
  required String childId,
  required String punishmentId,
  required String immunityId,
  required int linesToRemove,
}) {
  final punishments = getPunishments(childId);
  final index = punishments.indexWhere((p) => p['id'] == punishmentId);
  if (index == -1) return;

  final punishment = Map<String, dynamic>.from(punishments[index]);
  punishment['pendingImmunityRequest'] = {
    'immunityId': immunityId,
    'linesToRemove': linesToRemove,
    'requestedAt': DateTime.now().toIso8601String(),
  };

  _savePunishment(childId, punishmentId, punishment);
  notifyListeners();
}

/// Parent refuse la demande d'immunité
void rejectImmunityRequest({
  required String childId,
  required String punishmentId,
}) {
  final punishments = getPunishments(childId);
  final index = punishments.indexWhere((p) => p['id'] == punishmentId);
  if (index == -1) return;

  final punishment = Map<String, dynamic>.from(punishments[index]);
  punishment['pendingImmunityRequest'] = null;

  _savePunishment(childId, punishmentId, punishment);
  notifyListeners();
}

/// Effacer la demande d'immunité (après validation)
void clearImmunityRequest({
  required String childId,
  required String punishmentId,
}) {
  final punishments = getPunishments(childId);
  final index = punishments.indexWhere((p) => p['id'] == punishmentId);
  if (index == -1) return;

  final punishment = Map<String, dynamic>.from(punishments[index]);
  punishment['pendingImmunityRequest'] = null;

  _savePunishment(childId, punishmentId, punishment);
  notifyListeners();
}

/// Helper pour sauvegarder une punition
void _savePunishment(String childId, String punishmentId, Map<String, dynamic> data) {
  final key = '${childId}_$punishmentId';
  _punishmentBox.put(key, data);
}

// ════════════════════════════════════════════════════════
//  SCHOOL NOTES SUBMISSION (enfant soumet, parent valide)
// ════════════════════════════════════════════════════════

/// Enfant soumet une note scolaire avec preuve photo
void submitSchoolNote({
  required String childId,
  required String subject,
  required double value,
  required double maxValue,
  required String proofPhotoBase64,
}) {
  final id = 'note_${DateTime.now().millisecondsSinceEpoch}';
  final noteData = {
    'id': id,
    'childId': childId,
    'subject': subject,
    'value': value,
    'maxValue': maxValue,
    'proofPhotoBase64': proofPhotoBase64,
    'submittedAt': DateTime.now().toIso8601String(),
    'status': 'pending',
  };

  final key = '${childId}_pending_note_$id';
  _schoolNotesBox.put(key, noteData);
  notifyListeners();
}

/// Récupérer les notes en attente d'un enfant
List<Map<String, dynamic>> getPendingSchoolNotes(String childId) {
  final results = <Map<String, dynamic>>[];
  for (final key in _schoolNotesBox.keys) {
    if (key.toString().startsWith('${childId}_pending_note_')) {
      final data = Map<String, dynamic>.from(_schoolNotesBox.get(key));
      if (data['status'] == 'pending') {
        results.add(data);
      }
    }
  }
  return results;
}

/// Récupérer les notes rejetées d'un enfant
List<Map<String, dynamic>> getRejectedSchoolNotes(String childId) {
  final results = <Map<String, dynamic>>[];
  for (final key in _schoolNotesBox.keys) {
    if (key.toString().startsWith('${childId}_pending_note_') ||
        key.toString().startsWith('${childId}_rejected_note_')) {
      final data = Map<String, dynamic>.from(_schoolNotesBox.get(key));
      if (data['status'] == 'rejected') {
        results.add(data);
      }
    }
  }
  return results;
}

/// Parent valide une note scolaire
void validateSchoolNote({
  required String childId,
  required String noteId,
  required double adjustedValue,
  required double maxValue,
  required String subject,
  String? proofPhotoBase64,
  String? parentNote,
}) {
  // Supprimer de la liste pending
  final pendingKey = '${childId}_pending_note_$noteId';
  _schoolNotesBox.delete(pendingKey);

  // Calculer les points bonus
  final normalizedNote = maxValue > 0 ? (adjustedValue / maxValue) * 20 : 0;
  int bonusPoints = 0;
  if (normalizedNote >= 18) bonusPoints = 5;
  else if (normalizedNote >= 15) bonusPoints = 3;
  else if (normalizedNote >= 12) bonusPoints = 2;
  else if (normalizedNote >= 10) bonusPoints = 1;

  // Ajouter dans l'historique comme note validée
  addPoints(
    childId: childId,
    points: bonusPoints,
    reason: '$subject|$adjustedValue|$maxValue',
    category: 'school_note',
    isBonus: true,
    proofPhotoBase64: proofPhotoBase64,
  );

  notifyListeners();
}

/// Parent refuse une note scolaire
void rejectSchoolNote({
  required String childId,
  required String noteId,
  String? parentNote,
}) {
  final pendingKey = '${childId}_pending_note_$noteId';
  final data = _schoolNotesBox.get(pendingKey);
  if (data == null) return;

  final noteData = Map<String, dynamic>.from(data);
  noteData['status'] = 'rejected';
  noteData['parentNote'] = parentNote;
  noteData['rejectedAt'] = DateTime.now().toIso8601String();

  // Sauvegarder comme rejetée
  final rejectedKey = '${childId}_rejected_note_$noteId';
  _schoolNotesBox.put(rejectedKey, noteData);
  _schoolNotesBox.delete(pendingKey);

  notifyListeners();
}
