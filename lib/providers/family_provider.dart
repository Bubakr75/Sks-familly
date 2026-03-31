// lib/providers/family_provider.dart
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/child_model.dart';
import '../models/badge_model.dart';
import '../models/history_entry.dart';
import '../models/immunity_lines.dart';
import '../models/punishment_lines.dart';
import '../models/trade_model.dart';
import '../models/tribunal_model.dart';
import '../models/note_model.dart';

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
      _childrenBox.values
          .map((m) => ChildModel.fromMap(Map<String, dynamic>.from(m)))
          .toList();

  List<ChildModel> get sortedChildren {
    final list = [...children];
    list.sort((a, b) => b.points.compareTo(a.points));
    return list;
  }

  List<HistoryEntry> get history =>
      _historyBox.values
          .map((m) => HistoryEntry.fromMap(Map<String, dynamic>.from(m)))
          .toList();

  List<Map<String, dynamic>> get goals =>
      _goalsBox.values.map((m) => Map<String, dynamic>.from(m)).toList();

  List<NoteModel> get notes =>
      _notesBox.values
          .map((m) => NoteModel.fromMap(Map<String, dynamic>.from(m)))
          .toList();

  List<Map<String, dynamic>> get punishments =>
      _punishmentsBox.values
          .map((m) => Map<String, dynamic>.from(m))
          .toList();

  List<ImmunityLines> get immunities =>
      _immunitiesBox.values
          .map((m) => ImmunityLines.fromMap(Map<String, dynamic>.from(m)))
          .toList();

  List<TribunalCase> get tribunalCases =>
      _tribunalBox.values
          .map((m) => TribunalCase.fromMap(Map<String, dynamic>.from(m)))
          .toList();

  List<TribunalCase> get activeTribunalCases =>
      tribunalCases.where((tc) => !tc.isClosed).toList();

  List<TribunalCase> get closedTribunalCases =>
      tribunalCases.where((tc) => tc.isClosed).toList();

  List<BadgeModel> get customBadges =>
      _customBadgesBox.values
          .map((m) => BadgeModel.fromMap(Map<String, dynamic>.from(m)))
          .toList();

  List<TradeModel> get trades =>
      _tradesBox.values
          .map((m) => TradeModel.fromMap(Map<String, dynamic>.from(m)))
          .toList();

  List<Map<String, dynamic>> get schoolNotes =>
      _schoolNotesBox.values
          .map((m) => Map<String, dynamic>.from(m))
          .toList();

  Box<Map> get schoolNotesBox => _schoolNotesBox;

  // ─── Init ─────────────────────────────────────────────
  Future<void> init() async {
    _childrenBox      = await Hive.openBox<Map>('children');
    _historyBox       = await Hive.openBox<Map>('history');
    _goalsBox         = await Hive.openBox<Map>('goals');
    _notesBox         = await Hive.openBox<Map>('notes');
    _punishmentsBox   = await Hive.openBox<Map>('punishments');
    _immunitiesBox    = await Hive.openBox<Map>('immunities');
    _tribunalBox      = await Hive.openBox<Map>('tribunal');
    _customBadgesBox  = await Hive.openBox<Map>('customBadges');
    _metaBox          = await Hive.openBox<Map>('meta');
    _screenTimeBox    = await Hive.openBox<Map>('screenTime');
    _tradesBox        = await Hive.openBox<Map>('trades');
    _schoolNotesBox   = await Hive.openBox<Map>('schoolNotes');

    final meta = _metaBox.get('family');
    if (meta != null) {
      final m = Map<String, dynamic>.from(meta);
      _familyCode    = m['code'] as String?;
      _isSyncEnabled = m['syncEnabled'] == true;
    }
    notifyListeners();
  }

  // ─── Family Management ────────────────────────────────
  String getFamilyCode() => _familyCode ?? '';

  Future<String> createFamily({String? customCode}) async {
    final code = customCode ?? _generateCode();
    _familyCode    = code;
    _isSyncEnabled = true;
    await _metaBox.put('family', {'code': code, 'syncEnabled': true});
    notifyListeners();
    _syncToFirestore();
    return code;
  }

  String _generateCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng = Random();
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  Future<bool> joinFamily(String code) async {
    try {
      final db  = FirebaseFirestore.instance;
      final doc = await db.collection('families').doc(code).get();
      if (!doc.exists) return false;
      _familyCode    = code;
      _isSyncEnabled = true;
      await _metaBox.put('family', {'code': code, 'syncEnabled': true});
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> disconnectFamily() async {
    _isSyncEnabled = false;
    await _metaBox.put('family', {'code': _familyCode, 'syncEnabled': false});
    notifyListeners();
  }

  Future<void> changeFamilyCode(String newCode) async {
    _familyCode = newCode;
    await _metaBox.put('family', {'code': newCode, 'syncEnabled': _isSyncEnabled});
    notifyListeners();
    _syncToFirestore();
  }

  Future<void> enableSync() async {
    _isSyncEnabled = true;
    await _metaBox.put('family', {'code': _familyCode, 'syncEnabled': true});
    notifyListeners();
    _syncToFirestore();
  }

  Future<void> disableSync() async {
    _isSyncEnabled = false;
    await _metaBox.put('family', {'code': _familyCode, 'syncEnabled': false});
    notifyListeners();
  }

  Future<void> reconnectFirestore() async {
    if (_isSyncEnabled && _familyCode != null) {
      try { await _syncToFirestore(); } catch (_) {}
    }
  }

  // ─── Child CRUD ───────────────────────────────────────
  ChildModel? getChild(String id) {
    final raw = _childrenBox.get(id);
    if (raw == null) return null;
    return ChildModel.fromMap(Map<String, dynamic>.from(raw));
  }

  // ✅ CORRIGÉ : photoBase64 ?? '' pour éviter null vers String
  Future<void> addChild(String name, String avatar, {String? photoBase64}) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final child = ChildModel(
      id: id, name: name, avatar: avatar,
      photoBase64: photoBase64 ?? '',
      points: 0, level: 1, badgeIds: [], createdAt: DateTime.now(),
    );
    await _childrenBox.put(id, child.toMap());
    notifyListeners();
    _syncToFirestore();
  }

  Future<void> updateChild(String childId, String name, String avatar) async {
    final child = getChild(childId);
    if (child == null) return;
    final updated = child.copyWith(name: name, avatar: avatar);
    await _childrenBox.put(childId, updated.toMap());
    notifyListeners();
    _syncToFirestore();
  }

  Future<void> updateChildPhoto(String childId, String? photoBase64) async {
    final child = getChild(childId);
    if (child == null) return;
    final updated = child.copyWith(
      photoBase64: (photoBase64 == null || photoBase64.isEmpty) ? null : photoBase64,
    );
    await _childrenBox.put(childId, updated.toMap());
    notifyListeners();
    _syncToFirestore();
  }

  Future<void> removeChild(String id) async {
    await _childrenBox.delete(id);
    final histKeys = <dynamic>[];
    for (final key in _historyBox.keys) {
      final m = Map<String, dynamic>.from(_historyBox.get(key)!);
      if (m['childId'] == id) histKeys.add(key);
    }
    for (final k in histKeys) { await _historyBox.delete(k); }
    notifyListeners();
    _syncToFirestore();
  }

  // ─── Points ───────────────────────────────────────────
  Future<void> addPoints(
    String childId,
    int points,
    String description, {
    String? category,
    String? emoji,
    String? proofPhotoBase64,
    String? actionBy,
  }) async {
    final child = getChild(childId);
    if (child == null) return;
    final isBonus  = points >= 0;
    final newPts   = child.points + points;
    final newLevel = _computeLevel(newPts);
    final updated  = child.copyWith(points: newPts, level: newLevel);
    await _childrenBox.put(childId, updated.toMap());

    final entryId = DateTime.now().millisecondsSinceEpoch.toString();
    final entry = HistoryEntry(
      id: entryId,
      childId: childId,
      points: points,
      description: description,
      emoji: emoji ?? (isBonus ? '⭐' : '⚠️'),
      category: category ?? (isBonus ? 'Bonus' : 'Malus'),
      date: DateTime.now(),
      proofPhotoBase64: proofPhotoBase64,
      actionBy: actionBy,
    );
    await _historyBox.put(entryId, entry.toMap());
    _checkBadgeUnlock(updated);
    notifyListeners();
    _syncToFirestore();
  }

  int _computeLevel(int points) {
    if (points <= 0) return 1;
    return (points ~/ 100) + 1;
  }

  void _checkBadgeUnlock(ChildModel child) {
    final allBadges = [...BadgeModel.defaultBadges, ...customBadges];
    for (final badge in allBadges) {
      if (!child.badgeIds.contains(badge.id) &&
          child.points >= badge.requiredPoints) {
        final updated = child.copyWith(badgeIds: [...child.badgeIds, badge.id]);
        _childrenBox.put(child.id, updated.toMap());
      }
    }
  }

  Future<void> unlockBadge(String childId, String badgeId) async {
    final child = getChild(childId);
    if (child == null || child.badgeIds.contains(badgeId)) return;
    final updated = child.copyWith(badgeIds: [...child.badgeIds, badgeId]);
    await _childrenBox.put(childId, updated.toMap());
    notifyListeners();
    _syncToFirestore();
  }

  // ─── Badges helpers ───────────────────────────────────
  List<BadgeModel> getAllBadges() => [...BadgeModel.defaultBadges, ...customBadges];
  List<BadgeModel> getDefaultBadges() => BadgeModel.defaultBadges;
  List<BadgeModel> getCustomBadgesForChild(String childId) => customBadges;

  List<BadgeModel> getChildBadges(String childId) {
    final child = getChild(childId);
    if (child == null) return [];
    return getAllBadges().where((b) => child.badgeIds.contains(b.id)).toList();
  }

  // ─── History ──────────────────────────────────────────
  List<HistoryEntry> getHistory([String? childId]) {
    if (childId == null) return history;
    return history.where((e) => e.childId == childId).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  List<HistoryEntry> getHistoryForChild(String childId) {
    return history.where((e) => e.childId == childId).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  List<HistoryEntry> getChildBonuses(String childId) =>
      getHistoryForChild(childId).where((e) => e.points > 0).toList();

  List<HistoryEntry> getChildPenalties(String childId) =>
      getHistoryForChild(childId).where((e) => e.points < 0).toList();

  Future<void> deleteHistoryEntry(String id) async {
    await _historyBox.delete(id);
    notifyListeners();
    _syncToFirestore();
  }

  Future<void> editHistoryEntry(String id, {int? points, String? reason}) async {
    final raw = _historyBox.get(id);
    if (raw == null) return;
    final m = Map<String, dynamic>.from(raw);
    if (points != null) m['points'] = points;
    if (reason != null) m['description'] = reason;
    await _historyBox.put(id, m);
    notifyListeners();
    _syncToFirestore();
  }

  // ─── Goals ────────────────────────────────────────────
  Future<void> addGoal(String childId, String title, int targetPoints) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    await _goalsBox.put(id, {
      'id': id, 'childId': childId, 'title': title,
      'targetPoints': targetPoints, 'isCompleted': false,
      'createdAt': DateTime.now().toIso8601String(),
    });
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
  List<NoteModel> getNotesForChild(String childId) {
    return notes.where((n) => n.childId == childId).toList()
      ..sort((a, b) {
        if (a.isPinned && !b.isPinned) return -1;
        if (!a.isPinned && b.isPinned) return 1;
        return b.createdAt.compareTo(a.createdAt);
      });
  }

  Future<void> addNote(String childId, String content, {String? category}) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final note = NoteModel(id: id, childId: childId, text: content);
    await _notesBox.put(id, note.toMap());
    notifyListeners();
    _syncToFirestore();
  }

  Future<void> removeNote(String noteId) async {
    await _notesBox.delete(noteId);
    notifyListeners();
    _syncToFirestore();
  }

  Future<void> toggleNotePin(String noteId) async {
    final raw = _notesBox.get(noteId);
    if (raw == null) return;
    final m = Map<String, dynamic>.from(raw);
    m['isPinned'] = !(m['isPinned'] == true);
    await _notesBox.put(noteId, m);
    notifyListeners();
    _syncToFirestore();
  }

  Future<void> updateNote(String noteId, String text) async {
    final raw = _notesBox.get(noteId);
    if (raw == null) return;
    final m = Map<String, dynamic>.from(raw);
    m['text'] = text;
    await _notesBox.put(noteId, m);
    notifyListeners();
    _syncToFirestore();
  }

  // ─── Punishments ──────────────────────────────────────
  List<PunishmentLines> getPunishmentsForChild(String childId) {
    return _punishmentsBox.values
        .map((m) => Map<String, dynamic>.from(m))
        .where((m) => m['childId'] == childId)
        .map((m) => PunishmentLines.fromMap(m))
        .toList();
  }

  List<Map<String, dynamic>> getPunishments([String? childId]) {
    final all = punishments;
    if (childId == null) return all;
    return all.where((p) => p['childId'] == childId).toList();
  }

  Future<void> addPunishment({
    required String childId,
    required String text,
    required int totalLines,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final punishment = PunishmentLines(
      id: id, childId: childId, text: text,
      totalLines: totalLines, completedLines: 0,
      createdAt: DateTime.now(),
    );
    await _punishmentsBox.put(id, punishment.toMap());
    notifyListeners();
    _syncToFirestore();
  }

  Future<void> updatePunishmentProgress(String id, int additionalLines) async {
    final raw = _punishmentsBox.get(id);
    if (raw == null) return;
    final m = Map<String, dynamic>.from(raw);
    final current      = (m['completedLines'] as int? ?? 0);
    final total        = (m['totalLines']     as int? ?? 1);
    final newCompleted = (current + additionalLines).clamp(0, total);
    m['completedLines'] = newCompleted;
    if (newCompleted >= total) {
      m['isCompleted'] = true;
      m['completedAt'] = DateTime.now().toIso8601String();
    }
    await _punishmentsBox.put(id, m);
    notifyListeners();
    _syncToFirestore();
  }

  Future<void> completePunishment(String id) async {
    final raw = _punishmentsBox.get(id);
    if (raw == null) return;
    final m = Map<String, dynamic>.from(raw);
    m['completedLines'] = m['totalLines'];
    m['isCompleted']    = true;
    m['completedAt']    = DateTime.now().toIso8601String();
    await _punishmentsBox.put(id, m);
    notifyListeners();
    _syncToFirestore();
  }

  Future<void> removePunishment(String id) async {
    await _punishmentsBox.delete(id);
    notifyListeners();
    _syncToFirestore();
  }

  Future<void> deletePunishment(String id) async => removePunishment(id);

  Future<void> resetPunishmentProgress(String id) async {
    final raw = _punishmentsBox.get(id);
    if (raw == null) return;
    final m = Map<String, dynamic>.from(raw);
    m['completedLines'] = 0;
    m['isCompleted']    = false;
    m.remove('completedAt');
    await _punishmentsBox.put(id, m);
    notifyListeners();
    _syncToFirestore();
  }

  Future<void> updatePunishment(String id, Map<String, dynamic> data) async {
    final raw = _punishmentsBox.get(id);
    if (raw == null) return;
    final m = Map<String, dynamic>.from(raw);
    m.addAll(data);
    await _punishmentsBox.put(id, m);
    notifyListeners();
    _syncToFirestore();
  }

  Future<void> submitPunishmentLines(String punishmentId, int lines,
      {String? photoBase64}) async {
    await updatePunishmentProgress(punishmentId, lines);
  }

  // ─── Immunities ───────────────────────────────────────
  List<ImmunityLines> getImmunities([String? childId]) {
    if (childId == null) return immunities;
    return immunities.where((i) => i.childId == childId).toList();
  }

  List<ImmunityLines> getImmunitiesForChild(String childId) =>
      getImmunities(childId);

  List<ImmunityLines> getUsableImmunitiesForChild(String childId) =>
      getImmunities(childId).where((i) => i.isUsable).toList();

  Future<void> addImmunity({
    required String childId,
    required String reason,
    required int lines,
    DateTime? expiresAt,
  }) async {
    final id  = DateTime.now().millisecondsSinceEpoch.toString();
    final imm = ImmunityLines(
      id: id, childId: childId, reason: reason,
      lines: lines, usedLines: 0,
      createdAt: DateTime.now(), expiresAt: expiresAt,
    );
    await _immunitiesBox.put(id, imm.toMap());
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

  Future<void> useImmunityOnPunishment({
    required String immunityId,
    required String punishmentId,
    required int linesToUse,
  }) async {
    final immRaw = _immunitiesBox.get(immunityId);
    final punRaw = _punishmentsBox.get(punishmentId);
    if (immRaw == null || punRaw == null) return;

    final imm = ImmunityLines.fromMap(Map<String, dynamic>.from(immRaw));
    if (!imm.isUsable) return;

    final safeLines = linesToUse.clamp(1, imm.availableLines);

    final immMap = imm.toMap();
    immMap['usedLines'] = imm.usedLines + safeLines;
    await _immunitiesBox.put(immunityId, immMap);

    final pun = Map<String, dynamic>.from(punRaw);
    final newCompleted =
        ((pun['completedLines'] as int? ?? 0) + safeLines)
            .clamp(0, pun['totalLines'] as int);
    pun['completedLines'] = newCompleted;
    if (newCompleted >= (pun['totalLines'] as int)) {
      pun['isCompleted'] = true;
      pun['completedAt'] = DateTime.now().toIso8601String();
    }
    await _punishmentsBox.put(punishmentId, pun);

    notifyListeners();
    _syncToFirestore();
  }

  Future<void> removeImmunity(String id) async {
    await _immunitiesBox.delete(id);
    notifyListeners();
    _syncToFirestore();
  }

  Future<void> deleteImmunity(String id) async => removeImmunity(id);

  Future<void> reactivateImmunity(String id) async {
    final raw = _immunitiesBox.get(id);
    if (raw == null) return;
    final m = Map<String, dynamic>.from(raw);
    m['usedLines'] = 0;
    if (m['expiresAt'] != null) {
      m['expiresAt'] =
          DateTime.now().add(const Duration(days: 7)).toIso8601String();
    }
    await _immunitiesBox.put(id, m);
    notifyListeners();
    _syncToFirestore();
  }

  int getTotalAvailableImmunity(String childId) {
    return getImmunities(childId)
        .where((i) => i.isUsable)
        .fold<int>(0, (sum, i) => sum + i.availableLines);
  }

  // ─── Custom Badges ────────────────────────────────────
  Future<void> addCustomBadge(String name, String icon, String description,
      int requiredPoints, {String powerType = 'custom'}) async {
    final id    = 'custom_${DateTime.now().millisecondsSinceEpoch}';
    final badge = BadgeModel(
      id: id, name: name, icon: icon, description: description,
      requiredPoints: requiredPoints, powerType: powerType, isCustom: true,
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

  Future<void> removeCustomBadge(String id) async => deleteCustomBadge(id);

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

  int getSaturdayMinutes(String childId) =>
      (getScreenTime(childId)?['saturdayMinutes'] as int?) ?? 0;

  int getSundayMinutes(String childId) =>
      (getScreenTime(childId)?['sundayMinutes'] as int?) ?? 0;

  int getParentBonusMinutes(String childId) =>
      (getScreenTime(childId)?['bonusMinutes'] as int?) ?? 0;

  int getBonusMinutes(String childId) => getParentBonusMinutes(childId);

  int getWeeklyScreenMinutes(String childId) =>
      getSaturdayMinutes(childId) +
      getSundayMinutes(childId) +
      getParentBonusMinutes(childId);

  // ─── Weekly Score ─────────────────────────────────────
  int getWeeklyScore(String childId) {
    final now       = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final start     = DateTime(weekStart.year, weekStart.month, weekStart.day);
    return history
        .where((e) => e.childId == childId && e.date.isAfter(start))
        .fold<int>(0, (sum, e) => sum + e.points);
  }

  // ─── Tribunal ─────────────────────────────────────────
  Future<void> fileTribunalCase({
    required String title,
    required String description,
    required String plaintiffId,
    required String accusedId,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final tc = TribunalCase(
      id: id, title: title, description: description,
      plaintiffId: plaintiffId, accusedId: accusedId,
      status: TribunalStatus.filed,
    );
    await _tribunalBox.put(id, tc.toMap());
    notifyListeners();
    _syncToFirestore();
  }

  Future<void> startTribunalHearing(String caseId) async {
    final raw = _tribunalBox.get(caseId);
    if (raw == null) return;
    final tc = TribunalCase.fromMap(Map<String, dynamic>.from(raw));
    tc.status = TribunalStatus.inProgress;
    await _tribunalBox.put(caseId, tc.toMap());
    notifyListeners();
    _syncToFirestore();
  }

  Future<void> startTribunalDeliberation(String caseId) async {
    final raw = _tribunalBox.get(caseId);
    if (raw == null) return;
    final tc = TribunalCase.fromMap(Map<String, dynamic>.from(raw));
    tc.status = TribunalStatus.deliberation;
    await _tribunalBox.put(caseId, tc.toMap());
    notifyListeners();
    _syncToFirestore();
  }

  Future<void> dismissTribunalCase(String caseId) async {
    final raw = _tribunalBox.get(caseId);
    if (raw == null) return;
    final tc = TribunalCase.fromMap(Map<String, dynamic>.from(raw));
    tc.status      = TribunalStatus.closed;
    tc.verdict     = TribunalVerdict.dismissed;
    tc.verdictDate = DateTime.now();
    await _tribunalBox.put(caseId, tc.toMap());
    notifyListeners();
    _syncToFirestore();
  }

  Future<void> renderVerdict({
    required String caseId,
    required TribunalVerdict verdict,
    String? reason,
    int accusedPoints = 0,
  }) async {
    final raw = _tribunalBox.get(caseId);
    if (raw == null) return;
    final tc          = TribunalCase.fromMap(Map<String, dynamic>.from(raw));
    tc.status          = TribunalStatus.verdict;
    tc.verdict         = verdict;
    tc.verdictReason   = reason;
    tc.verdictDate     = DateTime.now();
    tc.accusedPoints   = accusedPoints;
    await _tribunalBox.put(caseId, tc.toMap());
    if (accusedPoints != 0) {
      await addPoints(
        tc.accusedId, accusedPoints,
        'Verdict tribunal: ${reason ?? verdict.name}',
        category: 'Tribunal',
      );
    }
    notifyListeners();
    _syncToFirestore();
  }

  Future<void> voteTribunal(
      String caseId, String voterId, TribunalVerdict vote) async {
    final raw = _tribunalBox.get(caseId);
    if (raw == null) return;
    final tc = TribunalCase.fromMap(Map<String, dynamic>.from(raw));
    tc.votes.removeWhere((v) => v.childId == voterId);
    tc.votes.add(TribunalVote(childId: voterId, vote: vote));
    await _tribunalBox.put(caseId, tc.toMap());
    notifyListeners();
    _syncToFirestore();
  }

  Future<void> deleteTribunalCase(String id) async {
    await _tribunalBox.delete(id);
    notifyListeners();
    _syncToFirestore();
  }

  // ─── Trades ───────────────────────────────────────────
  Future<void> createTrade(
      String fromChildId, String toChildId, int lines, String serviceDescription) async {
    final id    = DateTime.now().millisecondsSinceEpoch.toString();
    final trade = TradeModel(
      id: id, fromChildId: fromChildId, toChildId: toChildId,
      immunityLines: lines, serviceDescription: serviceDescription,
      status: 'pending',
    );
    await _tradesBox.put(id, trade.toMap());
    notifyListeners();
    _syncToFirestore();
  }

  Future<void> acceptTrade(String id) async    => _updateTradeStatus(id, 'accepted');
  Future<void> rejectTrade(String id) async     => _updateTradeStatus(id, 'rejected');
  Future<void> cancelTrade(String id) async     => _updateTradeStatus(id, 'cancelled');
  Future<void> markServiceDone(String id) async => _updateTradeStatus(id, 'service_done');

  Future<void> completeTrade(String id, {String? parentNote}) async {
    final raw = _tradesBox.get(id);
    if (raw == null) return;
    final m = Map<String, dynamic>.from(raw);
    m['status']      = 'completed';
    m['completedAt'] = DateTime.now().toIso8601String();
    if (parentNote != null) m['parentValidatorNote'] = parentNote;
    final trade = TradeModel.fromMap(m);
    await addImmunity(
      childId: trade.toChildId,
      reason:  'Achat: ${trade.serviceDescription}',
      lines:   trade.immunityLines,
    );
    await _tradesBox.put(id, m);
    notifyListeners();
    _syncToFirestore();
  }

  Future<void> _updateTradeStatus(String id, String status) async {
    final raw = _tradesBox.get(id);
    if (raw == null) return;
    final m   = Map<String, dynamic>.from(raw);
    m['status'] = status;
    if (status == 'accepted')  m['acceptedAt']  = DateTime.now().toIso8601String();
    if (status == 'completed') m['completedAt'] = DateTime.now().toIso8601String();
    await _tradesBox.put(id, m);
    notifyListeners();
    _syncToFirestore();
  }

  Future<void> addTrade(TradeModel trade) async {
    await _tradesBox.put(trade.id, trade.toMap());
    notifyListeners();
    _syncToFirestore();
  }

  Future<void> deleteTrade(String id) async {
    await _tradesBox.delete(id);
    notifyListeners();
    _syncToFirestore();
  }

  List<TradeModel> getTradesForChild(String childId) =>
      trades.where((t) => t.fromChildId == childId || t.toChildId == childId).toList();

  List<TradeModel> getPendingTradesForChild(String childId) =>
      trades.where((t) => t.isPending && t.toChildId == childId).toList();

  List<TradeModel> getActiveTrades() => trades.where((t) => t.isActive).toList();

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
      final keys = <dynamic>[];
      for (final key in _historyBox.keys) {
        final m = Map<String, dynamic>.from(_historyBox.get(key)!);
        if (m['childId'] == childId) keys.add(key);
      }
      for (final k in keys) { await _historyBox.delete(k); }
    }
    notifyListeners();
    _syncToFirestore();
  }

  Future<void> clearChildHistory(String childId) async => clearHistory(childId);

  Future<void> clearChildPunishments(String childId) async {
    final keys = <dynamic>[];
    for (final key in _punishmentsBox.keys) {
      final m = Map<String, dynamic>.from(_punishmentsBox.get(key)!);
      if (m['childId'] == childId) keys.add(key);
    }
    for (final k in keys) { await _punishmentsBox.delete(k); }
    notifyListeners();
    _syncToFirestore();
  }

  Future<void> clearChildImmunities(String childId) async {
    final keys = <dynamic>[];
    for (final key in _immunitiesBox.keys) {
      final m = Map<String, dynamic>.from(_immunitiesBox.get(key)!);
      if (m['childId'] == childId) keys.add(key);
    }
    for (final k in keys) { await _immunitiesBox.delete(k); }
    notifyListeners();
    _syncToFirestore();
  }

  Future<void> clearAllPunishments({String? childId}) async {
    if (childId == null) {
      await _punishmentsBox.clear();
    } else {
      await clearChildPunishments(childId);
    }
    notifyListeners();
    _syncToFirestore();
  }

  Future<void> clearAllImmunities({String? childId}) async {
    if (childId == null) {
      await _immunitiesBox.clear();
    } else {
      await clearChildImmunities(childId);
    }
    notifyListeners();
    _syncToFirestore();
  }

  Future<void> resetAllData() async {
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
    _familyCode    = null;
    _isSyncEnabled = false;
    await _metaBox.clear();
    notifyListeners();
  }

  Future<void> resetEverything() async => resetAllData();

  // ─── School Notes ─────────────────────────────────────
  Future<void> addSchoolNote(String childId, String subject, double grade,
      double maxGrade, {String? comment, String? photoBase64}) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    await _schoolNotesBox.put(id, {
      'id': id, 'childId': childId, 'subject': subject,
      'grade': grade, 'maxGrade': maxGrade, 'comment': comment,
      'photoBase64': photoBase64, 'isValidated': false,
      'createdAt': DateTime.now().toIso8601String(),
    });
    notifyListeners();
    _syncToFirestore();
  }

  Future<void> validateSchoolNote(String noteId,
      {bool validated = true, int bonusPoints = 0, String? childId}) async {
    final raw = _schoolNotesBox.get(noteId);
    if (raw == null) return;
    final note = Map<String, dynamic>.from(raw);
    note['isValidated'] = validated;
    note['validatedAt'] = DateTime.now().toIso8601String();
    await _schoolNotesBox.put(noteId, note);
    if (validated && bonusPoints > 0 && childId != null) {
      await addPoints(
        childId, bonusPoints,
        'Bonus note scolaire: ${note['subject']}',
        category: 'École',
      );
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

  // ─── Firestore Sync ───────────────────────────────────
  Future<void> _syncToFirestore() async {
    if (!_isSyncEnabled || _familyCode == null) return;
    try {
      final db  = FirebaseFirestore.instance;
      final ref = db.collection('families').doc(_familyCode);
      await ref.set({
        'children':  children.map((c) => c.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firestore sync error: $e');
    }
  }
}
