// lib/providers/family_provider.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
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
  static const _uuid = Uuid();

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

  List<ChildModel>      _children      = [];
  List<HistoryEntry>    _history       = [];
  List<GoalModel>       _goals         = [];
  List<NoteModel>       _notes         = [];
  List<PunishmentLines> _punishments   = [];
  List<ImmunityLines>   _immunities    = [];
  List<TribunalCase>    _tribunalCases = [];
  List<BadgeModel>      _customBadges  = [];
  List<TradeModel>      _trades        = [];

  final Set<String> _deletedEntryIds = {};

  String? _familyCode;
  String _currentParentName = 'Parent';

  String                get currentParentName => _currentParentName;
  List<ChildModel>      get children          => _children;
  List<HistoryEntry>    get history           => _history;
  List<GoalModel>       get goals             => _goals;
  List<NoteModel>       get notes             => _notes;
  List<PunishmentLines> get punishments       => _punishments;
  List<ImmunityLines>   get immunities        => _immunities;
  List<TribunalCase>    get tribunalCases     => _tribunalCases;
  List<BadgeModel>      get customBadges      => _customBadges;
  List<TradeModel>      get trades            => _trades;
  String?               get familyCode        => _familyCode;
  String?               get familyId          => _familyCode;
  bool                  get isSyncEnabled     => _firestore.isConnected;

  List<ChildModel> get childrenSorted {
    final sorted = List<ChildModel>.from(_children);
    sorted.sort((a, b) => b.points.compareTo(a.points));
    return sorted;
  }

  List<TribunalCase> get activeTribunalCases =>
      _tribunalCases.where((c) => c.status != TribunalStatus.closed).toList();
  List<TribunalCase> get closedTribunalCases =>
      _tribunalCases.where((c) => c.status == TribunalStatus.closed).toList();

  // ─────────────────────────────────────────────────────────
  Future<void> init() async {
    _childrenBox    = await Hive.openBox('children');
    _historyBox     = await Hive.openBox('history');
    _goalsBox       = await Hive.openBox('goals');
    _notesBox       = await Hive.openBox('notes');
    _punishmentsBox = await Hive.openBox('punishments');
    _immunitiesBox  = await Hive.openBox('immunities');
    _tribunalBox    = await Hive.openBox('tribunal');
    _badgesBox      = await Hive.openBox('custom_badges');
    _metaBox        = await Hive.openBox('meta');
    _screenTimeBox  = await Hive.openBox('screen_time');
    _tradesBox      = await Hive.openBox('trades');
    _loadLocal();
    try {
      await _firestore.init();
      _familyCode = await _firestore.getFamilyCode();
      if (_firestore.isConnected) { _setupFirestoreCallbacks(); }
    } catch (e) {
      if (kDebugMode) debugPrint('Firestore init error: $e');
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _firestore.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────
  void _loadLocal() {
    _children = _childrenBox.values
        .map((v) => ChildModel.fromMap(Map<String, dynamic>.from(jsonDecode(v as String))))
        .toList();
    _history = _historyBox.values
        .map((v) => HistoryEntry.fromMap(Map<String, dynamic>.from(jsonDecode(v as String))))
        .where((h) => !_deletedEntryIds.contains(h.id))
        .toList();
    _history.sort((a, b) => b.date.compareTo(a.date));
    _goals = _goalsBox.values
        .map((v) => GoalModel.fromMap(Map<String, dynamic>.from(jsonDecode(v as String))))
        .toList();
    _notes = _notesBox.values
        .map((v) => NoteModel.fromMap(Map<String, dynamic>.from(jsonDecode(v as String))))
        .toList();
    _punishments = _punishmentsBox.values
        .map((v) => PunishmentLines.fromMap(Map<String, dynamic>.from(jsonDecode(v as String))))
        .toList();
    _immunities = _immunitiesBox.values
        .map((v) => ImmunityLines.fromMap(Map<String, dynamic>.from(jsonDecode(v as String))))
        .toList();
    _tribunalCases = _tribunalBox.values
        .map((v) => TribunalCase.fromMap(Map<String, dynamic>.from(jsonDecode(v as String))))
        .toList();
    _customBadges = _badgesBox.values
        .map((v) => BadgeModel.fromMap(Map<String, dynamic>.from(jsonDecode(v as String))))
        .toList();
    _trades = _tradesBox.values
        .map((v) => TradeModel.fromMap(Map<String, dynamic>.from(jsonDecode(v as String))))
        .toList();
    _currentParentName = _metaBox.get('current_parent', defaultValue: 'Parent') as String;
  }

  // ─────────────────────────────────────────────────────────
  void _setupFirestoreCallbacks() {
    _firestore.onChildrenChanged = (list, _) {
      _children = list;
      _saveBoxFromList(_childrenBox, _children, (e) => e.id, (e) => e.toMap());
      notifyListeners();
    };
    _firestore.onHistoryChanged = (list, _) {
      _history = list.where((h) => !_deletedEntryIds.contains(h.id)).toList();
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
    _firestore.onImmunitiesChanged = (list) {
      _immunities = list;
      _saveBoxFromList(_immunitiesBox, _immunities, (e) => e.id, (e) => e.toMap());
      notifyListeners();
    };
    _firestore.onTradesChanged = (list) {
      _trades = list;
      _saveBoxFromList(_tradesBox, _trades, (e) => e.id, (e) => e.toMap());
      notifyListeners();
    };
    _firestore.onTribunalChanged = (list) {
      _tribunalCases = list;
      _saveBoxFromList(_tribunalBox, _tribunalCases, (e) => e.id, (e) => e.toMap());
      notifyListeners();
    };
    _firestore.onBadgesChanged = (list) {
      _customBadges = list;
      _saveBoxFromList(_badgesBox, _customBadges, (e) => e.id, (e) => e.toMap());
      notifyListeners();
    };
    _firestore.onScreenTimeChanged = (data) {
      _screenTimeBox.clear();
      for (final entry in data.entries) {
        _screenTimeBox.put(entry.key, entry.value);
      }
      notifyListeners();
    };
  }

  // ─────────────────────────────────────────────────────────
  void _saveBoxFromList<T>(
    Box box,
    List<T> items,
    String Function(T) getId,
    Map<String, dynamic> Function(T) toMap,
  ) {
    box.clear();
    for (final item in items) {
      box.put(getId(item), jsonEncode(toMap(item)));
    }
  }

  Future<void> _saveAllLocal() async {
    _saveBoxFromList(_childrenBox,    _children,      (e) => e.id, (e) => e.toMap());
    _saveBoxFromList(_historyBox,     _history,       (e) => e.id, (e) => e.toMap());
    _saveBoxFromList(_goalsBox,       _goals,         (e) => e.id, (e) => e.toMap());
    _saveBoxFromList(_notesBox,       _notes,         (e) => e.id, (e) => e.toMap());
    _saveBoxFromList(_punishmentsBox, _punishments,   (e) => e.id, (e) => e.toMap());
    _saveBoxFromList(_immunitiesBox,  _immunities,    (e) => e.id, (e) => e.toMap());
    _saveBoxFromList(_tradesBox,      _trades,        (e) => e.id, (e) => e.toMap());
  }

  // ─────────────────────────────────────────────────────────
  Future<void> reconnectFirestore() async {
    if (_firestore.isConnected) {
      _firestore.reconnect();
      _setupFirestoreCallbacks();
    }
  }

  void setCurrentParent(String name) {
    _currentParentName = name;
    _metaBox.put('current_parent', name);
    notifyListeners();
  }

  Future<String> createFamily({String? customCode}) async {
    final code = await _firestore.createFamily(customCode: customCode);
    _familyCode = code;
    _setupFirestoreCallbacks();
    await _firestore.uploadAllData(
      children:       _children,
      history:        _history,
      goals:          _goals,
      punishments:    _punishments,
      notes:          _notes,
      immunities:     _immunities,
      trades:         _trades,
      tribunalCases:  _tribunalCases,
      customBadges:   _customBadges,
      screenTimeData: _getAllScreenTimeData(),
    );
    notifyListeners();
    return code;
  }

  Future<bool> joinFamily(String code) async {
    final ok = await _firestore.joinFamily(code);
    if (ok) { _familyCode = code; _setupFirestoreCallbacks(); notifyListeners(); }
    return ok;
  }

  Future<void> disconnectFamily() async {
    await _firestore.disconnectFamily();
    _familyCode = null;
    notifyListeners();
  }

  String getFamilyCode() => _familyCode ?? '';

  Future<void> changeFamilyCode(String newCode) async {
    if (!_firestore.isConnected) {
      throw Exception('Vous devez être connecté pour changer le code.');
    }
    await _firestore.changeFamilyCode(newCode);
    _familyCode = newCode;
    notifyListeners();
  }

  Map<String, dynamic> _getAllScreenTimeData() {
    final Map<String, dynamic> data = {};
    for (final key in _screenTimeBox.keys) {
      data[key.toString()] = _screenTimeBox.get(key);
    }
    return data;
  }

  // ─── Enfants ───────────────────────────────────────────────
  ChildModel? getChild(String id) {
    try { return _children.firstWhere((c) => c.id == id); } catch (_) { return null; }
  }

  List<HistoryEntry> getHistoryForChild(String childId) =>
      _history.where((h) => h.childId == childId).toList();

  // ✅ CORRIGÉ : suppression de l'appel Firestore inexistant
  Future<void> deleteHistoryEntry(String entryId) async {
    _deletedEntryIds.add(entryId);
    _history.removeWhere((h) => h.id == entryId);
    await _historyBox.delete(entryId);
    notifyListeners();
  }

  Future<void> addChild(String name, String avatar) async {
    final child = ChildModel(
      id:     _uuid.v4(),
      name:   name,
      avatar: avatar,
    );
    _children.add(child);
    await _childrenBox.put(child.id, jsonEncode(child.toMap()));
    if (_firestore.isConnected) await _firestore.saveChild(child);
    notifyListeners();
  }

  Future<void> updateChild(String id, String name, String avatar) async {
    final child = getChild(id); if (child == null) return;
    child.name   = name;
    child.avatar = avatar;
    await _childrenBox.put(child.id, jsonEncode(child.toMap()));
    if (_firestore.isConnected) await _firestore.saveChild(child);
    notifyListeners();
  }

  Future<void> updateChildPhoto(String childId, String base64Photo) async {
    final child = getChild(childId); if (child == null) return;
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
    final keysToRemove = _screenTimeBox.keys
        .where((k) => k.toString().startsWith(id))
        .toList();
    for (final key in keysToRemove) { await _screenTimeBox.delete(key); }
    await _saveAllLocal();
    if (_firestore.isConnected) await _firestore.deleteChild(id);
    notifyListeners();
  }

  // ─── Points & Historique ───────────────────────────────────
  Future<void> addPoints(
    String childId,
    int points,
    String reason, {
    String category       = 'Bonus',
    bool isBonus          = true,
    String? proofPhoto,
    String? proofPhotoBase64,
    DateTime? date,
  }) async {
    final child = getChild(childId); if (child == null) return;
    if (isBonus) {
      child.points += points;
    } else {
      child.points -= points;
    }
    child.level = child.currentLevelNumber;
    await _childrenBox.put(child.id, jsonEncode(child.toMap()));
    if (_firestore.isConnected) await _firestore.saveChild(child);
    final entry = HistoryEntry(
      id:               _uuid.v4(),
      childId:          childId,
      points:           points,
      reason:           reason,
      category:         category,
      isBonus:          isBonus,
      proofPhotoBase64: proofPhoto ?? proofPhotoBase64,
      date:             date,
      actionBy:         _currentParentName,
    );
    _history.insert(0, entry);
    await _historyBox.put(entry.id, jsonEncode(entry.toMap()));
    if (_firestore.isConnected) await _firestore.saveHistoryEntry(entry);
    await _checkBadgeUnlock(child);
    notifyListeners();
  }

  Future<void> _checkBadgeUnlock(ChildModel child) async {
    final allBadges = [...BadgeModel.defaultBadges, ..._customBadges];
    bool changed = false;
    for (final badge in allBadges) {
      if (child.points >= badge.requiredPoints && !child.badgeIds.contains(badge.id)) {
        child.badgeIds.add(badge.id);
        changed = true;
      }
    }
    if (changed) {
      await _childrenBox.put(child.id, jsonEncode(child.toMap()));
      if (_firestore.isConnected) await _firestore.saveChild(child);
    }
  }

  // ─── Objectifs ─────────────────────────────────────────────
  List<GoalModel> getGoalsForChild(String childId) =>
      _goals.where((g) => g.childId == childId).toList();

  Future<void> addGoal(String childId, String title, int targetPoints) async {
    final goal = GoalModel(
      id:           _uuid.v4(),
      childId:      childId,
      title:        title,
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

  // ─── Notes texte ───────────────────────────────────────────
  List<NoteModel> getNotesForChild(String childId) =>
      _notes.where((n) => n.childId == childId).toList();

  Future<void> addNote(
    String childId,
    String text, {
    String authorName = 'Parent',
  }) async {
    final note = NoteModel(
      id:         _uuid.v4(),
      childId:    childId,
      text:       text,
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

  // ─── Punitions ─────────────────────────────────────────────
  double _calculerDeductionPunition(int totalLignes) {
    if (totalLignes <= 10)  return 0.80;
    if (totalLignes <= 20)  return 1.20;
    if (totalLignes <= 50)  return 1.80;
    if (totalLignes <= 100) return 2.50;
    if (totalLignes <= 200) return 3.50;
    return 5.00;
  }

  Future<void> addPunishment(String childId, String text, int totalLines) async {
    final p = PunishmentLines(
      id:         _uuid.v4(),
      childId:    childId,
      text:       text,
      totalLines: totalLines,
    );
    _punishments.add(p);
    await _punishmentsBox.put(p.id, jsonEncode(p.toMap()));
    if (_firestore.isConnected) await _firestore.savePunishment(p);
    final deduction = _calculerDeductionPunition(totalLines);
    final entry = HistoryEntry(
      id:       _uuid.v4(),
      childId:  childId,
      points:   (deduction * 100).round(),
      reason:   'Déduction automatique : $totalLines lignes ($deduction pt comportement)',
      category: 'punition',
      isBonus:  false,
      actionBy: _currentParentName,
      date:     DateTime.now(),
    );
    _history.insert(0, entry);
    await _historyBox.put(entry.id, jsonEncode(entry.toMap()));
    if (_firestore.isConnected) await _firestore.saveHistoryEntry(entry);
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

  // ─── Immunités ─────────────────────────────────────────────
  Future<void> addImmunity(
    String childId,
    String reason,
    int lines, {
    DateTime? expiresAt,
  }) async {
    final im = ImmunityLines(
      id:        _uuid.v4(),
      childId:   childId,
      reason:    reason,
      lines:     lines,
      expiresAt: expiresAt,
    );
    _immunities.add(im);
    await _immunitiesBox.put(im.id, jsonEncode(im.toMap()));
    if (_firestore.isConnected) await _firestore.saveImmunity(im);
    notifyListeners();
  }

  Future<void> removeImmunity(String id) async {
    _immunities.removeWhere((im) => im.id == id);
    await _immunitiesBox.delete(id);
    if (_firestore.isConnected) await _firestore.deleteImmunity(id);
    notifyListeners();
  }

  int getTotalAvailableImmunity(String childId) =>
      _immunities
          .where((im) => im.childId == childId && im.isUsable)
          .fold<int>(0, (s, im) => s + im.availableLines);

  List<ImmunityLines> getUsableImmunitiesForChild(String childId) =>
      _immunities.where((im) => im.childId == childId && im.isUsable).toList();

  List<ImmunityLines> getImmunitiesForChild(String childId) =>
      _immunities.where((im) => im.childId == childId).toList();

  Future<void> useImmunityOnPunishment(
    String immunityId,
    String punishmentId,
    int lines,
  ) async {
    try {
      final im = _immunities.firstWhere((i) => i.id == immunityId);
      final p  = _punishments.firstWhere((p) => p.id == punishmentId);
      final actualLines = lines
          .clamp(0, im.availableLines)
          .clamp(0, p.totalLines - p.completedLines);
      im.usedLines     += actualLines;
      p.completedLines  = (p.completedLines + actualLines).clamp(0, p.totalLines);
      await _immunitiesBox.put(im.id, jsonEncode(im.toMap()));
      await _punishmentsBox.put(p.id, jsonEncode(p.toMap()));
      if (_firestore.isConnected) {
        await _firestore.saveImmunity(im);
        await _firestore.savePunishment(p);
      }
      notifyListeners();
    } catch (_) {}
  }

  // ─── Badges ────────────────────────────────────────────────
  List<BadgeModel> getBadgesForChild(String childId) {
    final child = getChild(childId); if (child == null) return [];
    final allBadges = [...BadgeModel.defaultBadges, ..._customBadges];
    return allBadges.where((b) => child.badgeIds.contains(b.id)).toList();
  }

  Future<void> addCustomBadge(
    String name,
    String icon,
    String description,
    int requiredPoints, {
    String powerType = 'custom',
  }) async {
    final badge = BadgeModel(
      id:             'custom_${_uuid.v4()}',
      name:           name,
      icon:           icon,
      description:    description,
      requiredPoints: requiredPoints,
      powerType:      powerType,
      isCustom:       true,
    );
    _customBadges.add(badge);
    await _badgesBox.put(badge.id, jsonEncode(badge.toMap()));
    if (_firestore.isConnected) await _firestore.saveCustomBadge(badge);
    notifyListeners();
  }

  Future<void> removeCustomBadge(String id) async {
    _customBadges.removeWhere((b) => b.id == id);
    await _badgesBox.delete(id);
    for (final child in _children) {
      if (child.badgeIds.remove(id)) {
        await _childrenBox.put(child.id, jsonEncode(child.toMap()));
      }
    }
    if (_firestore.isConnected) await _firestore.deleteCustomBadge(id);
    notifyListeners();
  }

  // ─── Temps écran ───────────────────────────────────────────
  String _screenTimeKey(String childId, String key) {
    final now       = DateTime.now().toUtc();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    return '${childId}_${weekStart.year}_${weekStart.month}_${weekStart.day}_$key';
  }

  double getWeeklySchoolAverage(String childId) {
    final notes = _getWeekSchoolNotes(childId);
    if (notes.isEmpty) return -1;
    return notes.fold<int>(0, (s, n) => s + n.points) / notes.length;
  }

  double getWeeklyBehaviorScore(String childId) {
    final weekEntries = _getWeekHistory(childId).where((h) =>
        h.category != 'school_note' &&
        h.category != 'screen_time_bonus' &&
        h.category != 'saturday_rating').toList();
    if (weekEntries.isEmpty) return 10.0;
    final bonusCount   = weekEntries.where((h) => h.isBonus).length;
    final penaltyCount = weekEntries.where((h) => !h.isBonus).length;
    final total = bonusCount + penaltyCount;
    if (total == 0) return 10.0;
    return ((bonusCount / total) * 20).clamp(0.0, 20.0);
  }

  double getWeeklyGlobalScore(String childId) {
    final sa = getWeeklySchoolAverage(childId);
    final bs = getWeeklyBehaviorScore(childId);
    if (sa < 0) return bs;
    return (sa * 0.5 + bs * 0.5);
  }

  Set<DateTime> _getSelectedDates(Set<int> joursSources) {
    final now = DateTime.now();
    final debutSemaine = now.subtract(Duration(days: now.weekday - 1));
    return joursSources.map((jourIdx) {
      final d = debutSemaine.add(Duration(days: jourIdx));
      return DateTime(d.year, d.month, d.day);
    }).toSet();
  }

  double getSchoolAverageForDays(String childId, Set<int> joursSources) {
    if (joursSources.isEmpty) return -1;
    final datesCochees = _getSelectedDates(joursSources);
    final notes = _history.where((h) {
      if (h.childId != childId) return false;
      if (h.category != 'school_note') return false;
      final entryDay = DateTime(h.date.year, h.date.month, h.date.day);
      return datesCochees.contains(entryDay);
    }).toList();
    if (notes.isEmpty) return -1;
    return notes.fold<int>(0, (s, n) => s + n.points) / notes.length;
  }

  double getBehaviorScoreForDays(String childId, Set<int> joursSources) {
    if (joursSources.isEmpty) return 10.0;
    final datesCochees = _getSelectedDates(joursSources);
    final entries = _history.where((h) {
      if (h.childId != childId) return false;
      if (h.category == 'school_note'      ||
          h.category == 'screen_time_bonus' ||
          h.category == 'saturday_rating'   ||
          h.category == 'tribunal_vote'     ||
          h.category == 'tribunal_verdict') return false;
      final entryDay = DateTime(h.date.year, h.date.month, h.date.day);
      return datesCochees.contains(entryDay);
    }).toList();
    if (entries.isEmpty) return 10.0;
    final bonusCount   = entries.where((h) => h.isBonus).length;
    final penaltyCount = entries.where((h) => !h.isBonus).length;
    final total = bonusCount + penaltyCount;
    if (total == 0) return 10.0;
    return ((bonusCount / total) * 20).clamp(0.0, 20.0);
  }

  double getGlobalScoreForDays(String childId, Set<int> joursSources) {
    final sa = getSchoolAverageForDays(childId, joursSources);
    final bs = getBehaviorScoreForDays(childId, joursSources);
    if (sa < 0) return bs;
    return (sa * 0.5 + bs * 0.5);
  }

  int _minutesFromGlobalScore(double score) {
    if (score >= 18) return 180;
    if (score >= 16) return 150;
    if (score >= 14) return 120;
    if (score >= 12) return 90;
    if (score >= 10) return 60;
    if (score >= 8)  return 30;
    return 0;
  }

  int getSaturdayMinutes(String childId) =>
      (_minutesFromGlobalScore(getWeeklyGlobalScore(childId)) +
       getParentBonusMinutes(childId)).clamp(0, 480);

  int getSundayMinutes(String childId) {
    final sr = getSaturdayBehaviorRating(childId);
    if (sr < 0) return getSaturdayMinutes(childId);
    return (_minutesFromGlobalScore(sr) + getParentBonusMinutes(childId)).clamp(0, 480);
  }

  int getParentBonusMinutes(String childId) =>
      _screenTimeBox.get(_screenTimeKey(childId, 'bonus'), defaultValue: 0) as int;

  double getSaturdayBehaviorRating(String childId) =>
      (_screenTimeBox.get(_screenTimeKey(childId, 'sat_rating'), defaultValue: -1.0) as num)
          .toDouble();

  Future<void> addScreenTimeBonus(String childId, int minutes, String reason) async {
    final key     = _screenTimeKey(childId, 'bonus');
    final current = _screenTimeBox.get(key, defaultValue: 0) as int;
    await _screenTimeBox.put(key, current + minutes);
    if (_firestore.isConnected) {
      await _firestore.saveScreenTimeValue(key, current + minutes);
    }
    final entry = HistoryEntry(
      id:       _uuid.v4(),
      childId:  childId,
      points:   minutes.abs(),
      reason:   '⏱ $reason (${minutes > 0 ? '+' : ''}${minutes}min)',
      category: 'screen_time_bonus',
      isBonus:  minutes > 0,
      actionBy: _currentParentName,
    );
    _history.insert(0, entry);
    await _historyBox.put(entry.id, jsonEncode(entry.toMap()));
    if (_firestore.isConnected) await _firestore.saveHistoryEntry(entry);
    notifyListeners();
  }

  Future<void> resetScreenTimeBonus(String childId) async {
    final key = _screenTimeKey(childId, 'bonus');
    await _screenTimeBox.put(key, 0);
    if (_firestore.isConnected) await _firestore.saveScreenTimeValue(key, 0);
    notifyListeners();
  }

  Future<void> rateSaturdayBehavior(String childId, int rating) async {
    final key = _screenTimeKey(childId, 'sat_rating');
    await _screenTimeBox.put(key, rating.toDouble());
    if (_firestore.isConnected) {
      await _firestore.saveScreenTimeValue(key, rating.toDouble());
    }
    final entry = HistoryEntry(
      id:       _uuid.v4(),
      childId:  childId,
      points:   rating,
      reason:   '⭐ Note samedi: $rating/20',
      category: 'saturday_rating',
      isBonus:  true,
      actionBy: _currentParentName,
    );
    _history.insert(0, entry);
    await _historyBox.put(entry.id, jsonEncode(entry.toMap()));
    if (_firestore.isConnected) await _firestore.saveHistoryEntry(entry);
    notifyListeners();
  }

  List<HistoryEntry> _getWeekHistory(String childId) {
    final now       = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final start     = DateTime(weekStart.year, weekStart.month, weekStart.day);
    return _history.where((h) => h.childId == childId && h.date.isAfter(start)).toList();
  }

  List<HistoryEntry> _getWeekSchoolNotes(String childId) =>
      _getWeekHistory(childId).where((h) => h.category == 'school_note').toList();

  // ─── Tribunal ──────────────────────────────────────────────
  Future<void> addTribunalCase(TribunalCase tc) async {
    _tribunalCases.add(tc);
    await _tribunalBox.put(tc.id, jsonEncode(tc.toMap()));
    if (_firestore.isConnected) await _firestore.saveTribunalCase(tc);
    notifyListeners();
  }

  Future<void> updateTribunalCase(TribunalCase tc) async {
    final idx = _tribunalCases.indexWhere((c) => c.id == tc.id);
    if (idx != -1) {
      _tribunalCases[idx] = tc;
      await _tribunalBox.put(tc.id, jsonEncode(tc.toMap()));
      if (_firestore.isConnected) await _firestore.saveTribunalCase(tc);
      notifyListeners();
    }
  }

  Future<void> removeTribunalCase(String id) async {
    _tribunalCases.removeWhere((c) => c.id == id);
    await _tribunalBox.delete(id);
    if (_firestore.isConnected) await _firestore.deleteTribunalCase(id);
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
      TribunalParticipant(childId: accusedId,   role: TribunalRole.accused),
    ];
    if (prosecutionLawyerId != null) {
      participants.add(TribunalParticipant(
          childId: prosecutionLawyerId, role: TribunalRole.prosecutionLawyer));
    }
    if (defenseLawyerId != null) {
      participants.add(TribunalParticipant(
          childId: defenseLawyerId, role: TribunalRole.defenseLawyer));
    }
    if (witnessIds != null) {
      for (final wId in witnessIds) {
        participants.add(TribunalParticipant(childId: wId, role: TribunalRole.witness));
      }
    }
    final tc = TribunalCase(
      id:           _uuid.v4(),
      title:        title,
      description:  description,
      plaintiffId:  plaintiffId,
      accusedId:    accusedId,
      participants: participants,
      status:       TribunalStatus.filed,
    );
    _tribunalCases.add(tc);
    await _tribunalBox.put(tc.id, jsonEncode(tc.toMap()));
    if (_firestore.isConnected) await _firestore.saveTribunalCase(tc);
    notifyListeners();
  }

  Future<void> scheduleTribunalHearing(String caseId, DateTime date) async {
    try {
      final tc = _tribunalCases.firstWhere((c) => c.id == caseId);
      tc.status        = TribunalStatus.scheduled;
      tc.scheduledDate = date;
      await _tribunalBox.put(tc.id, jsonEncode(tc.toMap()));
      if (_firestore.isConnected) await _firestore.saveTribunalCase(tc);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> startTribunalHearing(String caseId) async {
    try {
      final tc = _tribunalCases.firstWhere((c) => c.id == caseId);
      tc.status = TribunalStatus.inProgress;
      await _tribunalBox.put(tc.id, jsonEncode(tc.toMap()));
      if (_firestore.isConnected) await _firestore.saveTribunalCase(tc);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> startTribunalDeliberation(String caseId) async {
    try {
      final tc = _tribunalCases.firstWhere((c) => c.id == caseId);
      tc.status = TribunalStatus.deliberation;
      await _tribunalBox.put(tc.id, jsonEncode(tc.toMap()));
      if (_firestore.isConnected) await _firestore.saveTribunalCase(tc);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> dismissTribunalCase(String caseId) async {
    try {
      final tc = _tribunalCases.firstWhere((c) => c.id == caseId);
      tc.status        = TribunalStatus.closed;
      tc.verdict       = TribunalVerdict.dismissed;
      tc.verdictReason = 'Classé sans suite';
      tc.verdictDate   = DateTime.now();
      await _tribunalBox.put(tc.id, jsonEncode(tc.toMap()));
      if (_firestore.isConnected) await _firestore.saveTribunalCase(tc);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> enableTribunalVoting(String caseId) async {
    try {
      final tc = _tribunalCases.firstWhere((c) => c.id == caseId);
      tc.votingEnabled = true;
      await _tribunalBox.put(tc.id, jsonEncode(tc.toMap()));
      if (_firestore.isConnected) await _firestore.saveTribunalCase(tc);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> disableTribunalVoting(String caseId) async {
    try {
      final tc = _tribunalCases.firstWhere((c) => c.id == caseId);
      tc.votingEnabled = false;
      await _tribunalBox.put(tc.id, jsonEncode(tc.toMap()));
      if (_firestore.isConnected) await _firestore.saveTribunalCase(tc);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> castTribunalVote(String caseId, String childId, TribunalVerdict vote) async {
    try {
      final tc = _tribunalCases.firstWhere((c) => c.id == caseId);
      if (!tc.canVote(childId)) return;
      tc.votes.add(TribunalVote(childId: childId, vote: vote));
      await _tribunalBox.put(tc.id, jsonEncode(tc.toMap()));
      if (_firestore.isConnected) await _firestore.saveTribunalCase(tc);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> changeTribunalVote(String caseId, String childId, TribunalVerdict newVote) async {
    try {
      final tc = _tribunalCases.firstWhere((c) => c.id == caseId);
      if (!tc.votingEnabled || tc.isClosed) return;
      if (childId == tc.plaintiffId || childId == tc.accusedId) return;
      tc.votes.removeWhere((v) => v.childId == childId);
      tc.votes.add(TribunalVote(childId: childId, vote: newVote));
      await _tribunalBox.put(tc.id, jsonEncode(tc.toMap()));
      if (_firestore.isConnected) await _firestore.saveTribunalCase(tc);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> removeTribunalVote(String caseId, String childId) async {
    try {
      final tc = _tribunalCases.firstWhere((c) => c.id == caseId);
      if (!tc.votingEnabled || tc.isClosed) return;
      tc.votes.removeWhere((v) => v.childId == childId);
      await _tribunalBox.put(tc.id, jsonEncode(tc.toMap()));
      if (_firestore.isConnected) await _firestore.saveTribunalCase(tc);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _distributeVotePoints(TribunalCase tc) async {
    if (tc.verdict == null || tc.verdict == TribunalVerdict.dismissed) return;
    for (final vote in tc.votes) {
      final correct = vote.vote == tc.verdict;
      vote.pointsAwarded = correct ? 1 : -1;
      await addPoints(
        vote.childId, 1,
        '⚖️ Tribunal (juré): ${correct ? "bon vote ✅" : "mauvais vote ❌"}',
        category: 'tribunal_vote',
        isBonus:  correct,
      );
    }
  }

  Future<void> renderVerdict({
    required String caseId,
    required TribunalVerdict verdict,
    required String reason,
    int? plaintiffPoints,
    int? accusedPoints,
  }) async {
    try {
      final tc         = _tribunalCases.firstWhere((c) => c.id == caseId);
      tc.status        = TribunalStatus.closed;
      tc.verdict       = verdict;
      tc.verdictReason = reason;
      tc.verdictDate   = DateTime.now();
      if (accusedPoints != null && accusedPoints != 0) {
        await addPoints(tc.accusedId, accusedPoints.abs(),
          '⚖️ Verdict tribunal (accusé): $reason',
          category: 'tribunal_verdict', isBonus: accusedPoints > 0);
      }
      if (plaintiffPoints != null && plaintiffPoints != 0) {
        await addPoints(tc.plaintiffId, plaintiffPoints.abs(),
          '⚖️ Verdict tribunal (plaignant): $reason',
          category: 'tribunal_verdict', isBonus: plaintiffPoints > 0);
      }
      await _distributeVotePoints(tc);
      await _tribunalBox.put(tc.id, jsonEncode(tc.toMap()));
      if (_firestore.isConnected) await _firestore.saveTribunalCase(tc);
      notifyListeners();
    } catch (_) {}
  }

  // ─── Trades ────────────────────────────────────────────────
  List<TradeModel> getTradesForChild(String childId) =>
      _trades.where((t) => t.fromChildId == childId || t.toChildId == childId).toList();

  List<TradeModel> getPendingTradesForChild(String childId) =>
      _trades.where((t) => t.toChildId == childId && t.isPending).toList();

  Future<void> createTrade(
    String fromChildId,
    String toChildId,
    int immunityLines,
    String serviceDescription,
  ) async {
    final trade = TradeModel(
      id:                 _uuid.v4(),
      fromChildId:        fromChildId,
      toChildId:          toChildId,
      immunityLines:      immunityLines,
      serviceDescription: serviceDescription,
    );
    _trades.add(trade);
    await _tradesBox.put(trade.id, jsonEncode(trade.toMap()));
    if (_firestore.isConnected) await _firestore.saveTrade(trade);
    notifyListeners();
  }

  Future<void> acceptTrade(String tradeId) async {
    try {
      final trade = _trades.firstWhere((t) => t.id == tradeId);
      trade.status = TradeStatus.accepted;
      await _tradesBox.put(trade.id, jsonEncode(trade.toMap()));
      if (_firestore.isConnected) await _firestore.saveTrade(trade);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> rejectTrade(String tradeId) async {
    try {
      final trade = _trades.firstWhere((t) => t.id == tradeId);
      trade.status = TradeStatus.rejected;
      await _tradesBox.put(trade.id, jsonEncode(trade.toMap()));
      if (_firestore.isConnected) await _firestore.saveTrade(trade);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> cancelTrade(String tradeId) async {
    try {
      final trade = _trades.firstWhere((t) => t.id == tradeId);
      trade.status = TradeStatus.cancelled;
      await _tradesBox.put(trade.id, jsonEncode(trade.toMap()));
      if (_firestore.isConnected) await _firestore.saveTrade(trade);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> markServiceDone(String tradeId) async {
    try {
      final trade = _trades.firstWhere((t) => t.id == tradeId);
      trade.status = TradeStatus.serviceDone;
      await _tradesBox.put(trade.id, jsonEncode(trade.toMap()));
      if (_firestore.isConnected) await _firestore.saveTrade(trade);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> completeTrade(String tradeId) async {
    try {
      final trade = _trades.firstWhere((t) => t.id == tradeId);
      final seller = getChild(trade.fromChildId);
      final buyer  = getChild(trade.toChildId);
      if (seller == null || buyer == null) return;
      // Transfert des immunités du vendeur vers l'acheteur
      int remaining = trade.immunityLines;
      final sellerImmunities = getUsableImmunitiesForChild(trade.fromChildId);
      for (final im in sellerImmunities) {
        if (remaining <= 0) break;
        final toUse = remaining.clamp(0, im.availableLines);
        im.usedLines += toUse;
        remaining    -= toUse;
        await _immunitiesBox.put(im.id, jsonEncode(im.toMap()));
        if (_firestore.isConnected) await _firestore.saveImmunity(im);
      }
      // Créer une nouvelle immunité pour l'acheteur
      final newIm = ImmunityLines(
        id:      _uuid.v4(),
        childId: trade.toChildId,
        reason:  'Achat à ${seller.name} : ${trade.serviceDescription}',
        lines:   trade.immunityLines,
      );
      _immunities.add(newIm);
      await _immunitiesBox.put(newIm.id, jsonEncode(newIm.toMap()));
      if (_firestore.isConnected) await _firestore.saveImmunity(newIm);
      trade.status = TradeStatus.completed;
      await _tradesBox.put(trade.id, jsonEncode(trade.toMap()));
      if (_firestore.isConnected) await _firestore.saveTrade(trade);
      notifyListeners();
    } catch (_) {}
  }

  // ─── Réinitialisation & Nettoyage ──────────────────────────
  // ✅ AJOUTÉ : méthodes manquantes pour settings_screen.dart
  Future<void> resetAllScores() async {
    for (final child in _children) {
      child.points  = 0;
      child.level   = 1;
      child.badgeIds.clear();
      await _childrenBox.put(child.id, jsonEncode(child.toMap()));
    }
    if (_firestore.isConnected) await _firestore.resetAllScores();
    notifyListeners();
  }

  // ✅ CORRIGÉ : clearAllHistory() est le vrai nom dans FirestoreService
  Future<void> clearHistory() async {
    _history.clear();
    await _historyBox.clear();
    if (_firestore.isConnected) await _firestore.clearAllHistory();
    notifyListeners();
  }
}
