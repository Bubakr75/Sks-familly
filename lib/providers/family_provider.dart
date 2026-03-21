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
import '../services/firestore_service.dart';

class FamilyProvider extends ChangeNotifier {
  // ── Firestore ──
  final FirestoreService _firestore = FirestoreService();

  // ── Hive boxes ──
  late Box _childrenBox;
  late Box _historyBox;
  late Box _goalsBox;
  late Box _notesBox;
  late Box _punishmentsBox;
  late Box _immunitiesBox;
  late Box _tribunalBox;
  late Box _badgesBox;
  late Box _metaBox;

  // ── In-memory lists ──
  List<ChildModel> _children = [];
  List<HistoryEntry> _history = [];
  List<GoalModel> _goals = [];
  List<NoteModel> _notes = [];
  List<PunishmentLines> _punishments = [];
  List<ImmunityLines> _immunities = [];
  List<TribunalCase> _tribunalCases = [];
  List<BadgeModel> _customBadges = [];

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

  String? get familyCode => _familyCode;
  String? get familyId => _familyCode;
  bool get isSyncEnabled => _familyCode != null && _familyCode!.isNotEmpty;

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

    _loadLocal();

    _familyCode = _metaBox.get('familyCode');
    if (_familyCode != null && _familyCode!.isNotEmpty) {
      try {
        await _firestore.init(_familyCode!);
        _setupFirestoreListeners();
      } catch (e) {
        if (kDebugMode) debugPrint('Firestore init error: $e');
      }
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
  }

  void _setupFirestoreListeners() {
    _firestore.listenToChildren((list) {
      _children = list;
      _saveBox(_childrenBox, _children, (e) => e.id, (e) => e.toMap());
      notifyListeners();
    });
    _firestore.listenToHistory((list) {
      _history = list;
      _history.sort((a, b) => b.date.compareTo(a.date));
      _saveBox(_historyBox, _history, (e) => e.id, (e) => e.toMap());
      notifyListeners();
    });
  }

  void _saveBox<T>(Box box, List<T> items, String Function(T) getId, Map<String, dynamic> Function(T) toMap) {
    box.clear();
    for (final item in items) {
      box.put(getId(item), jsonEncode(toMap(item)));
    }
  }

  Future<void> reconnectFirestore() async {
    if (_familyCode != null && _familyCode!.isNotEmpty) {
      try {
        await _firestore.init(_familyCode!);
        _setupFirestoreListeners();
        if (kDebugMode) debugPrint('Firestore reconnected');
      } catch (e) {
        if (kDebugMode) debugPrint('Firestore reconnect error: $e');
      }
    }
  }

  // ══════════════════════════════════════
  //  FAMILY (create / join / disconnect)
  // ══════════════════════════════════════
  Future<String> createFamily({String? customCode}) async {
    final code = await _firestore.createFamily(customCode: customCode);
    _familyCode = code;
    await _metaBox.put('familyCode', code);
    await _firestore.init(code);
    _setupFirestoreListeners();
    // Upload existing local data
    for (final c in _children) {
      await _firestore.saveChild(c);
    }
    for (final h in _history) {
      await _firestore.saveHistory(h);
    }
    notifyListeners();
    return code;
  }

  Future<bool> joinFamily(String code) async {
    final ok = await _firestore.joinFamily(code);
    if (ok) {
      _familyCode = code;
      await _metaBox.put('familyCode', code);
      await _firestore.init(code);
      _setupFirestoreListeners();
      notifyListeners();
    }
    return ok;
  }

  Future<void> disconnectFamily() async {
    _familyCode = null;
    await _metaBox.delete('familyCode');
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

  Future<void> addChild(ChildModel child) async {
    _children.add(child);
    await _childrenBox.put(child.id, jsonEncode(child.toMap()));
    if (isSyncEnabled) await _firestore.saveChild(child);
    notifyListeners();
  }

  Future<void> updateChild(ChildModel child) async {
    final idx = _children.indexWhere((c) => c.id == child.id);
    if (idx != -1) {
      _children[idx] = child;
      await _childrenBox.put(child.id, jsonEncode(child.toMap()));
      if (isSyncEnabled) await _firestore.saveChild(child);
      notifyListeners();
    }
  }

  Future<void> updateChildPhoto(String childId, String base64Photo) async {
    final child = getChild(childId);
    if (child != null) {
      child.photoBase64 = base64Photo;
      await _childrenBox.put(child.id, jsonEncode(child.toMap()));
      if (isSyncEnabled) await _firestore.saveChild(child);
      notifyListeners();
    }
  }

  Future<void> removeChild(String id) async {
    _children.removeWhere((c) => c.id == id);
    await _childrenBox.delete(id);
    // Also remove related data
    _history.removeWhere((h) => h.childId == id);
    _goals.removeWhere((g) => g.childId == id);
    _notes.removeWhere((n) => n.childId == id);
    _punishments.removeWhere((p) => p.childId == id);
    _immunities.removeWhere((im) => im.childId == id);
    await _saveAllLocal();
    if (isSyncEnabled) await _firestore.deleteChild(id);
    notifyListeners();
  }

  // ══════════════════════════════════════
  //  POINTS
  // ══════════════════════════════════════
  Future<void> addPoints(String childId, int points, String reason, String category, {bool isBonus = true, String? proofPhoto}) async {
    final child = getChild(childId);
    if (child == null) return;

    if (isBonus) {
      child.points += points;
    } else {
      child.points -= points;
    }
    await _childrenBox.put(child.id, jsonEncode(child.toMap()));
    if (isSyncEnabled) await _firestore.saveChild(child);

    final entry = HistoryEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      childId: childId,
      points: points,
      reason: reason,
      category: category,
      isBonus: isBonus,
      proofPhotoBase64: proofPhoto,
    );
    _history.insert(0, entry);
    await _historyBox.put(entry.id, jsonEncode(entry.toMap()));
    if (isSyncEnabled) await _firestore.saveHistory(entry);

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
    if (isSyncEnabled) _firestore.saveChild(child);
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
    notifyListeners();
  }

  Future<void> toggleGoal(String goalId) async {
    final goal = _goals.firstWhere((g) => g.id == goalId, orElse: () => GoalModel(id: '', childId: '', title: '', targetPoints: 0));
    if (goal.id.isEmpty) return;
    goal.completed = !goal.completed;
    await _goalsBox.put(goal.id, jsonEncode(goal.toMap()));
    notifyListeners();
  }

  Future<void> removeGoal(String goalId) async {
    _goals.removeWhere((g) => g.id == goalId);
    await _goalsBox.delete(goalId);
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
    notifyListeners();
  }

  Future<void> updateNote(String noteId, String newText) async {
    final note = _notes.firstWhere((n) => n.id == noteId, orElse: () => NoteModel(id: '', childId: '', text: ''));
    if (note.id.isEmpty) return;
    note.text = newText;
    await _notesBox.put(note.id, jsonEncode(note.toMap()));
    notifyListeners();
  }

  Future<void> deleteNote(String noteId) async {
    _notes.removeWhere((n) => n.id == noteId);
    await _notesBox.delete(noteId);
    notifyListeners();
  }

  Future<void> toggleNotePin(String noteId) async {
    final note = _notes.firstWhere((n) => n.id == noteId, orElse: () => NoteModel(id: '', childId: '', text: ''));
    if (note.id.isEmpty) return;
    note.isPinned = !note.isPinned;
    await _notesBox.put(note.id, jsonEncode(note.toMap()));
    notifyListeners();
  }

  // ══════════════════════════════════════
  //  PUNISHMENT LINES
  // ══════════════════════════════════════
  Future<void> addPunishment(PunishmentLines p) async {
    _punishments.add(p);
    await _punishmentsBox.put(p.id, jsonEncode(p.toMap()));
    notifyListeners();
  }

  Future<void> removePunishment(String id) async {
    _punishments.removeWhere((p) => p.id == id);
    await _punishmentsBox.delete(id);
    notifyListeners();
  }

  Future<void> updatePunishmentProgress(String id, int linesToAdd) async {
    final p = _punishments.firstWhere((p) => p.id == id, orElse: () => PunishmentLines(id: '', childId: '', text: '', totalLines: 0));
    if (p.id.isEmpty) return;
    p.completedLines = (p.completedLines + linesToAdd).clamp(0, p.totalLines);
    await _punishmentsBox.put(p.id, jsonEncode(p.toMap()));
    notifyListeners();
  }

  Future<void> addPhotoToPunishment(String id, String base64Photo) async {
    final p = _punishments.firstWhere((p) => p.id == id, orElse: () => PunishmentLines(id: '', childId: '', text: '', totalLines: 0));
    if (p.id.isEmpty) return;
    p.photoUrls.add(base64Photo);
    await _punishmentsBox.put(p.id, jsonEncode(p.toMap()));
    notifyListeners();
  }

  Future<void> removePhotoFromPunishment(String id, int index) async {
    final p = _punishments.firstWhere((p) => p.id == id, orElse: () => PunishmentLines(id: '', childId: '', text: '', totalLines: 0));
    if (p.id.isEmpty) return;
    if (index >= 0 && index < p.photoUrls.length) {
      p.photoUrls.removeAt(index);
      await _punishmentsBox.put(p.id, jsonEncode(p.toMap()));
      notifyListeners();
    }
  }

  // ══════════════════════════════════════
  //  IMMUNITY LINES
  // ══════════════════════════════════════
  Future<void> addImmunity(ImmunityLines im) async {
    _immunities.add(im);
    await _immunitiesBox.put(im.id, jsonEncode(im.toMap()));
    notifyListeners();
  }

  Future<void> removeImmunity(String id) async {
    _immunities.removeWhere((im) => im.id == id);
    await _immunitiesBox.delete(id);
    notifyListeners();
  }

  int getTotalAvailableImmunity(String childId) {
    return _immunities
        .where((im) => im.childId == childId && im.isUsable)
        .fold<int>(0, (sum, im) => sum + im.availableLines);
  }

  List<ImmunityLines> getUsableImmunitiesForChild(String childId) {
    return _immunities.where((im) => im.childId == childId && im.isUsable).toList();
  }

  List<ImmunityLines> getImmunitiesForChild(String childId) {
    return _immunities.where((im) => im.childId == childId).toList();
  }

  Future<void> useImmunityOnPunishment(String immunityId, String punishmentId, int lines) async {
    final im = _immunities.firstWhere((i) => i.id == immunityId, orElse: () => ImmunityLines(id: '', childId: '', reason: '', lines: 0));
    if (im.id.isEmpty) return;
    final p = _punishments.firstWhere((p) => p.id == punishmentId, orElse: () => PunishmentLines(id: '', childId: '', text: '', totalLines: 0));
    if (p.id.isEmpty) return;

    final actualLines = lines.clamp(0, im.availableLines).clamp(0, p.totalLines - p.completedLines);
    im.usedLines += actualLines;
    p.completedLines = (p.completedLines + actualLines).clamp(0, p.totalLines);

    await _immunitiesBox.put(im.id, jsonEncode(im.toMap()));
    await _punishmentsBox.put(p.id, jsonEncode(p.toMap()));
    notifyListeners();
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

  Future<void> addCustomBadge(BadgeModel badge) async {
    badge.isCustom = true;
    _customBadges.add(badge);
    await _badgesBox.put(badge.id, jsonEncode(badge.toMap()));
    notifyListeners();
  }

  Future<void> removeCustomBadge(String id) async {
    _customBadges.removeWhere((b) => b.id == id);
    await _badgesBox.delete(id);
    // Remove badge from children who had it
    for (final child in _children) {
      child.badgeIds.remove(id);
      await _childrenBox.put(child.id, jsonEncode(child.toMap()));
    }
    notifyListeners();
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

  Future<void> startTribunalHearing(String caseId) async {
    final tc = _tribunalCases.firstWhere((c) => c.id == caseId, orElse: () => TribunalCase(id: '', title: '', description: '', plaintiffId: '', accusedId: ''));
    if (tc.id.isEmpty) return;
    tc.status = TribunalStatus.inProgress;
    await _tribunalBox.put(tc.id, jsonEncode(tc.toMap()));
    notifyListeners();
  }

  // ══════════════════════════════════════
  //  HISTORY QUERIES
  // ══════════════════════════════════════
  List<HistoryEntry> getHistoryForChild(String childId) =>
      _history.where((h) => h.childId == childId).toList();

  List<HistoryEntry> getHistoryForDate(DateTime date) {
    return _history.where((h) =>
        h.date.year == date.year &&
        h.date.month == date.month &&
        h.date.day == date.day).toList();
  }

  List<HistoryEntry> getWeeklyPoints(String childId) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final start = DateTime(weekStart.year, weekStart.month, weekStart.day);
    return _history
        .where((h) => h.childId == childId && h.date.isAfter(start))
        .toList();
  }

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

  Map<String, int> getCategoryStats(String childId) {
    final entries = getHistoryForChild(childId);
    final Map<String, int> stats = {};
    for (final e in entries) {
      stats[e.category] = (stats[e.category] ?? 0) + (e.isBonus ? e.points : -e.points);
    }
    return stats;
  }

  // ══════════════════════════════════════
  //  SCHOOL NOTES (from history)
  // ══════════════════════════════════════
  List<HistoryEntry> getSchoolNotes(String childId) {
    return _history
        .where((h) => h.childId == childId && h.category == 'school_note')
        .toList();
  }

  double getSchoolAverage(String childId) {
    final notes = getSchoolNotes(childId);
    if (notes.isEmpty) return 0;
    final total = notes.fold<int>(0, (s, n) => s + n.points);
    return total / notes.length;
  }

  // ══════════════════════════════════════
  //  RESET / CLEAR
  // ══════════════════════════════════════
  Future<void> resetAllScores() async {
    for (var child in _children) {
      child.points = 0;
      child.badgeIds.clear();
      await _childrenBox.put(child.id, jsonEncode(child.toMap()));
      if (isSyncEnabled) await _firestore.saveChild(child);
    }
    notifyListeners();
  }

  Future<void> clearHistory() async {
    _history.clear();
    await _historyBox.clear();
    notifyListeners();
  }

  // ══════════════════════════════════════
  //  SAVE ALL LOCAL
  // ══════════════════════════════════════
  Future<void> _saveAllLocal() async {
    await _childrenBox.clear();
    for (final c in _children) {
      await _childrenBox.put(c.id, jsonEncode(c.toMap()));
    }
    await _historyBox.clear();
    for (final h in _history) {
      await _historyBox.put(h.id, jsonEncode(h.toMap()));
    }
    await _goalsBox.clear();
    for (final g in _goals) {
      await _goalsBox.put(g.id, jsonEncode(g.toMap()));
    }
    await _notesBox.clear();
    for (final n in _notes) {
      await _notesBox.put(n.id, jsonEncode(n.toMap()));
    }
    await _punishmentsBox.clear();
    for (final p in _punishments) {
      await _punishmentsBox.put(p.id, jsonEncode(p.toMap()));
    }
    await _immunitiesBox.clear();
    for (final im in _immunities) {
      await _immunitiesBox.put(im.id, jsonEncode(im.toMap()));
    }
    await _tribunalBox.clear();
    for (final tc in _tribunalCases) {
      await _tribunalBox.put(tc.id, jsonEncode(tc.toMap()));
    }
    await _badgesBox.clear();
    for (final b in _customBadges) {
      await _badgesBox.put(b.id, jsonEncode(b.toMap()));
    }
  }
}
