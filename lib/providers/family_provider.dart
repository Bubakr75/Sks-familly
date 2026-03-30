import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../models/badge_model.dart';
import '../models/history_entry.dart';
// Uncomment if you use Firebase:
// import 'package:cloud_firestore/cloud_firestore.dart';

class FamilyProvider extends ChangeNotifier {
  // ==================== HIVE BOXES ====================
  Box? _childrenBox;
  Box? _historyBox;
  Box? _goalsBox;
  Box? _notesBox;
  Box? _punishmentsBox;
  Box? _immunitiesBox;
  Box? _tribunalBox;
  Box? _customBadgesBox;
  Box? _metaBox;
  Box? _screenTimeBox;
  Box? _tradesBox;
  Box? _schoolNotesBox;

  // ==================== GETTERS BOXES ====================
  Box? get schoolNotesBox => _schoolNotesBox;
  Box? get punishmentsBox => _punishmentsBox;
  Box? get immunitiesBox => _immunitiesBox;

  // ==================== STATE ====================
  String? _familyCode;
  String? get familyCode => _familyCode;

  List<Map<String, dynamic>> get children {
    if (_childrenBox == null) return [];
    return _childrenBox!.values
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  List<Map<String, dynamic>> get history {
    if (_historyBox == null) return [];
    return _historyBox!.values
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  List<Map<String, dynamic>> get goals {
    if (_goalsBox == null) return [];
    return _goalsBox!.values
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  List<Map<String, dynamic>> get notes {
    if (_notesBox == null) return [];
    return _notesBox!.values
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  List<Map<String, dynamic>> get punishments {
    if (_punishmentsBox == null) return [];
    return _punishmentsBox!.values
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  List<Map<String, dynamic>> get immunities {
    if (_immunitiesBox == null) return [];
    return _immunitiesBox!.values
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  List<Map<String, dynamic>> get tribunalCases {
    if (_tribunalBox == null) return [];
    return _tribunalBox!.values
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  List<Map<String, dynamic>> get customBadges {
    if (_customBadgesBox == null) return [];
    return _customBadgesBox!.values
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  List<Map<String, dynamic>> get trades {
    if (_tradesBox == null) return [];
    return _tradesBox!.values
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  List<Map<String, dynamic>> get schoolNotes {
    if (_schoolNotesBox == null) return [];
    return _schoolNotesBox!.values
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  // ==================== INITIALIZATION ====================

  Future<void> init() async {
    _childrenBox = await Hive.openBox('children');
    _historyBox = await Hive.openBox('history');
    _goalsBox = await Hive.openBox('goals');
    _notesBox = await Hive.openBox('notes');
    _punishmentsBox = await Hive.openBox('punishments');
    _immunitiesBox = await Hive.openBox('immunities');
    _tribunalBox = await Hive.openBox('tribunal');
    _customBadgesBox = await Hive.openBox('custom_badges');
    _metaBox = await Hive.openBox('meta');
    _screenTimeBox = await Hive.openBox('screen_time');
    _tradesBox = await Hive.openBox('trades');
    _schoolNotesBox = await Hive.openBox('school_notes');

    // Load meta
    _familyCode = _metaBox?.get('familyCode');

    notifyListeners();
  }

  // ==================== FAMILY MANAGEMENT ====================

  Future<void> createFamily(String code) async {
    _familyCode = code;
    await _metaBox?.put('familyCode', code);
    notifyListeners();
  }

  Future<void> joinFamily(String code) async {
    _familyCode = code;
    await _metaBox?.put('familyCode', code);
    // Sync from Firestore if available
    notifyListeners();
  }

  Future<void> disconnectFamily() async {
    _familyCode = null;
    await _metaBox?.delete('familyCode');
    notifyListeners();
  }

  Future<void> changeFamilyCode(String newCode) async {
    _familyCode = newCode;
    await _metaBox?.put('familyCode', newCode);
    notifyListeners();
  }

  // ==================== CHILDREN ====================

  Future<void> addChild(String name) async {
    final child = {
      'id': const Uuid().v4(),
      'name': name,
      'points': 0,
      'photoBase64': null,
      'unlockedBadges': <String>[],
      'createdAt': DateTime.now().toIso8601String(),
    };
    await _childrenBox?.add(child);
    await _syncToFirestore('children', _childrenBox);
    notifyListeners();
  }

  Future<void> updateChild(String childId, Map<String, dynamic> updates) async {
    if (_childrenBox == null) return;
    final entries = _childrenBox!.values.toList();
    final index = entries.indexWhere((c) => c['id'] == childId);
    if (index == -1) return;
    final child = Map<String, dynamic>.from(entries[index] as Map);
    child.addAll(updates);
    await _childrenBox!.putAt(index, child);
    await _syncToFirestore('children', _childrenBox);
    notifyListeners();
  }

  Future<void> updateChildPhoto(String childId, String? photoBase64) async {
    await updateChild(childId, {'photoBase64': photoBase64});
  }

  Future<void> removeChild(String childId) async {
    if (_childrenBox == null) return;
    final entries = _childrenBox!.values.toList();
    final index = entries.indexWhere((c) => c['id'] == childId);
    if (index != -1) {
      await _childrenBox!.deleteAt(index);
      await _syncToFirestore('children', _childrenBox);
      notifyListeners();
    }
  }

  // ==================== POINTS ====================

  Future<String?> addPoints(
    String childId,
    int points,
    String reason, {
    String category = 'Bonus',
    bool isBonus = true,
    String? proofPhotoBase64,
    String? actionBy,
  }) async {
    // Update child points
    if (_childrenBox == null) return null;
    final entries = _childrenBox!.values.toList();
    final childIndex = entries.indexWhere((c) => c['id'] == childId);
    if (childIndex == -1) return null;

    final child = Map<String, dynamic>.from(entries[childIndex] as Map);
    child['points'] = ((child['points'] as int?) ?? 0) + points;
    await _childrenBox!.putAt(childIndex, child);

    // Create history entry
    final entryId = const Uuid().v4();
    final entry = {
      'id': entryId,
      'childId': childId,
      'points': points,
      'reason': reason,
      'category': category,
      'isBonus': isBonus,
      'date': DateTime.now().toIso8601String(),
      'proofPhotoBase64': proofPhotoBase64,
      'actionBy': actionBy,
    };
    await _historyBox?.add(entry);

    // Check badge unlocks
    _checkBadgeUnlocks(childId, child['points'] as int);

    await _syncToFirestore('children', _childrenBox);
    await _syncToFirestore('history', _historyBox);
    notifyListeners();

    return entryId;
  }

  // ==================== BADGES ====================

  void _checkBadgeUnlocks(String childId, int totalPoints) {
    if (_childrenBox == null) return;
    final entries = _childrenBox!.values.toList();
    final childIndex = entries.indexWhere((c) => c['id'] == childId);
    if (childIndex == -1) return;

    final child = Map<String, dynamic>.from(entries[childIndex] as Map);
    final unlocked = List<String>.from(child['unlockedBadges'] ?? []);

    for (final badge in BadgeModel.defaultBadges) {
      if (!unlocked.contains(badge.id) && totalPoints >= badge.requiredPoints) {
        unlocked.add(badge.id);
      }
    }

    // Check custom badges
    for (final cb in customBadges) {
      final bid = cb['id'] as String?;
      final req = (cb['requiredPoints'] as int?) ?? 999999;
      if (bid != null && !unlocked.contains(bid) && totalPoints >= req) {
        unlocked.add(bid);
      }
    }

    child['unlockedBadges'] = unlocked;
    _childrenBox!.putAt(childIndex, child);
  }

  Future<void> unlockBadge(String childId, String badgeId) async {
    if (_childrenBox == null) return;
    final entries = _childrenBox!.values.toList();
    final childIndex = entries.indexWhere((c) => c['id'] == childId);
    if (childIndex == -1) return;
    final child = Map<String, dynamic>.from(entries[childIndex] as Map);
    final unlocked = List<String>.from(child['unlockedBadges'] ?? []);
    if (!unlocked.contains(badgeId)) {
      unlocked.add(badgeId);
      child['unlockedBadges'] = unlocked;
      await _childrenBox!.putAt(childIndex, child);
      await _syncToFirestore('children', _childrenBox);
      notifyListeners();
    }
  }

  // ==================== GOALS ====================

  Future<void> addGoal(String childId, String title, int targetPoints) async {
    final goal = {
      'id': const Uuid().v4(),
      'childId': childId,
      'title': title,
      'targetPoints': targetPoints,
      'completed': false,
      'createdAt': DateTime.now().toIso8601String(),
    };
    await _goalsBox?.add(goal);
    await _syncToFirestore('goals', _goalsBox);
    notifyListeners();
  }

  Future<void> completeGoal(String goalId) async {
    if (_goalsBox == null) return;
    final entries = _goalsBox!.values.toList();
    final index = entries.indexWhere((g) => g['id'] == goalId);
    if (index == -1) return;
    final goal = Map<String, dynamic>.from(entries[index] as Map);
    goal['completed'] = true;
    await _goalsBox!.putAt(index, goal);
    await _syncToFirestore('goals', _goalsBox);
    notifyListeners();
  }

  Future<void> deleteGoal(String goalId) async {
    if (_goalsBox == null) return;
    final entries = _goalsBox!.values.toList();
    final index = entries.indexWhere((g) => g['id'] == goalId);
    if (index != -1) {
      await _goalsBox!.deleteAt(index);
      await _syncToFirestore('goals', _goalsBox);
      notifyListeners();
    }
  }

  // ==================== NOTES (parent notes) ====================

  Future<void> addNote(String childId, String content) async {
    final note = {
      'id': const Uuid().v4(),
      'childId': childId,
      'content': content,
      'date': DateTime.now().toIso8601String(),
    };
    await _notesBox?.add(note);
    await _syncToFirestore('notes', _notesBox);
    notifyListeners();
  }

  Future<void> deleteNote(String noteId) async {
    if (_notesBox == null) return;
    final entries = _notesBox!.values.toList();
    final index = entries.indexWhere((n) => n['id'] == noteId);
    if (index != -1) {
      await _notesBox!.deleteAt(index);
      await _syncToFirestore('notes', _notesBox);
      notifyListeners();
    }
  }

  // ==================== PUNISHMENTS ====================

  Future<void> addPunishment(
    String childId,
    String phrase,
    int totalLines,
  ) async {
    final punishment = {
      'id': const Uuid().v4(),
      'childId': childId,
      'phrase': phrase,
      'totalLines': totalLines,
      'completedLines': 0,
      'status': 'active',
      'submissions': <Map<String, dynamic>>[],
      'createdAt': DateTime.now().toIso8601String(),
    };
    await _punishmentsBox?.add(punishment);
    await _syncToFirestore('punishments', _punishmentsBox);
    notifyListeners();
  }

  Future<void> updatePunishment(
      String punishmentId, Map<String, dynamic> updates) async {
    if (_punishmentsBox == null) return;
    final entries = _punishmentsBox!.values.toList();
    final index = entries.indexWhere((p) => p['id'] == punishmentId);
    if (index == -1) return;
    final punishment = Map<String, dynamic>.from(entries[index] as Map);
    punishment.addAll(updates);
    await _punishmentsBox!.putAt(index, punishment);
    await _syncToFirestore('punishments', _punishmentsBox);
    notifyListeners();
  }

  Future<void> submitPunishmentLines(
    String punishmentId,
    int lineCount, {
    String? photoBase64,
  }) async {
    if (_punishmentsBox == null) return;
    final entries = _punishmentsBox!.values.toList();
    final index = entries.indexWhere((p) => p['id'] == punishmentId);
    if (index == -1) return;
    final punishment = Map<String, dynamic>.from(entries[index] as Map);

    final submissions =
        List<Map<String, dynamic>>.from(punishment['submissions'] ?? []);
    submissions.add({
      'id': const Uuid().v4(),
      'lineCount': lineCount,
      'photoBase64': photoBase64,
      'status': 'pending',
      'date': DateTime.now().toIso8601String(),
    });

    punishment['submissions'] = submissions;
    await _punishmentsBox!.putAt(index, punishment);
    await _syncToFirestore('punishments', _punishmentsBox);
    notifyListeners();
  }

  Future<void> validatePunishmentSubmission(
    String punishmentId,
    String submissionId, {
    required bool approved,
    String? note,
    int? approvedLines,
  }) async {
    if (_punishmentsBox == null) return;
    final entries = _punishmentsBox!.values.toList();
    final index = entries.indexWhere((p) => p['id'] == punishmentId);
    if (index == -1) return;
    final punishment = Map<String, dynamic>.from(entries[index] as Map);

    final submissions =
        List<Map<String, dynamic>>.from(punishment['submissions'] ?? []);
    final subIndex = submissions.indexWhere((s) => s['id'] == submissionId);
    if (subIndex == -1) return;

    submissions[subIndex]['status'] = approved ? 'approved' : 'rejected';
    submissions[subIndex]['note'] = note;

    if (approved) {
      final lines =
          approvedLines ?? (submissions[subIndex]['lineCount'] as int? ?? 0);
      punishment['completedLines'] =
          ((punishment['completedLines'] as int?) ?? 0) + lines;

      if ((punishment['completedLines'] as int) >=
          (punishment['totalLines'] as int? ?? 0)) {
        punishment['status'] = 'completed';
      }
    }

    punishment['submissions'] = submissions;
    await _punishmentsBox!.putAt(index, punishment);
    await _syncToFirestore('punishments', _punishmentsBox);
    notifyListeners();
  }

  // Photo handling for punishments
  Future<void> addPunishmentPhoto(
      String punishmentId, String photoBase64) async {
    await updatePunishment(punishmentId, {'proofPhoto': photoBase64});
  }

  // ==================== IMMUNITIES ====================

  Future<void> addImmunity(
    String childId,
    String name,
    String type, {
    int maxUses = 1,
    String? description,
  }) async {
    final immunity = {
      'id': const Uuid().v4(),
      'childId': childId,
      'name': name,
      'type': type,
      'maxUses': maxUses,
      'usedCount': 0,
      'status': 'active',
      'description': description ?? '',
      'createdAt': DateTime.now().toIso8601String(),
    };
    await _immunitiesBox?.add(immunity);
    await _syncToFirestore('immunities', _immunitiesBox);
    notifyListeners();
  }

  Future<void> useImmunity(String childId, String immunityId) async {
    if (_immunitiesBox == null) return;
    final entries = _immunitiesBox!.values.toList();
    final index = entries.indexWhere(
        (i) => i['id'] == immunityId && i['childId'] == childId);
    if (index == -1) return;
    final immunity = Map<String, dynamic>.from(entries[index] as Map);
    immunity['usedCount'] = ((immunity['usedCount'] as int?) ?? 0) + 1;
    if ((immunity['usedCount'] as int) >= (immunity['maxUses'] as int? ?? 1)) {
      immunity['status'] = 'used';
    }
    await _immunitiesBox!.putAt(index, immunity);
    await _syncToFirestore('immunities', _immunitiesBox);
    notifyListeners();
  }

  Future<void> useImmunityOnPunishment(
    String childId,
    String immunityId,
    String punishmentId,
  ) async {
    // Use the immunity
    await useImmunity(childId, immunityId);

    // Mark punishment as immunized
    if (_punishmentsBox == null) return;
    final entries = _punishmentsBox!.values.toList();
    final index = entries.indexWhere((p) => p['id'] == punishmentId);
    if (index == -1) return;
    final punishment = Map<String, dynamic>.from(entries[index] as Map);
    punishment['status'] = 'immunized';
    punishment['immunityUsed'] = immunityId;
    await _punishmentsBox!.putAt(index, punishment);
    await _syncToFirestore('punishments', _punishmentsBox);
    notifyListeners();
  }

  /// Named-parameter wrapper for useImmunityOnPunishment
  Future<void> useImmunityOnPunishmentNamed({
    required String immunityId,
    required String punishmentId,
    required String childId,
  }) async {
    await useImmunityOnPunishment(childId, immunityId, punishmentId);
  }

  int getImmunityTotal(String childId) {
    return immunities.where((i) => i['childId'] == childId).length;
  }

  int getImmunityUsed(String childId) {
    return immunities
        .where((i) => i['childId'] == childId && i['status'] == 'used')
        .length;
  }

  int getImmunityActive(String childId) {
    return immunities
        .where((i) => i['childId'] == childId && i['status'] == 'active')
        .length;
  }

  // ==================== CUSTOM BADGES ====================

  Future<void> addCustomBadge(Map<String, dynamic> badge) async {
    badge['id'] ??= const Uuid().v4();
    badge['isCustom'] = true;
    await _customBadgesBox?.add(badge);
    await _syncToFirestore('custom_badges', _customBadgesBox);
    notifyListeners();
  }

  Future<void> deleteCustomBadge(String badgeId) async {
    if (_customBadgesBox == null) return;
    final entries = _customBadgesBox!.values.toList();
    final index = entries.indexWhere((b) => b['id'] == badgeId);
    if (index != -1) {
      await _customBadgesBox!.deleteAt(index);
      await _syncToFirestore('custom_badges', _customBadgesBox);
      notifyListeners();
    }
  }

  // ==================== SCREEN TIME ====================

  int getSaturdayMinutes(String childId) {
    if (_screenTimeBox == null) return 0;
    final key = '${childId}_saturday';
    return (_screenTimeBox!.get(key) as int?) ?? 0;
  }

  int getSundayMinutes(String childId) {
    if (_screenTimeBox == null) return 0;
    final key = '${childId}_sunday';
    return (_screenTimeBox!.get(key) as int?) ?? 0;
  }

  int getParentBonusMinutes(String childId) {
    if (_screenTimeBox == null) return 0;
    final key = '${childId}_bonus';
    return (_screenTimeBox!.get(key) as int?) ?? 0;
  }

  Future<void> setSaturdayMinutes(String childId, int minutes) async {
    await _screenTimeBox?.put('${childId}_saturday', minutes);
    await _syncToFirestore('screen_time', _screenTimeBox);
    notifyListeners();
  }

  Future<void> setSundayMinutes(String childId, int minutes) async {
    await _screenTimeBox?.put('${childId}_sunday', minutes);
    await _syncToFirestore('screen_time', _screenTimeBox);
    notifyListeners();
  }

  Future<void> setParentBonusMinutes(String childId, int minutes) async {
    await _screenTimeBox?.put('${childId}_bonus', minutes);
    await _syncToFirestore('screen_time', _screenTimeBox);
    notifyListeners();
  }

  int getSaturdayRating(String childId) {
    if (_screenTimeBox == null) return 0;
    return (_screenTimeBox!.get('${childId}_sat_rating') as int?) ?? 0;
  }

  Future<void> setSaturdayRating(String childId, int rating) async {
    await _screenTimeBox?.put('${childId}_sat_rating', rating);
    await _syncToFirestore('screen_time', _screenTimeBox);
    notifyListeners();
  }

  // ==================== WEEKLY SCORE ====================

  int calculateWeeklyScore(String childId) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekStartDate =
        DateTime(weekStart.year, weekStart.month, weekStart.day);

    int score = 0;
    for (final entry in history) {
      if (entry['childId'] != childId) continue;
      final date = DateTime.tryParse(entry['date'] ?? '');
      if (date != null && date.isAfter(weekStartDate)) {
        score += (entry['points'] as int?) ?? 0;
      }
    }
    return score;
  }

  // ==================== TRIBUNAL ====================

  Future<void> addTribunalCase(
    String accusedId,
    String accuserId,
    String description,
  ) async {
    final caseItem = {
      'id': const Uuid().v4(),
      'accusedId': accusedId,
      'accuserId': accuserId,
      'description': description,
      'status': 'open',
      'votes': <Map<String, dynamic>>[],
      'verdict': null,
      'createdAt': DateTime.now().toIso8601String(),
    };
    await _tribunalBox?.add(caseItem);
    await _syncToFirestore('tribunal', _tribunalBox);
    notifyListeners();
  }

  Future<void> updateTribunalCase(
      String caseId, Map<String, dynamic> updates) async {
    if (_tribunalBox == null) return;
    final entries = _tribunalBox!.values.toList();
    final index = entries.indexWhere((c) => c['id'] == caseId);
    if (index == -1) return;
    final caseItem = Map<String, dynamic>.from(entries[index] as Map);
    caseItem.addAll(updates);
    await _tribunalBox!.putAt(index, caseItem);
    await _syncToFirestore('tribunal', _tribunalBox);
    notifyListeners();
  }

  Future<void> voteTribunalCase(
    String caseId,
    String voterId,
    String vote,
  ) async {
    if (_tribunalBox == null) return;
    final entries = _tribunalBox!.values.toList();
    final index = entries.indexWhere((c) => c['id'] == caseId);
    if (index == -1) return;
    final caseItem = Map<String, dynamic>.from(entries[index] as Map);
    final votes =
        List<Map<String, dynamic>>.from(caseItem['votes'] ?? []);

    // Remove previous vote from same voter
    votes.removeWhere((v) => v['voterId'] == voterId);
    votes.add({
      'voterId': voterId,
      'vote': vote,
      'date': DateTime.now().toIso8601String(),
    });

    caseItem['votes'] = votes;
    await _tribunalBox!.putAt(index, caseItem);
    await _syncToFirestore('tribunal', _tribunalBox);
    notifyListeners();
  }

  Future<void> renderVerdict(
    String caseId,
    String verdict, {
    int? penaltyPoints,
  }) async {
    if (_tribunalBox == null) return;
    final entries = _tribunalBox!.values.toList();
    final index = entries.indexWhere((c) => c['id'] == caseId);
    if (index == -1) return;
    final caseItem = Map<String, dynamic>.from(entries[index] as Map);
    caseItem['status'] = 'closed';
    caseItem['verdict'] = verdict;
    caseItem['closedAt'] = DateTime.now().toIso8601String();

    await _tribunalBox!.putAt(index, caseItem);

    // Apply penalty if guilty
    if (verdict == 'guilty' && penaltyPoints != null && penaltyPoints > 0) {
      final accusedId = caseItem['accusedId'] as String?;
      if (accusedId != null) {
        await addPoints(
          accusedId,
          -penaltyPoints,
          'Tribunal: ${caseItem['description']}',
          category: 'Tribunal',
          isBonus: false,
        );
      }
    }

    await _syncToFirestore('tribunal', _tribunalBox);
    notifyListeners();
  }

  Future<void> distributeVotePoints(String caseId) async {
    if (_tribunalBox == null) return;
    final entries = _tribunalBox!.values.toList();
    final index = entries.indexWhere((c) => c['id'] == caseId);
    if (index == -1) return;
    final caseItem = Map<String, dynamic>.from(entries[index] as Map);
    final votes = List<Map<String, dynamic>>.from(caseItem['votes'] ?? []);

    for (final vote in votes) {
      final voterId = vote['voterId'] as String?;
      if (voterId != null) {
        await addPoints(
          voterId,
          1,
          'Participation au tribunal',
          category: 'Tribunal',
          isBonus: true,
        );
      }
    }
  }

  // ==================== TRADES ====================

  Future<void> createTrade(
    String fromChildId,
    String toChildId,
    String offer,
    String request,
  ) async {
    final trade = {
      'id': const Uuid().v4(),
      'fromChildId': fromChildId,
      'toChildId': toChildId,
      'offer': offer,
      'request': request,
      'status': 'pending',
      'createdAt': DateTime.now().toIso8601String(),
    };
    await _tradesBox?.add(trade);
    await _syncToFirestore('trades', _tradesBox);
    notifyListeners();
  }

  Future<void> _updateTrade(String tradeId, Map<String, dynamic> updates) async {
    if (_tradesBox == null) return;
    final entries = _tradesBox!.values.toList();
    final index = entries.indexWhere((t) => t['id'] == tradeId);
    if (index == -1) return;
    final trade = Map<String, dynamic>.from(entries[index] as Map);
    trade.addAll(updates);
    await _tradesBox!.putAt(index, trade);
    await _syncToFirestore('trades', _tradesBox);
    notifyListeners();
  }

  Future<void> acceptTrade(String tradeId) async {
    await _updateTrade(tradeId, {'status': 'accepted'});
  }

  Future<void> rejectTrade(String tradeId) async {
    await _updateTrade(tradeId, {'status': 'rejected'});
  }

  Future<void> cancelTrade(String tradeId) async {
    await _updateTrade(tradeId, {'status': 'cancelled'});
  }

  Future<void> markTradeDone(String tradeId) async {
    await _updateTrade(tradeId, {'status': 'done'});
  }

  Future<void> completeTrade(String tradeId) async {
    await _updateTrade(tradeId, {
      'status': 'completed',
      'completedAt': DateTime.now().toIso8601String(),
    });
  }

  // ==================== HISTORY / STATS HELPERS ====================

  List<Map<String, dynamic>> getChildHistory(String childId) {
    return history.where((h) => h['childId'] == childId).toList()
      ..sort((a, b) {
        final da = DateTime.tryParse(a['date'] ?? '') ?? DateTime(2000);
        final db = DateTime.tryParse(b['date'] ?? '') ?? DateTime(2000);
        return db.compareTo(da);
      });
  }

  List<Map<String, dynamic>> getChildBonuses(String childId) {
    return getChildHistory(childId)
        .where((h) => h['isBonus'] == true)
        .toList();
  }

  List<Map<String, dynamic>> getChildPenalties(String childId) {
    return getChildHistory(childId)
        .where((h) => h['isBonus'] == false)
        .toList();
  }

  int getTotalBonusPoints(String childId) {
    return getChildBonuses(childId)
        .fold<int>(0, (sum, h) => sum + ((h['points'] as int?) ?? 0));
  }

  int getTotalPenaltyPoints(String childId) {
    return getChildPenalties(childId)
        .fold<int>(0, (sum, h) => sum + ((h['points'] as int?) ?? 0).abs());
  }

  // ==================== PUNISHMENTS HELPERS (for admin) ====================

  List<Map<String, dynamic>> getPunishments(String childId) {
    return punishments.where((p) => p['childId'] == childId).toList();
  }

  List<Map<String, dynamic>> getImmunities(String childId) {
    return immunities.where((i) => i['childId'] == childId).toList();
  }

  // ==================== DELETE / EDIT (admin) ====================

  Future<void> deletePunishment(String punishmentId) async {
    if (_punishmentsBox == null) return;
    final entries = _punishmentsBox!.values.toList();
    final index = entries.indexWhere((p) => p['id'] == punishmentId);
    if (index != -1) {
      await _punishmentsBox!.deleteAt(index);
      await _syncToFirestore('punishments', _punishmentsBox);
      notifyListeners();
    }
  }

  Future<void> deleteImmunity(String immunityId) async {
    if (_immunitiesBox == null) return;
    final entries = _immunitiesBox!.values.toList();
    final index = entries.indexWhere((i) => i['id'] == immunityId);
    if (index != -1) {
      await _immunitiesBox!.deleteAt(index);
      await _syncToFirestore('immunities', _immunitiesBox);
      notifyListeners();
    }
  }

  Future<void> deleteHistoryEntry(String childId, String entryId,
      {bool reversePoints = false}) async {
    if (_historyBox == null) return;
    final entries = _historyBox!.values.toList();
    final index = entries.indexWhere(
        (e) => e['id'] == entryId && e['childId'] == childId);
    if (index == -1) return;

    if (reversePoints) {
      final entry = Map<String, dynamic>.from(entries[index] as Map);
      final points = (entry['points'] as int?) ?? 0;
      if (_childrenBox != null) {
        final childEntries = _childrenBox!.values.toList();
        final childIndex =
            childEntries.indexWhere((c) => c['id'] == childId);
        if (childIndex != -1) {
          final child =
              Map<String, dynamic>.from(childEntries[childIndex] as Map);
          child['points'] = ((child['points'] as int?) ?? 0) - points;
          await _childrenBox!.putAt(childIndex, child);
          await _syncToFirestore('children', _childrenBox);
        }
      }
    }

    await _historyBox!.deleteAt(index);
    await _syncToFirestore('history', _historyBox);
    notifyListeners();
  }

  Future<void> editHistoryEntry(
      String childId, String entryId, Map<String, dynamic> updates) async {
    if (_historyBox == null) return;
    final entries = _historyBox!.values.toList();
    final index = entries.indexWhere(
        (e) => e['id'] == entryId && e['childId'] == childId);
    if (index == -1) return;

    final entry = Map<String, dynamic>.from(entries[index] as Map);
    final oldPoints = (entry['points'] as int?) ?? 0;
    entry.addAll(updates);
    final newPoints = (entry['points'] as int?) ?? 0;

    if (newPoints != oldPoints && _childrenBox != null) {
      final childEntries = _childrenBox!.values.toList();
      final childIndex = childEntries.indexWhere((c) => c['id'] == childId);
      if (childIndex != -1) {
        final child =
            Map<String, dynamic>.from(childEntries[childIndex] as Map);
        child['points'] =
            ((child['points'] as int?) ?? 0) - oldPoints + newPoints;
        await _childrenBox!.putAt(childIndex, child);
        await _syncToFirestore('children', _childrenBox);
      }
    }

    await _historyBox!.putAt(index, entry);
    await _syncToFirestore('history', _historyBox);
    notifyListeners();
  }

  Future<void> clearChildHistory(String childId) async {
    if (_historyBox == null) return;
    final entries = _historyBox!.values.toList();
    for (int i = entries.length - 1; i >= 0; i--) {
      if (entries[i]['childId'] == childId) {
        await _historyBox!.deleteAt(i);
      }
    }
    await _syncToFirestore('history', _historyBox);
    notifyListeners();
  }

  Future<void> clearAllPunishments(String childId) async {
    if (_punishmentsBox == null) return;
    final entries = _punishmentsBox!.values.toList();
    for (int i = entries.length - 1; i >= 0; i--) {
      if (entries[i]['childId'] == childId) {
        await _punishmentsBox!.deleteAt(i);
      }
    }
    await _syncToFirestore('punishments', _punishmentsBox);
    notifyListeners();
  }

  Future<void> clearAllImmunities(String childId) async {
    if (_immunitiesBox == null) return;
    final entries = _immunitiesBox!.values.toList();
    for (int i = entries.length - 1; i >= 0; i--) {
      if (entries[i]['childId'] == childId) {
        await _immunitiesBox!.deleteAt(i);
      }
    }
    await _syncToFirestore('immunities', _immunitiesBox);
    notifyListeners();
  }

  Future<void> resetChildPoints(String childId) async {
    if (_childrenBox == null) return;
    final entries = _childrenBox!.values.toList();
    final index = entries.indexWhere((c) => c['id'] == childId);
    if (index == -1) return;
    final child = Map<String, dynamic>.from(entries[index] as Map);
    child['points'] = 0;
    await _childrenBox!.putAt(index, child);
    await _syncToFirestore('children', _childrenBox);
    notifyListeners();
  }

  Future<void> reactivateImmunity(String immunityId) async {
    if (_immunitiesBox == null) return;
    final entries = _immunitiesBox!.values.toList();
    final index = entries.indexWhere((i) => i['id'] == immunityId);
    if (index == -1) return;
    final immunity = Map<String, dynamic>.from(entries[index] as Map);
    immunity['status'] = 'active';
    immunity['usedCount'] = 0;
    await _immunitiesBox!.putAt(index, immunity);
    await _syncToFirestore('immunities', _immunitiesBox);
    notifyListeners();
  }

  Future<void> resetPunishmentProgress(String punishmentId) async {
    if (_punishmentsBox == null) return;
    final entries = _punishmentsBox!.values.toList();
    final index = entries.indexWhere((p) => p['id'] == punishmentId);
    if (index == -1) return;
    final punishment = Map<String, dynamic>.from(entries[index] as Map);
    punishment['completedLines'] = 0;
    punishment['status'] = 'active';
    punishment['submissions'] = <Map<String, dynamic>>[];
    await _punishmentsBox!.putAt(index, punishment);
    await _syncToFirestore('punishments', _punishmentsBox);
    notifyListeners();
  }

  Future<void> completePunishment(String punishmentId) async {
    if (_punishmentsBox == null) return;
    final entries = _punishmentsBox!.values.toList();
    final index = entries.indexWhere((p) => p['id'] == punishmentId);
    if (index == -1) return;
    final punishment = Map<String, dynamic>.from(entries[index] as Map);
    punishment['status'] = 'completed';
    punishment['completedLines'] = punishment['totalLines'] ?? 0;
    await _punishmentsBox!.putAt(index, punishment);
    await _syncToFirestore('punishments', _punishmentsBox);
    notifyListeners();
  }

  Future<void> resetEverything(String childId) async {
    await resetChildPoints(childId);
    await clearChildHistory(childId);
    await clearAllPunishments(childId);
    await clearAllImmunities(childId);
  }

  // ==================== SCHOOL NOTES ====================

  Future<void> addSchoolNote(
    String childId,
    String subject,
    double value,
    double maxValue, {
    String? comment,
    String? photoBase64,
  }) async {
    final note = {
      'id': const Uuid().v4(),
      'childId': childId,
      'subject': subject,
      'value': value,
      'maxValue': maxValue,
      'comment': comment ?? '',
      'photoBase64': photoBase64,
      'date': DateTime.now().toIso8601String(),
      'validated': null,
    };
    await _schoolNotesBox?.add(note);
    await _syncToFirestore('school_notes', _schoolNotesBox);
    notifyListeners();
  }

  Future<void> validateSchoolNote(String noteId,
      {required bool validated}) async {
    if (_schoolNotesBox == null) return;
    final entries = _schoolNotesBox!.values.toList();
    final index = entries.indexWhere((n) => n['id'] == noteId);
    if (index == -1) return;
    final note = Map<String, dynamic>.from(entries[index] as Map);
    note['validated'] = validated;
    await _schoolNotesBox!.putAt(index, note);
    await _syncToFirestore('school_notes', _schoolNotesBox);
    notifyListeners();
  }

  // ==================== HIVE HELPER ====================

  Future<void> _saveBoxFromList(Box box, List<Map<String, dynamic>> list) async {
    await box.clear();
    for (final item in list) {
      await box.add(item);
    }
  }

  // ==================== FIRESTORE SYNC ====================

  Future<void> _syncToFirestore(String collection, Box? box) async {
    if (_familyCode == null || _familyCode!.isEmpty || box == null) return;
    try {
      // TODO: Implement your Firestore sync logic
      // Example:
      // final data = box.values.toList().map((e) => Map<String, dynamic>.from(e as Map)).toList();
      // await FirebaseFirestore.instance
      //     .collection('families')
      //     .doc(_familyCode)
      //     .update({collection: data});
    } catch (e) {
      debugPrint('Sync error for $collection: $e');
    }
  }
}
