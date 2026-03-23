import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/child_model.dart';
import '../models/goal_model.dart';
import '../models/history_entry.dart';
import '../models/note_model.dart';
import '../models/badge_model.dart';
import '../models/punishment_lines.dart';
import '../models/immunity_lines.dart';
import '../models/tribunal_model.dart';
import '../models/trade_model.dart';
import '../services/firestore_service.dart';

class FamilyProvider extends ChangeNotifier {
  final FirestoreService _firestore = FirestoreService();

  late Box _childrenBox;
  late Box _historyBox;
  late Box _goalsBox;
  late Box _notesBox;
  late Box _punishmentsBox;
  late Box _immunitiesBox;
  late Box _tribunalBox;
  late Box _badgesBox;
  late Box _metaBox;
  late Box _screenTimeBox;
  late Box _tradesBox;

  List<ChildModel> _children = [];
  List<HistoryEntry> _history = [];
  List<GoalModel> _goals = [];
  List<NoteModel> _notes = [];
  List<PunishmentLines> _punishments = [];
  List<ImmunityLines> _immunities = [];
  List<TribunalCase> _tribunalCases = [];
  List<BadgeModel> _customBadges = [];
  List<TradeModel> _trades = [];

  String? _familyCode;

  // ══════════════════════════════════════
  //  GETTERS
  // ══════════════════════════════════════
  List<ChildModel> get children => _children;
  List<HistoryEntry> get history => _history;
  List<GoalModel> get goals => _goals;
  List<NoteModel> get notes => _notes;
  List<PunishmentLines> get punishments => _punishments;
  List<ImmunityLines> get immunities => _immunities;
  List<TribunalCase> get tribunalCases => _tribunalCases;
  List<BadgeModel> get customBadges => _customBadges;
  List<TradeModel> get trades => _trades;
  String? get familyCode => _familyCode;
  String? get familyId => _familyCode;
  bool get isSyncEnabled => _firestore.isConnected;

  List<ChildModel> get childrenSorted {
    final sorted = List<ChildModel>.from(_children);
    sorted.sort((a, b) => b.points.compareTo(a.points));
    return sorted;
  }

  List<TribunalCase> get activeTribunalCases =>
      _tribunalCases.where((c) => c.status != TribunalStatus.closed).toList();
  List<TribunalCase> get closedTribunalCases =>
      _tribunalCases.where((c) => c.status == TribunalStatus.closed).toList();

  // ══════════════════════════════════════
  //  INIT
  // ══════════════════════════════════════
  Future<void> init() async {
    _childrenBox = await Hive.openBox('children');
    _historyBox = await Hive.openBox('history');
    _goalsBox = await Hive.openBox('goals');
    _notesBox = await Hive.openBox('notes');
    _punishmentsBox = await Hive.openBox('punishments');
    _immunitiesBox = await Hive.openBox('immunities');
    _tribunalBox = await Hive.openBox('tribunal');
    _badgesBox = await Hive.openBox('custom_badges');
    _metaBox = await Hive.openBox('meta');
    _screenTimeBox = await Hive.openBox('screen_time');
    _tradesBox = await Hive.openBox('trades');

    _loadLocal();

    try {
      await _firestore.init();
      _familyCode = await _firestore.getFamilyCode();
      if (_firestore.isConnected) {
        _setupFirestoreCallbacks();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Firestore init error: $e');
    }
    notifyListeners();
  }

  void _loadLocal() {
    _children = _childrenBox.values
        .map((v) => ChildModel.fromMap(Map<String, dynamic>.from(jsonDecode(v))))
        .toList();
    _history = _historyBox.values
        .map((v) => HistoryEntry.fromMap(Map<String, dynamic>.from(jsonDecode(v))))
        .toList();
    _history.sort((a, b) => b.date.compareTo(a.date));
    _goals = _goalsBox.values
        .map((v) => GoalModel.fromMap(Map<String, dynamic>.from(jsonDecode(v))))
        .toList();
    _notes = _notesBox.values
        .map((v) => NoteModel.fromMap(Map<String, dynamic>.from(jsonDecode(v))))
        .toList();
    _punishments = _punishmentsBox.values
        .map((v) => PunishmentLines.fromMap(Map<String, dynamic>.from(jsonDecode(v))))
        .toList();
    _immunities = _immunitiesBox.values
        .map((v) => ImmunityLines.fromMap(Map<String, dynamic>.from(jsonDecode(v))))
        .toList();
    _tribunalCases = _tribunalBox.values
        .map((v) => TribunalCase.fromMap(Map<String, dynamic>.from(jsonDecode(v))))
        .toList();
    _customBadges = _badgesBox.values
        .map((v) => BadgeModel.fromMap(Map<String, dynamic>.from(jsonDecode(v))))
        .toList();
    _trades = _tradesBox.values
        .map((v) => TradeModel.fromMap(Map<String, dynamic>.from(jsonDecode(v))))
        .toList();
  }

  void _setupFirestoreCallbacks() {
    _firestore.onChildrenChanged = (list, _) {
      _children = list;
      _saveBoxFromList(_childrenBox, _children, (e) => e.id, (e) => e.toMap());
      notifyListeners();
    };
    _firestore.onHistoryChanged = (list, _) {
      _history = list;
      _history.sort((a, b) => b.date.compareTo(a.date));
      _saveBoxFromList(_historyBox, _history, (e) => e.id, (e) => e.toMap());
      notifyListeners();
    };
    _firestore.onGoalsChanged = (list, _) {
      _goals = list;
      _saveBoxFromList(_goalsBox, _goals, (e) => e.id, (e) => e.toMap());
      notifyListeners();
    };
    _firestore.onPunishmentsChanged = (list, _) {
      _punishments = list;
      _saveBoxFromList(_punishmentsBox, _punishments, (e) => e.id, (e) => e.toMap());
      notifyListeners();
    };
    _firestore.onNotesChanged = (list) {
      _notes = list;
      _saveBoxFromList(_notesBox, _notes, (e) => e.id, (e) => e.toMap());
      notifyListeners();
    };
  }

  void _saveBoxFromList<T>(Box box, List<T> items, String Function(T) getId, Map<String, dynamic> Function(T) toMap) {
    box.clear();
    for (final item in items) {
      box.put(getId(item), jsonEncode(toMap(item)));
    }
  }

  Future<void> reconnectFirestore() async {
    if (_firestore.isConnected) {
      _firestore.reconnect();
      _setupFirestoreCallbacks();
    }
  }

  // ══════════════════════════════════════
  //  FAMILY
  // ══════════════════════════════════════
  Future<String> createFamily({String? customCode}) async {
    final code = await _firestore.createFamily(customCode: customCode);
    _familyCode = code;
    _setupFirestoreCallbacks();
    await _firestore.uploadLocalData(
      children: _children,
      history: _history,
      goals: _goals,
      punishments: _punishments,
    );
    await _firestore.uploadNotes(_notes);
    notifyListeners();
    return code;
  }

  Future<bool> joinFamily(String code) async {
    final ok = await _firestore.joinFamily(code);
    if (ok) {
      _familyCode = code;
      _setupFirestoreCallbacks();
      notifyListeners();
    }
    return ok;
  }

  Future<void> disconnectFamily() async {
    await _firestore.disconnectFamily();
    _familyCode = null;
    notifyListeners();
  }

  String getFamilyCode() => _familyCode ?? '';

  // ══════════════════════════════════════
  //  CHILDREN
  // ══════════════════════════════════════
  ChildModel? getChild(String id) {
    try {
      return _children.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> addChild(String name, String avatar) async {
    final child = ChildModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      avatar: avatar,
    );
    _children.add(child);
    await _childrenBox.put(child.id, jsonEncode(child.toMap()));
    if (_firestore.isConnected) await _firestore.saveChild(child);
    notifyListeners();
  }

  Future<void> updateChild(String id, String name, String avatar) async {
    final child = getChild(id);
    if (child == null) return;
    child.name = name;
    child.avatar = avatar;
    await _childrenBox.put(child.id, jsonEncode(child.toMap()));
    if (_firestore.isConnected) await _firestore.saveChild(child);
    notifyListeners();
  }

  Future<void> updateChildPhoto(String childId, String base64Photo) async {
    final child = getChild(childId);
    if (child == null) return;
    child.photoBase64 = base64Photo;
    await _childrenBox.put(child.id, jsonEncode(child.toMap()));
    if (_firestore.isConnected) await _firestore.saveChild(child);
    notifyListeners();
  }

  Future<void> removeChild(String id) async {
    _children.removeWhere((c) => c.id == id);
    await _childrenBox.delete(id);
    _history.removeWhere((h) => h.childId == id);
    _goals.removeWhere((g) => g.childId == id);
    _notes.removeWhere((n) => n.childId == id);
    _punishments.removeWhere((p) => p.childId == id);
    _immunities.removeWhere((im) => im.childId == id);
    _trades.removeWhere((t) => t.fromChildId == id || t.toChildId == id);
    await _saveAllLocal();
    if (_firestore.isConnected) await _firestore.deleteChild(id);
    notifyListeners();
  }

  // ══════════════════════════════════════
  //  POINTS
  // ══════════════════════════════════════
  Future<void> addPoints(
    String childId,
    int points,
    String reason, {
    String category = 'Bonus',
    bool isBonus = true,
    String? proofPhoto,
    String? proofPhotoBase64,
    DateTime? date,
  }) async {
    final child = getChild(childId);
    if (child == null) return;

    if (isBonus) {
      child.points += points;
    } else {
      child.points -= points;
    }
    await _childrenBox.put(child.id, jsonEncode(child.toMap()));
    if (_firestore.isConnected) await _firestore.saveChild(child);

    final entry = HistoryEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      childId: childId,
      points: points,
      reason: reason,
      category: category,
      isBonus: isBonus,
      proofPhotoBase64: proofPhoto ?? proofPhotoBase64,
      date: date,
    );
    _history.insert(0, entry);
    await _historyBox.put(entry.id, jsonEncode(entry.toMap()));
    if (_firestore.isConnected) await _firestore.saveHistoryEntry(entry);

    _checkBadgeUnlock(child);
    notifyListeners();
  }

  void _checkBadgeUnlock(ChildModel child) {
    final allBadges = [...BadgeModel.defaultBadges, ..._customBadges];
    for (final badge in allBadges) {
      if (child.points >= badge.requiredPoints && !child.badgeIds.contains(badge.id)) {
        child.badgeIds.add(badge.id);
      }
    }
    _childrenBox.put(child.id, jsonEncode(child.toMap()));
    if (_firestore.isConnected) _firestore.saveChild(child);
  }
  // ══════════════════════════════════════
  //  GOALS
  // ══════════════════════════════════════
  List<GoalModel> getGoalsForChild(String childId) =>
      _goals.where((g) => g.childId == childId).toList();

  Future<void> addGoal(String childId, String title, int targetPoints) async {
    final goal = GoalModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      childId: childId,
      title: title,
      targetPoints: targetPoints,
    );
    _goals.add(goal);
    await _goalsBox.put(goal.id, jsonEncode(goal.toMap()));
    if (_firestore.isConnected) await _firestore.saveGoal(goal);
    notifyListeners();
  }

  Future<void> toggleGoal(String goalId) async {
    try {
      final goal = _goals.firstWhere((g) => g.id == goalId);
      goal.completed = !goal.completed;
      await _goalsBox.put(goal.id, jsonEncode(goal.toMap()));
      if (_firestore.isConnected) await _firestore.saveGoal(goal);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> removeGoal(String goalId) async {
    _goals.removeWhere((g) => g.id == goalId);
    await _goalsBox.delete(goalId);
    if (_firestore.isConnected) await _firestore.deleteGoal(goalId);
    notifyListeners();
  }

  // ══════════════════════════════════════
  //  NOTES
  // ══════════════════════════════════════
  List<NoteModel> getNotesForChild(String childId) =>
      _notes.where((n) => n.childId == childId).toList();

  Future<void> addNote(String childId, String text, {String authorName = 'Parent'}) async {
    final note = NoteModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      childId: childId,
      text: text,
      authorName: authorName,
    );
    _notes.add(note);
    await _notesBox.put(note.id, jsonEncode(note.toMap()));
    if (_firestore.isConnected) await _firestore.saveNote(note);
    notifyListeners();
  }

  Future<void> updateNote(String noteId, String newText) async {
    try {
      final note = _notes.firstWhere((n) => n.id == noteId);
      note.text = newText;
      await _notesBox.put(note.id, jsonEncode(note.toMap()));
      if (_firestore.isConnected) await _firestore.saveNote(note);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> deleteNote(String noteId) async {
    _notes.removeWhere((n) => n.id == noteId);
    await _notesBox.delete(noteId);
    if (_firestore.isConnected) await _firestore.deleteNote(noteId);
    notifyListeners();
  }

  Future<void> removeNote(String noteId) async => deleteNote(noteId);

  Future<void> toggleNotePin(String noteId) async {
    try {
      final note = _notes.firstWhere((n) => n.id == noteId);
      note.isPinned = !note.isPinned;
      await _notesBox.put(note.id, jsonEncode(note.toMap()));
      if (_firestore.isConnected) await _firestore.saveNote(note);
      notifyListeners();
    } catch (_) {}
  }

  // ══════════════════════════════════════
  //  PUNISHMENT LINES
  // ══════════════════════════════════════
  Future<void> addPunishment(String childId, String text, int totalLines) async {
    final p = PunishmentLines(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      childId: childId,
      text: text,
      totalLines: totalLines,
    );
    _punishments.add(p);
    await _punishmentsBox.put(p.id, jsonEncode(p.toMap()));
    if (_firestore.isConnected) await _firestore.savePunishment(p);
    notifyListeners();
  }

  Future<void> removePunishment(String id) async {
    _punishments.removeWhere((p) => p.id == id);
    await _punishmentsBox.delete(id);
    if (_firestore.isConnected) await _firestore.deletePunishment(id);
    notifyListeners();
  }

  Future<void> updatePunishmentProgress(String id, int linesToAdd) async {
    try {
      final p = _punishments.firstWhere((p) => p.id == id);
      p.completedLines = (p.completedLines + linesToAdd).clamp(0, p.totalLines);
      await _punishmentsBox.put(p.id, jsonEncode(p.toMap()));
      if (_firestore.isConnected) await _firestore.savePunishment(p);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> addPhotoToPunishment(String id, String base64Photo) async {
    try {
      final p = _punishments.firstWhere((p) => p.id == id);
      p.photoUrls.add(base64Photo);
      await _punishmentsBox.put(p.id, jsonEncode(p.toMap()));
      if (_firestore.isConnected) await _firestore.savePunishment(p);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> removePhotoFromPunishment(String id, int index) async {
    try {
      final p = _punishments.firstWhere((p) => p.id == id);
      if (index >= 0 && index < p.photoUrls.length) {
        p.photoUrls.removeAt(index);
        await _punishmentsBox.put(p.id, jsonEncode(p.toMap()));
        if (_firestore.isConnected) await _firestore.savePunishment(p);
        notifyListeners();
      }
    } catch (_) {}
  }

  // ══════════════════════════════════════
  //  IMMUNITY LINES
  // ══════════════════════════════════════
  Future<void> addImmunity(String childId, String reason, int lines, {DateTime? expiresAt}) async {
    final im = ImmunityLines(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      childId: childId,
      reason: reason,
      lines: lines,
      expiresAt: expiresAt,
    );
    _immunities.add(im);
    await _immunitiesBox.put(im.id, jsonEncode(im.toMap()));
    notifyListeners();
  }

  Future<void> removeImmunity(String id) async {
    _immunities.removeWhere((im) => im.id == id);
    await _immunitiesBox.delete(id);
    notifyListeners();
  }

  int getTotalAvailableImmunity(String childId) =>
      _immunities.where((im) => im.childId == childId && im.isUsable).fold<int>(0, (s, im) => s + im.availableLines);

  List<ImmunityLines> getUsableImmunitiesForChild(String childId) =>
      _immunities.where((im) => im.childId == childId && im.isUsable).toList();

  List<ImmunityLines> getImmunitiesForChild(String childId) =>
      _immunities.where((im) => im.childId == childId).toList();

  Future<void> useImmunityOnPunishment(String immunityId, String punishmentId, int lines) async {
    try {
      final im = _immunities.firstWhere((i) => i.id == immunityId);
      final p = _punishments.firstWhere((p) => p.id == punishmentId);
      final actualLines = lines.clamp(0, im.availableLines).clamp(0, p.totalLines - p.completedLines);
      im.usedLines += actualLines;
      p.completedLines = (p.completedLines + actualLines).clamp(0, p.totalLines);
      await _immunitiesBox.put(im.id, jsonEncode(im.toMap()));
      await _punishmentsBox.put(p.id, jsonEncode(p.toMap()));
      if (_firestore.isConnected) await _firestore.savePunishment(p);
      notifyListeners();
    } catch (_) {}
  }

  // ══════════════════════════════════════
  //  BADGES
  // ══════════════════════════════════════
  List<BadgeModel> getBadgesForChild(String childId) {
    final child = getChild(childId);
    if (child == null) return [];
    final allBadges = [...BadgeModel.defaultBadges, ..._customBadges];
    return allBadges.where((b) => child.badgeIds.contains(b.id)).toList();
  }

  Future<void> addCustomBadge(String name, String icon, String description, int requiredPoints, {String powerType = 'custom'}) async {
    final badge = BadgeModel(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      icon: icon,
      description: description,
      requiredPoints: requiredPoints,
      powerType: powerType,
      isCustom: true,
    );
    _customBadges.add(badge);
    await _badgesBox.put(badge.id, jsonEncode(badge.toMap()));
    notifyListeners();
  }

  Future<void> removeCustomBadge(String id) async {
    _customBadges.removeWhere((b) => b.id == id);
    await _badgesBox.delete(id);
    for (final child in _children) {
      child.badgeIds.remove(id);
      await _childrenBox.put(child.id, jsonEncode(child.toMap()));
    }
    notifyListeners();
  }

  // ══════════════════════════════════════
  //  SCREEN TIME
  // ══════════════════════════════════════
  String _screenTimeKey(String childId, String key) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekStr = '${weekStart.year}_${weekStart.month}_${weekStart.day}';
    return '${childId}_${weekStr}_$key';
  }

  double getWeeklySchoolAverage(String childId) {
    final notes = _getWeekSchoolNotes(childId);
    if (notes.isEmpty) return -1;
    final total = notes.fold<int>(0, (s, n) => s + n.points);
    return total / notes.length;
  }

  double getWeeklyBehaviorScore(String childId) {
    final weekEntries = _getWeekHistory(childId)
        .where((h) => h.category != 'school_note' && h.category != 'screen_time_bonus' && h.category != 'saturday_rating')
        .toList();
    if (weekEntries.isEmpty) return 10.0;
    int bonusCount = weekEntries.where((h) => h.isBonus).length;
    int penaltyCount = weekEntries.where((h) => !h.isBonus).length;
    int total = bonusCount + penaltyCount;
    if (total == 0) return 10.0;
    double ratio = bonusCount / total;
    return (ratio * 20).clamp(0, 20);
  }

  double getWeeklyGlobalScore(String childId) {
    final schoolAvg = getWeeklySchoolAverage(childId);
    final behaviorScore = getWeeklyBehaviorScore(childId);
    if (schoolAvg < 0) return behaviorScore;
    return (schoolAvg * 0.6 + behaviorScore * 0.4);
  }

  int _minutesFromGlobalScore(double score) {
    if (score >= 18) return 180;
    if (score >= 16) return 150;
    if (score >= 14) return 120;
    if (score >= 12) return 90;
    if (score >= 10) return 60;
    if (score >= 8) return 30;
    return 0;
  }

  int getSaturdayMinutes(String childId) {
    final globalScore = getWeeklyGlobalScore(childId);
    final base = _minutesFromGlobalScore(globalScore);
    final bonus = getParentBonusMinutes(childId);
    return (base + bonus).clamp(0, 480);
  }

  int getSundayMinutes(String childId) {
    final satRating = getSaturdayBehaviorRating(childId);
    if (satRating < 0) return getSaturdayMinutes(childId);
    final base = _minutesFromGlobalScore(satRating);
    final bonus = getParentBonusMinutes(childId);
    return (base + bonus).clamp(0, 480);
  }

  int getParentBonusMinutes(String childId) {
    final key = _screenTimeKey(childId, 'bonus');
    return _screenTimeBox.get(key, defaultValue: 0) as int;
  }

  double getSaturdayBehaviorRating(String childId) {
    final key = _screenTimeKey(childId, 'sat_rating');
    return (_screenTimeBox.get(key, defaultValue: -1.0) as num).toDouble();
  }

  Future<void> addScreenTimeBonus(String childId, int minutes, String reason) async {
    final key = _screenTimeKey(childId, 'bonus');
    final current = _screenTimeBox.get(key, defaultValue: 0) as int;
    await _screenTimeBox.put(key, current + minutes);

    final entry = HistoryEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      childId: childId,
      points: minutes.abs(),
      reason: '📺 $reason (${minutes > 0 ? '+' : ''}${minutes}min)',
      category: 'screen_time_bonus',
      isBonus: minutes > 0,
    );
    _history.insert(0, entry);
    await _historyBox.put(entry.id, jsonEncode(entry.toMap()));
    if (_firestore.isConnected) await _firestore.saveHistoryEntry(entry);
    notifyListeners();
  }

  Future<void> resetScreenTimeBonus(String childId) async {
    final key = _screenTimeKey(childId, 'bonus');
    await _screenTimeBox.put(key, 0);
    notifyListeners();
  }

  Future<void> rateSaturdayBehavior(String childId, int rating) async {
    final key = _screenTimeKey(childId, 'sat_rating');
    await _screenTimeBox.put(key, rating.toDouble());

    final entry = HistoryEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      childId: childId,
      points: rating,
      reason: '📋 Note samedi: $rating/20',
      category: 'saturday_rating',
      isBonus: true,
    );
    _history.insert(0, entry);
    await _historyBox.put(entry.id, jsonEncode(entry.toMap()));
    if (_firestore.isConnected) await _firestore.saveHistoryEntry(entry);
    notifyListeners();
  }

  List<HistoryEntry> _getWeekHistory(String childId) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final start = DateTime(weekStart.year, weekStart.month, weekStart.day);
    return _history.where((h) => h.childId == childId && h.date.isAfter(start)).toList();
  }

  List<HistoryEntry> _getWeekSchoolNotes(String childId) {
    return _getWeekHistory(childId).where((h) => h.category == 'school_note').toList();
  }
  // ══════════════════════════════════════
  //  TRIBUNAL
  // ══════════════════════════════════════
  Future<void> addTribunalCase(TribunalCase tc) async {
    _tribunalCases.add(tc);
    await _tribunalBox.put(tc.id, jsonEncode(tc.toMap()));
    notifyListeners();
  }

  Future<void> updateTribunalCase(TribunalCase tc) async {
    final idx = _tribunalCases.indexWhere((c) => c.id == tc.id);
    if (idx != -1) {
      _tribunalCases[idx] = tc;
      await _tribunalBox.put(tc.id, jsonEncode(tc.toMap()));
      notifyListeners();
    }
  }

  Future<void> removeTribunalCase(String id) async {
    _tribunalCases.removeWhere((c) => c.id == id);
    await _tribunalBox.delete(id);
    notifyListeners();
  }

  Future<void> fileTribunalCase({
    required String title,
    required String description,
    required String plaintiffId,
    required String accusedId,
    String? prosecutionLawyerId,
    String? defenseLawyerId,
    List<String>? witnessIds,
  }) async {
    final participants = <TribunalParticipant>[
      TribunalParticipant(childId: plaintiffId, role: TribunalRole.plaintiff),
      TribunalParticipant(childId: accusedId, role: TribunalRole.accused),
    ];
    if (prosecutionLawyerId != null) {
      participants.add(TribunalParticipant(childId: prosecutionLawyerId, role: TribunalRole.prosecutionLawyer));
    }
    if (defenseLawyerId != null) {
      participants.add(TribunalParticipant(childId: defenseLawyerId, role: TribunalRole.defenseLawyer));
    }
    if (witnessIds != null) {
      for (final wId in witnessIds) {
        participants.add(TribunalParticipant(childId: wId, role: TribunalRole.witness));
      }
    }

    final tc = TribunalCase(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      description: description,
      plaintiffId: plaintiffId,
      accusedId: accusedId,
      participants: participants,
      status: TribunalStatus.filed,
    );
    _tribunalCases.add(tc);
    await _tribunalBox.put(tc.id, jsonEncode(tc.toMap()));
    notifyListeners();
  }

  Future<void> scheduleTribunalHearing(String caseId, DateTime date) async {
    try {
      final tc = _tribunalCases.firstWhere((c) => c.id == caseId);
      tc.status = TribunalStatus.scheduled;
      tc.scheduledDate = date;
      await _tribunalBox.put(tc.id, jsonEncode(tc.toMap()));
      notifyListeners();
    } catch (_) {}
  }

  Future<void> startTribunalHearing(String caseId) async {
    try {
      final tc = _tribunalCases.firstWhere((c) => c.id == caseId);
      tc.status = TribunalStatus.inProgress;
      await _tribunalBox.put(tc.id, jsonEncode(tc.toMap()));
      notifyListeners();
    } catch (_) {}
  }

  Future<void> startTribunalDeliberation(String caseId) async {
    try {
      final tc = _tribunalCases.firstWhere((c) => c.id == caseId);
      tc.status = TribunalStatus.deliberation;
      await _tribunalBox.put(tc.id, jsonEncode(tc.toMap()));
      notifyListeners();
    } catch (_) {}
  }

  Future<void> dismissTribunalCase(String caseId) async {
    try {
      final tc = _tribunalCases.firstWhere((c) => c.id == caseId);
      tc.status = TribunalStatus.closed;
      tc.verdict = TribunalVerdict.dismissed;
      tc.verdictReason = 'Classe sans suite';
      tc.verdictDate = DateTime.now();
      await _tribunalBox.put(tc.id, jsonEncode(tc.toMap()));
      notifyListeners();
    } catch (_) {}
  }

  Future<void> renderVerdict({
    required String caseId,
    required TribunalVerdict verdict,
    required String reason,
    required int plaintiffPoints,
    required int accusedPoints,
    Map<String, int>? lawyerPoints,
    Map<String, bool>? witnessVerified,
    Map<String, int>? witnessPoints,
  }) async {
    try {
      final tc = _tribunalCases.firstWhere((c) => c.id == caseId);
      tc.status = TribunalStatus.closed;
      tc.verdict = verdict;
      tc.verdictReason = reason;
      tc.verdictDate = DateTime.now();
      tc.plaintiffPoints = plaintiffPoints;
      tc.accusedPoints = accusedPoints;

      if (plaintiffPoints != 0) {
        await addPoints(tc.plaintiffId, plaintiffPoints.abs(), '⚖️ Tribunal: $reason',
            category: 'tribunal', isBonus: plaintiffPoints > 0);
      }
      if (accusedPoints != 0) {
        await addPoints(tc.accusedId, accusedPoints.abs(), '⚖️ Tribunal: $reason',
            category: 'tribunal', isBonus: accusedPoints > 0);
      }

      if (lawyerPoints != null) {
        for (final entry in lawyerPoints.entries) {
          if (entry.value != 0) {
            final participant = tc.participants.firstWhere((p) => p.childId == entry.key,
                orElse: () => TribunalParticipant(childId: entry.key, role: TribunalRole.witness));
            participant.pointsAwarded = entry.value;
            await addPoints(entry.key, entry.value.abs(), '⚖️ Tribunal (avocat)',
                category: 'tribunal', isBonus: entry.value > 0);
          }
        }
      }

      if (witnessVerified != null) {
        for (final entry in witnessVerified.entries) {
          final wParticipant = tc.participants.where((p) => p.childId == entry.key && p.role == TribunalRole.witness);
          if (wParticipant.isNotEmpty) {
            wParticipant.first.testimonyVerified = entry.value;
          }
        }
      }
      if (witnessPoints != null) {
        for (final entry in witnessPoints.entries) {
          if (entry.value != 0) {
            final wParticipant = tc.participants.where((p) => p.childId == entry.key && p.role == TribunalRole.witness);
            if (wParticipant.isNotEmpty) {
              wParticipant.first.pointsAwarded = entry.value;
            }
            await addPoints(entry.key, entry.value.abs(), '⚖️ Tribunal (temoin)',
                category: 'tribunal', isBonus: entry.value > 0);
          }
        }
      }

      await _tribunalBox.put(tc.id, jsonEncode(tc.toMap()));
      notifyListeners();
    } catch (_) {}
  }

  // ══════════════════════════════════════
  //  TRADES (ÉCHANGES D'IMMUNITÉ)
  // ══════════════════════════════════════
  List<TradeModel> getTradesForChild(String childId) {
    return _trades.where((t) => t.fromChildId == childId || t.toChildId == childId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<TradeModel> getActiveTradesForChild(String childId) {
    return _trades.where((t) => t.isActive && (t.fromChildId == childId || t.toChildId == childId)).toList();
  }

  List<TradeModel> getPendingTradesForChild(String childId) {
    return _trades.where((t) => t.isPending && t.toChildId == childId).toList();
  }

  Future<void> createTrade(String fromChildId, String toChildId, int lines, String serviceDescription) async {
    final totalAvailable = getTotalAvailableImmunity(fromChildId);
    if (lines <= 0 || lines > totalAvailable) return;
    if (fromChildId == toChildId) return;

    final trade = TradeModel(
      id: 'trade_${DateTime.now().millisecondsSinceEpoch}',
      fromChildId: fromChildId,
      toChildId: toChildId,
      immunityLines: lines,
      serviceDescription: serviceDescription,
    );

    _trades.add(trade);
    await _tradesBox.put(trade.id, jsonEncode(trade.toMap()));
    notifyListeners();
  }

  Future<void> acceptTrade(String tradeId) async {
    try {
      final trade = _trades.firstWhere((t) => t.id == tradeId);
      if (!trade.isPending) return;

      trade.status = 'accepted';
      trade.acceptedAt = DateTime.now();
      await _tradesBox.put(trade.id, jsonEncode(trade.toMap()));
      notifyListeners();
    } catch (_) {}
  }

  Future<void> markServiceDone(String tradeId) async {
    try {
      final trade = _trades.firstWhere((t) => t.id == tradeId);
      if (!trade.isAccepted) return;

      trade.status = 'service_done';
      await _tradesBox.put(trade.id, jsonEncode(trade.toMap()));
      notifyListeners();
    } catch (_) {}
  }

  Future<void> completeTrade(String tradeId, {String? parentNote}) async {
    try {
      final trade = _trades.firstWhere((t) => t.id == tradeId);
      if (!trade.isServiceDone) return;

      // Retirer les lignes d'immunité du fromChild
      int remaining = trade.immunityLines;
      final fromImmunities = getImmunitiesForChild(trade.fromChildId)
          .where((im) => im.isUsable)
          .toList();

      for (final im in fromImmunities) {
        if (remaining <= 0) break;
        final canUse = im.availableLines.clamp(0, remaining);
        im.usedLines += canUse;
        remaining -= canUse;
        await _immunitiesBox.put(im.id, jsonEncode(im.toMap()));
      }

      // Donner les lignes au toChild
      await addImmunity(
        trade.toChildId,
        'Echange: ${trade.serviceDescription}',
        trade.immunityLines,
      );

      trade.status = 'completed';
      trade.completedAt = DateTime.now();
      trade.parentValidatorNote = parentNote;
      await _tradesBox.put(trade.id, jsonEncode(trade.toMap()));
      notifyListeners();
    } catch (_) {}
  }

  Future<void> rejectTrade(String tradeId) async {
    try {
      final trade = _trades.firstWhere((t) => t.id == tradeId);
      if (!trade.isPending) return;

      trade.status = 'rejected';
      await _tradesBox.put(trade.id, jsonEncode(trade.toMap()));
      notifyListeners();
    } catch (_) {}
  }

  Future<void> cancelTrade(String tradeId) async {
    try {
      final trade = _trades.firstWhere((t) => t.id == tradeId);
      if (trade.isCompleted || trade.isRejected || trade.isCancelled) return;

      trade.status = 'cancelled';
      await _tradesBox.put(trade.id, jsonEncode(trade.toMap()));
      notifyListeners();
    } catch (_) {}
  }

  // ══════════════════════════════════════
  //  HISTORY QUERIES
  // ══════════════════════════════════════
  List<HistoryEntry> getHistoryForChild(String childId) =>
      _history.where((h) => h.childId == childId).toList();

  List<HistoryEntry> getHistoryForDate(DateTime date) =>
      _history.where((h) => h.date.year == date.year && h.date.month == date.month && h.date.day == date.day).toList();

  List<HistoryEntry> getRecentHistory(String childId, {int limit = 50}) {
    final childHistory = _history.where((h) => h.childId == childId).toList();
    childHistory.sort((a, b) => b.date.compareTo(a.date));
    return childHistory.take(limit).toList();
  }

  List<HistoryEntry> getWeeklyPoints(String childId) => _getWeekHistory(childId);

  Map<String, int> getWeeklyStats(String childId) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    final Map<String, int> stats = {for (var d in days) d: 0};
    for (int i = 0; i < 7; i++) {
      final day = DateTime(weekStart.year, weekStart.month, weekStart.day + i);
      final dayEntries = _history.where((h) =>
          h.childId == childId &&
          h.date.year == day.year &&
          h.date.month == day.month &&
          h.date.day == day.day);
      int total = 0;
      for (final e in dayEntries) {
        total += e.isBonus ? e.points : -e.points;
      }
      stats[days[i]] = total;
    }
    return stats;
  }

  // ══════════════════════════════════════
  //  RESET / CLEAR
  // ══════════════════════════════════════
  Future<void> resetAllScores() async {
    for (var child in _children) {
      child.points = 0;
      child.badgeIds.clear();
      await _childrenBox.put(child.id, jsonEncode(child.toMap()));
      if (_firestore.isConnected) await _firestore.saveChild(child);
    }
    notifyListeners();
  }

  Future<void> clearHistory() async {
    _history.clear();
    await _historyBox.clear();
    if (_firestore.isConnected) await _firestore.clearAllHistory();
    notifyListeners();
  }

  // ══════════════════════════════════════
  //  SAVE ALL LOCAL
  // ══════════════════════════════════════
  Future<void> _saveAllLocal() async {
    await _childrenBox.clear();
    for (final c in _children) await _childrenBox.put(c.id, jsonEncode(c.toMap()));
    await _historyBox.clear();
    for (final h in _history) await _historyBox.put(h.id, jsonEncode(h.toMap()));
    await _goalsBox.clear();
    for (final g in _goals) await _goalsBox.put(g.id, jsonEncode(g.toMap()));
    await _notesBox.clear();
    for (final n in _notes) await _notesBox.put(n.id, jsonEncode(n.toMap()));
    await _punishmentsBox.clear();
    for (final p in _punishments) await _punishmentsBox.put(p.id, jsonEncode(p.toMap()));
    await _immunitiesBox.clear();
    for (final im in _immunities) await _immunitiesBox.put(im.id, jsonEncode(im.toMap()));
    await _tribunalBox.clear();
    for (final tc in _tribunalCases) await _tribunalBox.put(tc.id, jsonEncode(tc.toMap()));
    await _badgesBox.clear();
    for (final b in _customBadges) await _badgesBox.put(b.id, jsonEncode(b.toMap()));
    await _tradesBox.clear();
    for (final t in _trades) await _tradesBox.put(t.id, jsonEncode(t.toMap()));
  }
}
