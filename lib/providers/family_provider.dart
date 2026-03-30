// lib/providers/family_provider.dart

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/child_model.dart';
import '../models/badge_model.dart';
import '../models/history_entry.dart';
import '../models/immunity_lines.dart';
import '../models/trade_model.dart';

class FamilyProvider extends ChangeNotifier {
  // ─── Hive boxes ───────────────────────────────────────
  late Box<Map> _childrenBox;
  late Box<Map> _historyBox;
  late Box<Map> _goalsBox;
  late Box<Map> _notesBox;
  late Box<Map> _punishmentsBox;
  late Box<Map> _immunitiesBox;
  late Box<Map> _tribunalBox;
  late Box<Map> _customBadgesBox;
  late Box<Map> _metaBox;
  late Box<Map> _screenTimeBox;
  late Box<Map> _tradesBox;
  late Box<Map> _schoolNotesBox;

  String? _familyCode;
  bool _isSyncEnabled = false;

  // ─── Getters ──────────────────────────────────────────
  String? get familyCode => _familyCode;
  bool get isSyncEnabled => _isSyncEnabled;

  List<ChildModel> get children =>
      _childrenBox.values.map((m) => ChildModel.fromMap(Map<String, dynamic>.from(m))).toList();

  List<HistoryEntry> get history =>
      _historyBox.values.map((m) => HistoryEntry.fromMap(Map<String, dynamic>.from(m))).toList();

  List<Map<String, dynamic>> get goals =>
      _goalsBox.values.map((m) => Map<String, dynamic>.from(m)).toList();

  List<Map<String, dynamic>> get notes =>
      _notesBox.values.map((m) => Map<String, dynamic>.from(m)).toList();

  List<Map<String, dynamic>> get punishments =>
      _punishmentsBox.values.map((m) => Map<String, dynamic>.from(m)).toList();

  List<ImmunityLines> get immunities =>
      _immunitiesBox.values.map((m) => ImmunityLines.fromMap(Map<String, dynamic>.from(m))).toList();

  List<Map<String, dynamic>> get tribunalCases =>
      _tribunalBox.values.map((m) => Map<String, dynamic>.from(m)).toList();

  List<BadgeModel> get customBadges =>
      _customBadgesBox.values.map((m) => BadgeModel.fromMap(Map<String, dynamic>.from(m))).toList();

  List<TradeModel> get trades =>
      _tradesBox.values.map((m) => TradeModel.fromMap(Map<String, dynamic>.from(m))).toList();

  List<Map<String, dynamic>> get schoolNotes =>
      _schoolNotesBox.values.map((m) => Map<String, dynamic>.from(m)).toList();

  // ─── Init ─────────────────────────────────────────────
  Future<void> init() async {
    _childrenBox = await Hive.openBox<Map>('children');
    _historyBox = await Hive.openBox<Map>('history');
    _goalsBox = await Hive.openBox<Map>('goals');
    _notesBox = await Hive.openBox<Map>('notes');
    _punishmentsBox = await Hive.openBox<Map>('punishments');
    _immunitiesBox = await Hive.openBox<Map>('immunities');
    _tribunalBox = await Hive.openBox<Map>('tribunal');
    _customBadgesBox = await Hive.openBox<Map>('customBadges');
    _metaBox = await Hive.openBox<Map>('meta');
    _screenTimeBox = await Hive.openBox<Map>('screenTime');
    _tradesBox = await Hive.openBox<Map>('trades');
    _schoolNotesBox = await Hive.openBox<Map>('schoolNotes');

    // Load family code
    final meta = _metaBox.get('family');
    if (meta != null) {
      final m = Map<String, dynamic>.from(meta);
      _familyCode = m['code'] as String?;
      _isSyncEnabled = m['syncEnabled'] == true;
    }

    notifyListeners();
  }

  // ─── Family Management ────────────────────────────────
  Future<void> createFamily(String code) async {
    _familyCode = code;
    _isSyncEnabled = false;
    await _metaBox.put('family', {'code': code, 'syncEnabled': false});
    notifyListeners();
    _syncToFirestore();
  }

  Future<void> joinFamily(String code) async {
    _familyCode = code;
    _isSyncEnabled = false;
    await _metaBox.put('family', {'code': code, 'syncEnabled': false});
    notifyListeners();
  }

  Future<void> enableSync() async {
    _isSyncEnabled = true;
    await _metaBox.put('family', {
      'code': _familyCode,
      'syncEnabled': true,
    });
    notifyListeners();
    _syncToFirestore();
  }

  Future<void> disableSync() async {
    _isSyncEnabled = false;
    await _metaBox.put('family', {
      'code': _familyCode,
      'syncEnabled': false,
    });
    notifyListeners();
  }

  Future<void> reconnectFirestore() async {
    if (_isSyncEnabled && _familyCode != null) {
      try {
        await _syncToFirestore();
      } catch (_) {}
    }
  }

  // ─── Child CRUD ───────────────────────────────────────
  ChildModel? getChild(String id) {
    final raw = _childrenBox.get(id);
    if (raw == null) return null;
    return ChildModel.fromMap(Map<String, dynamic>.from(raw));
  }

  Future<void> addChild(String name, String avatar, {String? photoBase64}) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final child = ChildModel(
      id: id,
      name: name,
      avatar: avatar,
      photoBase64: photoBase64,
      points: 0,
      level: 1,
      badgeIds: [],
      createdAt: DateTime.now(),
    );
    await _childrenBox.put(id, child.toMap());
    notifyListeners();
    _syncToFirestore();
  }

  Future<void> updateChild(ChildModel child) async {
    await _childrenBox.put(child.id, child.toMap());
    notifyListeners();
    _syncToFirestore();
  }

  Future<void> removeChild(String id) async {
    await _childrenBox.delete(id);
    // Clean related data
    final histKeys = <dynamic>[];
    for (final key in _historyBox.keys) {
      final m = Map<String, dynamic>.from(_historyBox.get(key)!);
      if (m['childId'] == id) histKeys.add(key);
    }
    for (final k in histKeys) {
      await _historyBox.delete(k);
    }
    notifyListeners();
    _syncToFirestore();
  }

  // ─── Points ───────────────────────────────────────────
  Future<void> addPoints(String childId, int points, String description,
      {String? category, String? proofPhotoBase64, String? actionBy}) async {
    final child = getChild(childId);
    if (child == null) return;

    final isBonus = points >= 0;
    final updated = child.copyWith(points: child.points + points);
    await _childrenBox.put(childId, updated.toMap());

    final entryId = DateTime.now().millisecondsSinceEpoch.toString();
    final entry = HistoryEntry(
      id: entryId,
      childId: childId,
      points: points,
      reason: description,
      category: category ?? (isBonus ? 'Bonus' : 'Malus'),
      date: DateTime.now(),
      isBonus: isBonus,
      proofPhotoBase64: proofPhotoBase64,
      actionBy: actionBy,
    );
    await _historyBox.put(entryId, entry.toMap());

    // Check badge unlock
    _checkBadgeUnlock(updated);

    notifyListeners();
    _syncToFirestore();
  }

  void _checkBadgeUnlock(ChildModel child) {
    final allBadges = [...BadgeModel.defaultBadges, ...customBadges];
    for (final badge in allBadges) {
      if (!child.badgeIds.contains(badge.id) && child.points >= badge.requiredPoints) {
        final updated = child.copyWith(badgeIds: [...child.badgeIds, badge.id]);
        _childrenBox.put(child.id, updated.toMap());
      }
    }
  }

  Future<void> unlockBadge(String childId, String badgeId) async {
    final child = getChild(childId);
    if (child == null) return;
    if (child.badgeIds.contains(badgeId)) return;
    final updated = child.copyWith(badgeIds: [...child.badgeIds, badgeId]);
    await _childrenBox.put(childId, updated.toMap());
    notifyListeners();
    _syncToFirestore();
  }

  // ─── Goals ────────────────────────────────────────────
  Future<void> addGoal(String childId, String title, int targetPoints) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final goal = {
      'id': id,
      'childId': childId,
      'title': title,
      'targetPoints': targetPoints,
      'isCompleted': false,
      'createdAt': DateTime.now().toIso8601String(),
    };
    await _goalsBox.put(id, goal);
    notifyListeners();
    _syncToFirestore();
  }

  Future<void> completeGoal(String goalId) async {
    final raw = _goalsBox.get(goalId);
    if (raw == null) return;
    final goal = Map<String, dynamic>.from(raw);
    goal['isCompleted'] = true;
    await _goalsBox.put(goalId, goal);
    notifyListeners();
    _syncToFirestore();
  }

  Future<void> deleteGoal(String goalId) async {
    await _goalsBox.delete(goalId);
    notifyListeners();
    _syncToFirestore();
  }

  // ─── Notes ────────────────────────────────────────────
  Future<void> addNote(String childId, String content, {String? category}) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final note = {
      'id': id,
      'childId': childId,
      'content': content,
      'category': category ?? 'Général',
      'createdAt': DateTime.now().toIso8601String(),
    };
    await _notesBox.put(id, note);
    notifyListeners();
    _syncToFirestore();
  }

  Future<void> deleteNote(String noteId) async {
    await _notesBox.delete(noteId);
    notifyListeners();
    _syncToFirestore();
  }

  // ─── Punishments ──────────────────────────────────────
  List<Map<String, dynamic>> getPunishments([String? childId]) {
    final all = punishments;
    if (childId == null) return all;
    return all.where((p) => p['childId'] == childId).toList();
  }

  Future<void> addPunishment(String childId, String reason, int totalLines, {String? phrase}) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final punishment = {
      'id': id,
      'childId': childId,
      'reason': reason,
      'totalLines': totalLines,
      'completedLines': 0,
      'phrase': phrase ?? reason,
      'status': 'active',
      'submissions': <Map<String, dynamic>>[],
      'createdAt': DateTime.now().toIso8601String(),
    };
    await _punishmentsBox.put(id, punishment);
    notifyListeners();
    _syncToFirestore();
  }

  Future<void> updatePunishment(String id, Map<String, dynamic> data) async {
    final raw = _punishmentsBox.get(id);
    if (raw == null) return;
    final punishment = Map<String, dynamic>.from(raw);
    punishment.addAll(data);
    await _punishmentsBox.put(id, punishment);
    notifyListeners();
    _syncToFirestore();
  }

  Future<void> submitPunishmentLines(String punishmentId, int lines, {String? photoBase64}) async {
    final raw = _punishmentsBox.get(punishmentId);
    if (raw == null) return;
    final punishment = Map<String, dynamic>.from(raw);
    final submissions = List<Map<String, dynamic>>.from(punishment['submissions'] ?? []);
    submissions.add({
      'lines': lines,
      'photoBase64': photoBase64,
      'submittedAt': DateTime.now().toIso8601String(),
      'status': 'pending',
    });
    punishment['submissions'] = submissions;
    await _punishmentsBox.put(punishmentId, punishment);
    notifyListeners();
    _syncToFirestore();
  }

  Future<void> validatePunishmentSubmission(String punishmentId, int submissionIndex,
      {required bool accepted, int? validatedLines, String? note}) async {
    final raw = _punishmentsBox.get(punishmentId);
    if (raw == null) return;
    final punishment = Map<String, dynamic>.from(raw);
    final submissions = List<Map<String, dynamic>>.from(punishment['submissions'] ?? []);

    if (submissionIndex >= submissions.length) return;

    final sub = Map<String, dynamic>.from(submissions[submissionIndex]);
    if (accepted) {
      final lines = validatedLines ?? (sub['lines'] as int? ?? 0);
      sub['status'] = 'validated';
      sub['validatedLines'] = lines;
      sub['note'] = note;
      punishment['completedLines'] = (punishment['completedLines'] as int? ?? 0) + lines;
      if ((punishment['completedLines'] as int) >= (punishment['totalLines'] as int)) {
        punishment['status'] = 'completed';
        punishment['completedAt'] = DateTime.now().toIso8601String();
      }
    } else {
      sub['status'] = 'rejected';
      sub['note'] = note;
    }
    submissions[submissionIndex] = sub;
    punishment['submissions'] = submissions;
    await _punishmentsBox.put(punishmentId, punishment);
    notifyListeners();
    _syncToFirestore();
  }

  Future<void> deletePunishment(String id) async {
    await _punishmentsBox.delete(id);
    notifyListeners();
    _syncToFirestore();
  }

  Future<void> resetPunishmentProgress(String id) async {
    final raw = _punishmentsBox.get(id);
    if (raw == null) return;
    final punishment = Map<String, dynamic>.from(raw);
    punishment['completedLines'] = 0;
    punishment['status'] = 'active';
    punishment['submissions'] = <Map<String, dynamic>>[];
    await _punishmentsBox.put(id, punishment);
    notifyListeners();
    _syncToFirestore();
  }

  Future<void> completePunishment(String id) async {
    final raw = _punishmentsBox.get(id);
    if (raw == null) return;
    final punishment = Map<String, dynamic>.from(raw);
    punishment['status'] = 'completed';
    punishment['completedLines'] = punishment['totalLines'];
    punishment['completedAt'] = DateTime.now().toIso8601String();
    await _punishmentsBox.put(id, punishment);
    notifyListeners();
    _syncToFirestore();
  }

  // ─── Immunities ───────────────────────────────────────
  List<ImmunityLines> getImmunities([String? childId]) {
    final all = immunities;
    if (childId == null) return all;
    return all.where((i) => i.childId == childId).toList();
  }

  Future<void> addImmunity(String childId, String reason, int lines, {DateTime? expiresAt}) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final immunity = ImmunityLines(
      id: id,
      childId: childId,
      reason: reason,
      lines: lines,
      usedLines: 0,
      createdAt: DateTime.now(),
      expiresAt: expiresAt,
    );
    await _immunitiesBox.put(id, immunity.toMap());
    notifyListeners();
    _syncToFirestore();
  }

  Future<void> useImmunity(String immunityId, int lines) async {
    final raw = _immunitiesBox.get(immunityId);
    if (raw == null) return;
    final m = Map<String, dynamic>.from(raw);
    m['usedLines'] = (m['usedLines'] as int? ?? 0) + lines;
    await _immunitiesBox.put(immunityId, m);
    notifyListeners();
    _syncToFirestore();
  }

  Future<void> useImmunityOnPunishment(String immunityId, String punishmentId) async {
    final immRaw = _immunitiesBox.get(immunityId);
    final punRaw = _punishmentsBox.get(punishmentId);
    if (immRaw == null || punRaw == null) return;

    final imm = ImmunityLines.fromMap(Map<String, dynamic>.from(immRaw));
    final pun = Map<String, dynamic>.from(punRaw);

    if (!imm.isUsable) return;

    final remaining = (pun['totalLines'] as int) - (pun['completedLines'] as int? ?? 0);
    final available = imm.availableLines;
    final toUse = remaining < available ? remaining : available;

    // Update immunity
    final immMap = imm.toMap();
    immMap['usedLines'] = imm.usedLines + toUse;
    await _immunitiesBox.put(immunityId, immMap);

    // Update punishment
    pun['completedLines'] = (pun['completedLines'] as int? ?? 0) + toUse;
    if ((pun['completedLines'] as int) >= (pun['totalLines'] as int)) {
      pun['status'] = 'completed';
      pun['completedAt'] = DateTime.now().toIso8601String();
    }
    await _punishmentsBox.put(punishmentId, pun);

    notifyListeners();
    _syncToFirestore();
  }

  Future<void> useImmunityOnPunishmentNamed(String immunityId, String punishmentId) async {
    await useImmunityOnPunishment(immunityId, punishmentId);
  }

  Future<void> deleteImmunity(String id) async {
    await _immunitiesBox.delete(id);
    notifyListeners();
    _syncToFirestore();
  }

  Future<void> reactivateImmunity(String id) async {
    final raw = _immunitiesBox.get(id);
    if (raw == null) return;
    final m = Map<String, dynamic>.from(raw);
    m['usedLines'] = 0;
    if (m['expiresAt'] != null) {
      m['expiresAt'] = DateTime.now().add(const Duration(days: 7)).toIso8601String();
    }
    await _immunitiesBox.put(id, m);
    notifyListeners();
    _syncToFirestore();
  }

  // ─── Custom Badges ────────────────────────────────────
  Future<void> addCustomBadge(String name, String icon, String description,
      int requiredPoints, String powerType) async {
    final id = 'custom_${DateTime.now().millisecondsSinceEpoch}';
    final badge = BadgeModel(
      id: id,
      name: name,
      icon: icon,
      description: description,
      requiredPoints: requiredPoints,
      powerType: powerType,
      isCustom: true,
    );
    await _customBadgesBox.put(id, badge.toMap());
    notifyListeners();
    _syncToFirestore();
  }

  Future<void> deleteCustomBadge(String id) async {
    await _customBadgesBox.delete(id);
    notifyListeners();
    _syncToFirestore();
  }

  List<BadgeModel> getAllBadges() {
    return [...BadgeModel.defaultBadges, ...customBadges];
  }

  List<BadgeModel> getChildBadges(String childId) {
    final child = getChild(childId);
    if (child == null) return [];
    final allBadges = getAllBadges();
    return allBadges.where((b) => child.badgeIds.contains(b.id)).toList();
  }

  // ─── Screen Time ──────────────────────────────────────
  Map<String, dynamic>? getScreenTime(String childId) {
    final raw = _screenTimeBox.get(childId);
    if (raw == null) return null;
    return Map<String, dynamic>.from(raw);
  }

  Future<void> setScreenTime(String childId, Map<String, dynamic> data) async {
    await _screenTimeBox.put(childId, data);
    notifyListeners();
    _syncToFirestore();
  }

  // ─── Weekly Score ─────────────────────────────────────
  int getWeeklyScore(String childId) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final start = DateTime(weekStart.year, weekStart.month, weekStart.day);

    return history
        .where((e) => e.childId == childId && e.date.isAfter(start))
        .fold<int>(0, (sum, e) => sum + e.points);
  }

  // ─── Tribunal ─────────────────────────────────────────
  Future<void> startTribunalHearing(Map<String, dynamic> tribunalCase) async {
    final id = tribunalCase['id'] ?? DateTime.now().millisecondsSinceEpoch.toString();
    tribunalCase['id'] = id;
    tribunalCase['status'] = tribunalCase['status'] ?? 'open';
    tribunalCase['createdAt'] = tribunalCase['createdAt'] ?? DateTime.now().toIso8601String();
    tribunalCase['votes'] = tribunalCase['votes'] ?? <Map<String, dynamic>>[];
    await _tribunalBox.put(id, tribunalCase);
    notifyListeners();
    _syncToFirestore();
  }

  Future<void> updateTribunalCase(String id, Map<String, dynamic> data) async {
    final raw = _tribunalBox.get(id);
    if (raw == null) return;
    final tc = Map<String, dynamic>.from(raw);
    tc.addAll(data);
    await _tribunalBox.put(id, tc);
    notifyListeners();
    _syncToFirestore();
  }

  Future<void> voteTribunal(String caseId, String voterId, String vote) async {
    final raw = _tribunalBox.get(caseId);
    if (raw == null) return;
    final tc = Map<String, dynamic>.from(raw);
    final votes = List<Map<String, dynamic>>.from(tc['votes'] ?? []);
    // Remove previous vote by same voter
    votes.removeWhere((v) => v['voterId'] == voterId);
    votes.add({
      'voterId': voterId,
      'vote': vote,
      'votedAt': DateTime.now().toIso8601String(),
    });
    tc['votes'] = votes;
    await _tribunalBox.put(caseId, tc);
    notifyListeners();
    _syncToFirestore();
  }

  Future<void> renderVerdict(String caseId, String verdict, {int? pointsAdjust}) async {
    final raw = _tribunalBox.get(caseId);
    if (raw == null) return;
    final tc = Map<String, dynamic>.from(raw);
    tc['status'] = 'closed';
    tc['verdict'] = verdict;
    tc['closedAt'] = DateTime.now().toIso8601String();
    await _tribunalBox.put(caseId, tc);

    // Apply points adjustment if any
    if (pointsAdjust != null && tc['accusedId'] != null) {
      await addPoints(tc['accusedId'], pointsAdjust, 'Verdict tribunal: $verdict',
          category: 'Tribunal');
    }

    notifyListeners();
    _syncToFirestore();
  }

  Future<void> distributeVotePoints(String caseId) async {
    final raw = _tribunalBox.get(caseId);
    if (raw == null) return;
    final tc = Map<String, dynamic>.from(raw);
    final votes = List<Map<String, dynamic>>.from(tc['votes'] ?? []);
    for (final vote in votes) {
      final voterId = vote['voterId'] as String;
      await addPoints(voterId, 1, 'Participation au tribunal', category: 'Tribunal');
    }
  }

  Future<void> deleteTribunalCase(String id) async {
    await _tribunalBox.delete(id);
    notifyListeners();
    _syncToFirestore();
  }

  // ─── Trades ───────────────────────────────────────────
  Future<void> addTrade(TradeModel trade) async {
    await _tradesBox.put(trade.id, trade.toMap());
    notifyListeners();
    _syncToFirestore();
  }

  Future<void> updateTrade(String id, Map<String, dynamic> data) async {
    final raw = _tradesBox.get(id);
    if (raw == null) return;
    final tradeMap = Map<String, dynamic>.from(raw);
    tradeMap.addAll(data);
    await _tradesBox.put(id, tradeMap);
    notifyListeners();
    _syncToFirestore();
  }

  Future<void> deleteTrade(String id) async {
    await _tradesBox.delete(id);
    notifyListeners();
    _syncToFirestore();
  }

  TradeModel? getTrade(String id) {
    final raw = _tradesBox.get(id);
    if (raw == null) return null;
    return TradeModel.fromMap(Map<String, dynamic>.from(raw));
  }

  List<TradeModel> getChildTrades(String childId) {
    return trades
        .where((t) => t.fromChildId == childId || t.toChildId == childId)
        .toList();
  }

  List<TradeModel> getActiveTrades() {
    return trades.where((t) => t.isActive).toList();
  }

  // ─── History Helpers ──────────────────────────────────
  List<HistoryEntry> getHistory([String? childId]) {
    if (childId == null) return history;
    return history.where((e) => e.childId == childId).toList();
  }

  List<HistoryEntry> getChildHistory(String childId) {
    return history.where((e) => e.childId == childId).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  List<HistoryEntry> getChildBonuses(String childId) {
    return getChildHistory(childId).where((e) => e.isBonus).toList();
  }

  List<HistoryEntry> getChildPenalties(String childId) {
    return getChildHistory(childId).where((e) => !e.isBonus).toList();
  }

  int getChildTotalBonuses(String childId) {
    return getChildBonuses(childId).fold<int>(0, (sum, e) => sum + e.points);
  }

  int getChildTotalPenalties(String childId) {
    return getChildPenalties(childId).fold<int>(0, (sum, e) => sum + e.points.abs());
  }

  // ─── Delete / Edit Helpers ────────────────────────────
  Future<void> deleteHistoryEntry(String id) async {
    final raw = _historyBox.get(id);
    if (raw != null) {
      final entry = HistoryEntry.fromMap(Map<String, dynamic>.from(raw));
      // Reverse the points
      final child = getChild(entry.childId);
      if (child != null) {
        final updated = child.copyWith(points: child.points - entry.points);
        await _childrenBox.put(child.id, updated.toMap());
      }
    }
    await _historyBox.delete(id);
    notifyListeners();
    _syncToFirestore();
  }

  Future<void> editHistoryEntry(String id, {int? points, String? reason}) async {
    final raw = _historyBox.get(id);
    if (raw == null) return;
    final m = Map<String, dynamic>.from(raw);
    final oldPoints = m['points'] as int;

    if (points != null) {
      m['points'] = points;
      // Adjust child points
      final childId = m['childId'] as String;
      final child = getChild(childId);
      if (child != null) {
        final diff = points - oldPoints;
        final updated = child.copyWith(points: child.points + diff);
        await _childrenBox.put(child.id, updated.toMap());
      }
    }
    if (reason != null) m['reason'] = reason;

    await _historyBox.put(id, m);
    notifyListeners();
    _syncToFirestore();
  }

  // ─── Admin Helpers ────────────────────────────────────
  Future<void> resetChildPoints(String childId) async {
    final child = getChild(childId);
    if (child == null) return;
    final updated = child.copyWith(points: 0, level: 1, badgeIds: []);
    await _childrenBox.put(childId, updated.toMap());
    notifyListeners();
    _syncToFirestore();
  }

  Future<void> resetAllScores() async {
    for (final child in children) {
      final updated = child.copyWith(points: 0, level: 1, badgeIds: []);
      await _childrenBox.put(child.id, updated.toMap());
    }
    notifyListeners();
    _syncToFirestore();
  }

  Future<void> clearHistory([String? childId]) async {
    if (childId == null) {
      await _historyBox.clear();
    } else {
      final keysToDelete = <dynamic>[];
      for (final key in _historyBox.keys) {
        final m = Map<String, dynamic>.from(_historyBox.get(key)!);
        if (m['childId'] == childId) keysToDelete.add(key);
      }
      for (final k in keysToDelete) {
        await _historyBox.delete(k);
      }
    }
    notifyListeners();
    _syncToFirestore();
  }

  Future<void> clearAllPunishments([String? childId]) async {
    if (childId == null) {
      await _punishmentsBox.clear();
    } else {
      final keysToDelete = <dynamic>[];
      for (final key in _punishmentsBox.keys) {
        final m = Map<String, dynamic>.from(_punishmentsBox.get(key)!);
        if (m['childId'] == childId) keysToDelete.add(key);
      }
      for (final k in keysToDelete) {
        await _punishmentsBox.delete(k);
      }
    }
    notifyListeners();
    _syncToFirestore();
  }

  Future<void> clearAllImmunities([String? childId]) async {
    if (childId == null) {
      await _immunitiesBox.clear();
    } else {
      final keysToDelete = <dynamic>[];
      for (final key in _immunitiesBox.keys) {
        final m = Map<String, dynamic>.from(_immunitiesBox.get(key)!);
        if (m['childId'] == childId) keysToDelete.add(key);
      }
      for (final k in keysToDelete) {
        await _immunitiesBox.delete(k);
      }
    }
    notifyListeners();
    _syncToFirestore();
  }

  Future<void> resetEverything() async {
    await _childrenBox.clear();
    await _historyBox.clear();
    await _goalsBox.clear();
    await _notesBox.clear();
    await _punishmentsBox.clear();
    await _immunitiesBox.clear();
    await _tribunalBox.clear();
    await _customBadgesBox.clear();
    await _screenTimeBox.clear();
    await _tradesBox.clear();
    await _schoolNotesBox.clear();
    _familyCode = null;
    _isSyncEnabled = false;
    await _metaBox.clear();
    notifyListeners();
  }

  // ─── School Notes ─────────────────────────────────────
  Future<void> addSchoolNote(String childId, String subject, double grade,
      double maxGrade, {String? comment, String? photoBase64}) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final note = {
      'id': id,
      'childId': childId,
      'subject': subject,
      'grade': grade,
      'maxGrade': maxGrade,
      'comment': comment,
      'photoBase64': photoBase64,
      'isValidated': false,
      'createdAt': DateTime.now().toIso8601String(),
    };
    await _schoolNotesBox.put(id, note);
    notifyListeners();
    _syncToFirestore();
  }

  Future<void> validateSchoolNote(String noteId, {int bonusPoints = 0, String? childId}) async {
    final raw = _schoolNotesBox.get(noteId);
    if (raw == null) return;
    final note = Map<String, dynamic>.from(raw);
    note['isValidated'] = true;
    note['validatedAt'] = DateTime.now().toIso8601String();
    await _schoolNotesBox.put(noteId, note);

    if (bonusPoints > 0 && childId != null) {
      await addPoints(childId, bonusPoints, 'Bonus note scolaire: ${note['subject']}',
          category: 'École');
    }

    notifyListeners();
    _syncToFirestore();
  }

  Future<void> deleteSchoolNote(String id) async {
    await _schoolNotesBox.delete(id);
    notifyListeners();
    _syncToFirestore();
  }

  List<Map<String, dynamic>> getChildSchoolNotes(String childId) {
    return schoolNotes.where((n) => n['childId'] == childId).toList();
  }

  // ─── Firestore Sync (placeholder) ────────────────────
  Future<void> _syncToFirestore() async {
    if (!_isSyncEnabled || _familyCode == null) return;
    try {
      final db = FirebaseFirestore.instance;
      final ref = db.collection('families').doc(_familyCode);
      await ref.set({
        'children': children.map((c) => c.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firestore sync error: $e');
    }
  }
}
