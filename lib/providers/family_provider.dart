import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../models/child_model.dart';
import '../models/note_model.dart';
import '../models/history_entry.dart';
import '../models/punishment_lines.dart';
import '../models/immunity_lines.dart';
import '../models/tribunal_model.dart';
import '../models/badge_model.dart';
import '../services/firestore_sync_service.dart';

class FamilyProvider extends ChangeNotifier {
  final _uuid = const Uuid();
  late final FirestoreSyncService _firestore;

  // ===== HIVE BOXES =====
  late Box _childrenBox;
  late Box _historyBox;
  late Box _goalsBox;
  late Box _notesBox;
  late Box _badgesBox;
  late Box _parentBonusBox;
  late Box _punishmentLinesBox;
  late Box _immunityLinesBox;
  late Box _tribunalBox;
  late Box _customBadgesBox;

  // ===== STATE =====
  List<ChildModel> _children = [];
  List<HistoryEntry> _history = [];
  List<Map<String, dynamic>> _goals = [];
  List<NoteModel> _notes = [];
  List<String> _unlockedBadges = [];
  Map<String, int> _parentBonusMinutes = {};
  List<PunishmentLines> _punishmentLines = [];
  List<ImmunityLines> _immunityLines = [];
  List<TribunalCase> _tribunalCases = [];
  List<BadgeModel> _customBadges = [];

  String? _familyCode;
  bool _isSyncEnabled = false;

  // ===== GETTERS =====
  List<ChildModel> get children => _children;
  List<HistoryEntry> get history => _history;
  List<Map<String, dynamic>> get goals => _goals;
  List<NoteModel> get notes => _notes;
  List<String> get unlockedBadges => _unlockedBadges;
  String? get familyCode => _familyCode;
  String? get familyId => _familyCode;
  List<PunishmentLines> get punishments => _punishmentLines;
  List<ImmunityLines> get immunities => _immunityLines;
  List<TribunalCase> get tribunalCases => _tribunalCases;
  List<BadgeModel> get customBadges => _customBadges;
  bool get isSyncEnabled => _isSyncEnabled;

  List<TribunalCase> get activeTribunalCases =>
      _tribunalCases.where((tc) => !tc.isClosed).toList();

  List<TribunalCase> get closedTribunalCases =>
      _tribunalCases.where((tc) => tc.isClosed).toList();

  // ===== INIT =====
  Future<void> init() async {
    _childrenBox = await Hive.openBox('children');
    _historyBox = await Hive.openBox('history');
    _goalsBox = await Hive.openBox('goals');
    _notesBox = await Hive.openBox('notes');
    _badgesBox = await Hive.openBox('badges');
    _parentBonusBox = await Hive.openBox('parentBonus');
    _punishmentLinesBox = await Hive.openBox('punishmentLines');
    _immunityLinesBox = await Hive.openBox('immunityLines');
    _tribunalBox = await Hive.openBox('tribunal');
    _customBadgesBox = await Hive.openBox('customBadges');

    _loadLocal();

    _firestore = FirestoreSyncService();
    await _firestore.init(
      onChildrenUpdated: (list) {
        _children = list;
        _saveAllLocal();
        notifyListeners();
      },
      onHistoryUpdated: (list) {
        _history = list;
        _saveAllLocal();
        notifyListeners();
      },
      onGoalsUpdated: (list) {
        _goals = list;
        _saveAllLocal();
        notifyListeners();
      },
      onPunishmentsUpdated: (list) {
        _punishmentLines = list.map((m) => PunishmentLines.fromMap(m)).toList();
        _saveAllLocal();
        notifyListeners();
      },
      onImmunitiesUpdated: (list) {
        _immunityLines = list.map((m) => ImmunityLines.fromMap(m)).toList();
        _saveAllLocal();
        notifyListeners();
      },
      onNotesUpdated: (list) {
        _notes = list;
        _saveAllLocal();
        notifyListeners();
      },
      onTribunalUpdated: (list) {
        _tribunalCases = list.map((m) => TribunalCase.fromMap(m)).toList();
        _saveAllLocal();
        notifyListeners();
      },
    );

    _familyCode = _firestore.familyCode;
    _isSyncEnabled = _firestore.isConnected;
    notifyListeners();
  }

  void _loadLocal() {
    _children = _childrenBox.values
        .map((e) => ChildModel.fromMap(Map<String, dynamic>.from(jsonDecode(e))))
        .toList();
    _history = _historyBox.values
        .map((e) => HistoryEntry.fromMap(Map<String, dynamic>.from(jsonDecode(e))))
        .toList();
    _goals = _goalsBox.values
        .map((e) => Map<String, dynamic>.from(jsonDecode(e)))
        .toList();
    _notes = _notesBox.values
        .map((e) => NoteModel.fromMap(Map<String, dynamic>.from(jsonDecode(e))))
        .toList();
    _unlockedBadges = _badgesBox.values.map((e) => e.toString()).toList();

    for (var key in _parentBonusBox.keys) {
      _parentBonusMinutes[key.toString()] = _parentBonusBox.get(key) ?? 0;
    }

    _punishmentLines = _punishmentLinesBox.values
        .map((e) => PunishmentLines.fromMap(Map<String, dynamic>.from(jsonDecode(e))))
        .toList();
    _immunityLines = _immunityLinesBox.values
        .map((e) => ImmunityLines.fromMap(Map<String, dynamic>.from(jsonDecode(e))))
        .toList();
    _tribunalCases = _tribunalBox.values
        .map((e) => TribunalCase.fromMap(Map<String, dynamic>.from(jsonDecode(e))))
        .toList();
    _customBadges = _customBadgesBox.values
        .map((e) => BadgeModel.fromMap(Map<String, dynamic>.from(jsonDecode(e))))
        .toList();
  }

  // ===== FAMILY CODE =====
  Future<String?> getFamilyCode() async {
    return _familyCode;
  }

  Future<String> createFamily({String? customCode}) async {
    final code = await _firestore.createFamily(customCode: customCode);
    _familyCode = code;
    _isSyncEnabled = true;
    notifyListeners();
    return code;
  }

  Future<bool> joinFamily(String code) async {
    try {
      await _firestore.joinFamily(code);
      _familyCode = code;
      _isSyncEnabled = true;
      notifyListeners();
      return true;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> disconnectFamily() async {
    await _firestore.disconnect();
    _familyCode = null;
    _isSyncEnabled = false;
    notifyListeners();
  }

  // ===== CHILDREN =====
  ChildModel? getChild(String id) {
    try {
      return _children.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> addChild(String name, String avatar) async {
    final child = ChildModel(
      id: _uuid.v4(),
      name: name,
      avatar: avatar,
    );
    _children.add(child);
    await _childrenBox.put(child.id, jsonEncode(child.toMap()));
    if (_firestore.isConnected) await _firestore.saveChild(child);
    notifyListeners();
  }

  Future<void> updateChild(String childId, String name, String avatar) async {
    final index = _children.indexWhere((c) => c.id == childId);
    if (index != -1) {
      _children[index].name = name;
      _children[index].avatar = avatar;
      await _childrenBox.put(childId, jsonEncode(_children[index].toMap()));
      if (_firestore.isConnected) await _firestore.saveChild(_children[index]);
      notifyListeners();
    }
  }

  Future<void> _saveChild(ChildModel child) async {
    final index = _children.indexWhere((c) => c.id == child.id);
    if (index != -1) {
      _children[index] = child;
    }
    await _childrenBox.put(child.id, jsonEncode(child.toMap()));
    if (_firestore.isConnected) await _firestore.saveChild(child);
    notifyListeners();
  }

  Future<void> updateChildPhoto(String childId, String photoBase64) async {
    final child = getChild(childId);
    if (child != null) {
      child.photoBase64 = photoBase64;
      await _saveChild(child);
    }
  }

  Future<void> removeChild(String id) async {
    _children.removeWhere((c) => c.id == id);
    await _childrenBox.delete(id);
    if (_firestore.isConnected) await _firestore.deleteChild(id);
    notifyListeners();
  }

  // ===== POINTS =====
  Future<void> addPoints(String childId, int points, String reason,
      {String category = 'Bonus', bool isBonus = true, String? proofPhotoBase64, DateTime? date}) async {
    final child = getChild(childId);
    if (child == null) return;

    child.points += points;
    if (child.points < 0) child.points = 0;

    await _childrenBox.put(child.id, jsonEncode(child.toMap()));
    if (_firestore.isConnected) await _firestore.saveChild(child);

    final entry = HistoryEntry(
      id: _uuid.v4(),
      childId: childId,
      points: points,
      reason: reason,
      category: category,
      isBonus: isBonus,
      proofPhotoBase64: proofPhotoBase64,
      date: date,
    );

    _history.insert(0, entry);
    await _historyBox.put(entry.id, jsonEncode(entry.toMap()));
    if (_firestore.isConnected) await _firestore.saveHistoryEntry(entry);
    notifyListeners();
  }

  // ===== SCREEN TIME CALCULATION =====

  List<HistoryEntry> getSchoolNotesForWeek(String childId, DateTime weekStart) {
    final monday = weekStart.subtract(Duration(days: weekStart.weekday - 1));
    final mondayStart = DateTime(monday.year, monday.month, monday.day);
    final fridayEnd = DateTime(monday.year, monday.month, monday.day + 4, 23, 59, 59);

    return _history.where((h) {
      return h.childId == childId &&
          h.category == 'school_note' &&
          h.date.isAfter(mondayStart.subtract(const Duration(seconds: 1))) &&
          h.date.isBefore(fridayEnd.add(const Duration(seconds: 1)));
    }).toList();
  }

  double getWeeklySchoolAverage(String childId, {DateTime? referenceDate}) {
    final ref = referenceDate ?? DateTime.now();
    final notes = getSchoolNotesForWeek(childId, ref);
    if (notes.isEmpty) return -1;
    double sum = 0;
    for (var n in notes) {
      sum += n.points;
    }
    return sum / notes.length;
  }

  List<HistoryEntry> getBehaviorEntriesForWeek(String childId, DateTime weekStart) {
    final monday = weekStart.subtract(Duration(days: weekStart.weekday - 1));
    final mondayStart = DateTime(monday.year, monday.month, monday.day);
    final fridayEnd = DateTime(monday.year, monday.month, monday.day + 4, 23, 59, 59);

    return _history.where((h) {
      return h.childId == childId &&
          h.category != 'school_note' &&
          h.category != 'screentime' &&
          h.category != 'saturday_rating' &&
          h.category != 'immunity_used' &&
          h.date.isAfter(mondayStart.subtract(const Duration(seconds: 1))) &&
          h.date.isBefore(fridayEnd.add(const Duration(seconds: 1)));
    }).toList();
  }

  double getWeeklyBehaviorScore(String childId, {DateTime? referenceDate}) {
    final ref = referenceDate ?? DateTime.now();
    final entries = getBehaviorEntriesForWeek(childId, ref);
    if (entries.isEmpty) return 10;

    int totalBonus = 0;
    int totalPenalty = 0;
    for (var e in entries) {
      if (e.isBonus && e.points > 0) {
        totalBonus += e.points;
      } else if (!e.isBonus || e.points < 0) {
        totalPenalty += e.points.abs();
      }
    }

    double score = 10 + (totalBonus / 5) - (totalPenalty / 5);
    return score.clamp(0, 20).toDouble();
  }

  double getWeeklyGlobalScore(String childId, {DateTime? referenceDate}) {
    final ref = referenceDate ?? DateTime.now();
    final schoolAvg = getWeeklySchoolAverage(childId, referenceDate: ref);
    final behaviorScore = getWeeklyBehaviorScore(childId, referenceDate: ref);

    if (schoolAvg < 0) return behaviorScore;
    return (schoolAvg * 0.5) + (behaviorScore * 0.5);
  }

  int _scoreToMinutes(double score) {
    if (score >= 18) return 180;
    if (score >= 16) return 150;
    if (score >= 14) return 120;
    if (score >= 12) return 90;
    if (score >= 10) return 60;
    if (score >= 8) return 30;
    return 0;
  }

  int getSaturdayMinutes(String childId, {DateTime? referenceDate}) {
    final ref = referenceDate ?? DateTime.now();
    final globalScore = getWeeklyGlobalScore(childId, referenceDate: ref);
    final base = _scoreToMinutes(globalScore);
    final bonus = _parentBonusMinutes[childId] ?? 0;
    return (base + bonus).clamp(0, 360);
  }

  double getSaturdayBehaviorRating(String childId, {DateTime? referenceDate}) {
    final ref = referenceDate ?? DateTime.now();
    final daysUntilSaturday = DateTime.saturday - ref.weekday;
    final saturday = ref.add(Duration(days: daysUntilSaturday >= 0 ? daysUntilSaturday : daysUntilSaturday + 7));
    final saturdayStart = DateTime(saturday.year, saturday.month, saturday.day);
    final saturdayEnd = DateTime(saturday.year, saturday.month, saturday.day, 23, 59, 59);

    final ratings = _history.where((h) {
      return h.childId == childId &&
          h.category == 'saturday_rating' &&
          h.date.isAfter(saturdayStart.subtract(const Duration(seconds: 1))) &&
          h.date.isBefore(saturdayEnd.add(const Duration(seconds: 1)));
    }).toList();

    if (ratings.isEmpty) return -1;
    ratings.sort((a, b) => b.date.compareTo(a.date));
    return ratings.first.points.toDouble();
  }

  int getSundayMinutes(String childId, {DateTime? referenceDate}) {
    final ref = referenceDate ?? DateTime.now();
    final saturdayRating = getSaturdayBehaviorRating(childId, referenceDate: ref);
    if (saturdayRating < 0) {
      return getSaturdayMinutes(childId, referenceDate: ref);
    }
    final base = _scoreToMinutes(saturdayRating);
    final bonus = _parentBonusMinutes[childId] ?? 0;
    return (base + bonus).clamp(0, 360);
  }

  double getGlobalScoreDisplay(String childId) => getWeeklyGlobalScore(childId);

  int getTotalWeekendMinutes(String childId) =>
      getSaturdayMinutes(childId) + getSundayMinutes(childId);

  // ===== PARENT BONUS =====
  int getParentBonusMinutes(String childId) => _parentBonusMinutes[childId] ?? 0;

  Future<void> addScreenTimeBonus(String childId, int minutes, String reason) async {
    _parentBonusMinutes[childId] = (_parentBonusMinutes[childId] ?? 0) + minutes;
    await _parentBonusBox.put(childId, _parentBonusMinutes[childId]);

    final entry = HistoryEntry(
      id: _uuid.v4(),
      childId: childId,
      points: 0,
      reason: '\u{1F4FA} Temps ecran ${minutes > 0 ? "+" : ""}${minutes}min - $reason',
      category: 'screentime',
      isBonus: minutes > 0,
    );
    _history.insert(0, entry);
    await _historyBox.put(entry.id, jsonEncode(entry.toMap()));
    if (_firestore.isConnected) await _firestore.saveHistoryEntry(entry);
    notifyListeners();
  }

  Future<void> setParentBonusMinutes(String childId, int minutes) async {
    _parentBonusMinutes[childId] = minutes;
    await _parentBonusBox.put(childId, minutes);
    notifyListeners();
  }

  Future<void> resetScreenTimeBonus(String childId) async {
    _parentBonusMinutes[childId] = 0;
    await _parentBonusBox.put(childId, 0);
    notifyListeners();
  }

  Future<void> rateSaturdayBehavior(String childId, int rating) async {
    final entry = HistoryEntry(
      id: _uuid.v4(),
      childId: childId,
      points: rating,
      reason: 'Note comportement samedi : $rating/20',
      category: 'saturday_rating',
      isBonus: true,
    );
    _history.insert(0, entry);
    await _historyBox.put(entry.id, jsonEncode(entry.toMap()));
    if (_firestore.isConnected) await _firestore.saveHistoryEntry(entry);
    notifyListeners();
  }

  // ===== BADGES =====
  Future<void> unlockBadge(String badgeId) async {
    if (!_unlockedBadges.contains(badgeId)) {
      _unlockedBadges.add(badgeId);
      await _badgesBox.add(badgeId);
      notifyListeners();
    }
  }

  bool isBadgeUnlocked(String badgeId) => _unlockedBadges.contains(badgeId);

  Future<void> addBadgeToChild(String childId, String badgeId) async {
    final child = getChild(childId);
    if (child != null && !child.badgeIds.contains(badgeId)) {
      child.badgeIds.add(badgeId);
      await _saveChild(child);
    }
  }

  // ===== CUSTOM BADGES =====
  Future<void> addCustomBadge(String name, String description, int requiredPoints, String powerType) async {
    final badge = BadgeModel(
      id: _uuid.v4(),
      name: name,
      icon: powerType,
      description: description,
      requiredPoints: requiredPoints,
      powerType: powerType,
      isCustom: true,
    );
    _customBadges.add(badge);
    await _customBadgesBox.put(badge.id, jsonEncode(badge.toMap()));
    notifyListeners();
  }

  Future<void> removeCustomBadge(String badgeId) async {
    _customBadges.removeWhere((b) => b.id == badgeId);
    await _customBadgesBox.delete(badgeId);
    notifyListeners();
  }

  // ===== GOALS =====
  Future<void> addGoal(Map<String, dynamic> goal) async {
    _goals.add(goal);
    await _goalsBox.put(goal['id'], jsonEncode(goal));
    if (_firestore.isConnected) await _firestore.saveGoal(goal);
    notifyListeners();
  }

  Future<void> updateGoal(Map<String, dynamic> goal) async {
    final index = _goals.indexWhere((g) => g['id'] == goal['id']);
    if (index != -1) {
      _goals[index] = goal;
      await _goalsBox.put(goal['id'], jsonEncode(goal));
      if (_firestore.isConnected) await _firestore.saveGoal(goal);
      notifyListeners();
    }
  }

  Future<void> removeGoal(String id) async {
    _goals.removeWhere((g) => g['id'] == id);
    await _goalsBox.delete(id);
    if (_firestore.isConnected) await _firestore.deleteGoal(id);
    notifyListeners();
  }

  List<Map<String, dynamic>> getGoalsForChild(String childId) =>
      _goals.where((g) => g['childId'] == childId).toList();

  // ===== PUNISHMENT LINES =====
  Future<void> addPunishment(String childId, String text, int totalLines) async {
    final punishment = PunishmentLines(
      id: _uuid.v4(),
      childId: childId,
      text: text,
      totalLines: totalLines,
    );
    _punishmentLines.add(punishment);
    await _punishmentLinesBox.put(punishment.id, jsonEncode(punishment.toMap()));
    if (_firestore.isConnected) await _firestore.savePunishment(punishment.toMap());
    notifyListeners();
  }

  Future<void> updatePunishmentProgress(String punishmentId, int additionalLines) async {
    final index = _punishmentLines.indexWhere((p) => p.id == punishmentId);
    if (index != -1) {
      final p = _punishmentLines[index];
      p.completedLines = (p.completedLines + additionalLines).clamp(0, p.totalLines);
      await _punishmentLinesBox.put(p.id, jsonEncode(p.toMap()));
      if (_firestore.isConnected) await _firestore.savePunishment(p.toMap());
      notifyListeners();
    }
  }

  Future<void> addPhotoToPunishment(String punishmentId, String photoBase64) async {
    final index = _punishmentLines.indexWhere((p) => p.id == punishmentId);
    if (index != -1) {
      final p = _punishmentLines[index];
      p.photoUrls.add(photoBase64);
      await _punishmentLinesBox.put(p.id, jsonEncode(p.toMap()));
      if (_firestore.isConnected) await _firestore.savePunishment(p.toMap());
      notifyListeners();
    }
  }

  Future<void> removePhotoFromPunishment(String punishmentId, int photoIndex) async {
    final index = _punishmentLines.indexWhere((p) => p.id == punishmentId);
    if (index != -1) {
      final p = _punishmentLines[index];
      if (photoIndex >= 0 && photoIndex < p.photoUrls.length) {
        p.photoUrls.removeAt(photoIndex);
        await _punishmentLinesBox.put(p.id, jsonEncode(p.toMap()));
        if (_firestore.isConnected) await _firestore.savePunishment(p.toMap());
        notifyListeners();
      }
    }
  }

  Future<void> removePunishment(String id) async {
    _punishmentLines.removeWhere((p) => p.id == id);
    await _punishmentLinesBox.delete(id);
    if (_firestore.isConnected) await _firestore.deletePunishment(id);
    notifyListeners();
  }

  List<PunishmentLines> getPunishmentsForChild(String childId) =>
      _punishmentLines.where((p) => p.childId == childId).toList();

  // ===== IMMUNITY LINES =====
  Future<void> addImmunity(String childId, String reason, int lines, {DateTime? expiresAt}) async {
    final immunity = ImmunityLines(
      id: _uuid.v4(),
      childId: childId,
      reason: reason,
      lines: lines,
      expiresAt: expiresAt,
    );
    _immunityLines.add(immunity);
    await _immunityLinesBox.put(immunity.id, jsonEncode(immunity.toMap()));
    if (_firestore.isConnected) await _firestore.saveImmunity(immunity.toMap());
    notifyListeners();
  }

  Future<void> removeImmunity(String id) async {
    _immunityLines.removeWhere((i) => i.id == id);
    await _immunityLinesBox.delete(id);
    if (_firestore.isConnected) await _firestore.deleteImmunity(id);
    notifyListeners();
  }

  List<ImmunityLines> getImmunitiesForChild(String childId) =>
      _immunityLines.where((i) => i.childId == childId).toList();

  List<ImmunityLines> getUsableImmunitiesForChild(String childId) =>
      _immunityLines.where((i) => i.childId == childId && i.isUsable).toList();

  int getTotalAvailableImmunity(String childId) {
    return getUsableImmunitiesForChild(childId)
        .fold(0, (sum, im) => sum + im.availableLines);
  }

  Future<void> useImmunityOnPunishment(String immunityId, String punishmentId, int linesToUse) async {
    final imIndex = _immunityLines.indexWhere((i) => i.id == immunityId);
    final pIndex = _punishmentLines.indexWhere((p) => p.id == punishmentId);

    if (imIndex != -1 && pIndex != -1) {
      final im = _immunityLines[imIndex];
      final p = _punishmentLines[pIndex];

      final actualLines = linesToUse.clamp(0, im.availableLines);
      final remaining = p.totalLines - p.completedLines;
      final toApply = actualLines.clamp(0, remaining);

      im.usedLines += toApply;
      p.completedLines = (p.completedLines + toApply).clamp(0, p.totalLines);

      await _immunityLinesBox.put(im.id, jsonEncode(im.toMap()));
      await _punishmentLinesBox.put(p.id, jsonEncode(p.toMap()));

      if (_firestore.isConnected) {
        await _firestore.saveImmunity(im.toMap());
        await _firestore.savePunishment(p.toMap());
      }

      final entry = HistoryEntry(
        id: _uuid.v4(),
        childId: p.childId,
        points: 0,
        reason: '\u{1F6E1} Immunite utilisee : $toApply lignes deduites de "${p.text}"',
        category: 'immunity_used',
        isBonus: true,
      );
      _history.insert(0, entry);
      await _historyBox.put(entry.id, jsonEncode(entry.toMap()));
      if (_firestore.isConnected) await _firestore.saveHistoryEntry(entry);
      notifyListeners();
    }
  }

  bool hasActiveImmunity(String childId, String type) {
    return _immunityLines.any((i) => i.childId == childId && i.isUsable);
  }

  // ===== NOTES (commentaires texte) =====
  Future<void> addNote(String childId, String text) async {
    final note = NoteModel(
      id: _uuid.v4(),
      childId: childId,
      text: text,
    );
    _notes.add(note);
    await _notesBox.put(note.id, jsonEncode(note.toMap()));
    if (_firestore.isConnected) await _firestore.saveNote(note);
    notifyListeners();
  }

  Future<void> updateNote(String noteId, String newText) async {
    final index = _notes.indexWhere((n) => n.id == noteId);
    if (index != -1) {
      _notes[index].text = newText;
      await _notesBox.put(noteId, jsonEncode(_notes[index].toMap()));
      if (_firestore.isConnected) await _firestore.saveNote(_notes[index]);
      notifyListeners();
    }
  }

  Future<void> removeNote(String id) async {
    _notes.removeWhere((n) => n.id == id);
    await _notesBox.delete(id);
    if (_firestore.isConnected) await _firestore.deleteNote(id);
    notifyListeners();
  }

  Future<void> toggleNotePin(String noteId) async {
    final index = _notes.indexWhere((n) => n.id == noteId);
    if (index != -1) {
      _notes[index].isPinned = !_notes[index].isPinned;
      await _notesBox.put(noteId, jsonEncode(_notes[index].toMap()));
      if (_firestore.isConnected) await _firestore.saveNote(_notes[index]);
      notifyListeners();
    }
  }

  List<NoteModel> getNotesForChild(String childId) =>
      _notes.where((n) => n.childId == childId).toList();

  // ===== TRIBUNAL =====
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
      id: _uuid.v4(),
      title: title,
      description: description,
      plaintiffId: plaintiffId,
      accusedId: accusedId,
      participants: participants,
      status: TribunalStatus.filed,
    );

    _tribunalCases.insert(0, tc);
    await _tribunalBox.put(tc.id, jsonEncode(tc.toMap()));
    if (_firestore.isConnected) await _firestore.saveTribunalCase(tc.toMap());
    notifyListeners();
  }

  Future<void> scheduleTribunalHearing(String caseId, DateTime scheduledDate) async {
    final index = _tribunalCases.indexWhere((tc) => tc.id == caseId);
    if (index != -1) {
      _tribunalCases[index].scheduledDate = scheduledDate;
      _tribunalCases[index].status = TribunalStatus.scheduled;
      await _tribunalBox.put(caseId, jsonEncode(_tribunalCases[index].toMap()));
      if (_firestore.isConnected) await _firestore.saveTribunalCase(_tribunalCases[index].toMap());
      notifyListeners();
    }
  }

  Future<void> startTribunalHearing(String caseId) async {
    final index = _tribunalCases.indexWhere((tc) => tc.id == caseId);
    if (index != -1) {
      _tribunalCases[index].status = TribunalStatus.inProgress;
      await _tribunalBox.put(caseId, jsonEncode(_tribunalCases[index].toMap()));
      if (_firestore.isConnected) await _firestore.saveTribunalCase(_tribunalCases[index].toMap());
      notifyListeners();
    }
  }

  Future<void> startTribunalDeliberation(String caseId) async {
    final index = _tribunalCases.indexWhere((tc) => tc.id == caseId);
    if (index != -1) {
      _tribunalCases[index].status = TribunalStatus.deliberation;
      await _tribunalBox.put(caseId, jsonEncode(_tribunalCases[index].toMap()));
      if (_firestore.isConnected) await _firestore.saveTribunalCase(_tribunalCases[index].toMap());
      notifyListeners();
    }
  }

  Future<void> dismissTribunalCase(String caseId) async {
    final index = _tribunalCases.indexWhere((tc) => tc.id == caseId);
    if (index != -1) {
      _tribunalCases[index].status = TribunalStatus.closed;
      _tribunalCases[index].verdict = TribunalVerdict.dismissed;
      _tribunalCases[index].verdictDate = DateTime.now();
      await _tribunalBox.put(caseId, jsonEncode(_tribunalCases[index].toMap()));
      if (_firestore.isConnected) await _firestore.saveTribunalCase(_tribunalCases[index].toMap());
      notifyListeners();
    }
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
    final index = _tribunalCases.indexWhere((tc) => tc.id == caseId);
    if (index == -1) return;

    final tc = _tribunalCases[index];
    tc.status = TribunalStatus.verdict;
    tc.verdict = verdict;
    tc.verdictReason = reason;
    tc.verdictDate = DateTime.now();
    tc.plaintiffPoints = plaintiffPoints;
    tc.accusedPoints = accusedPoints;

    await addPoints(tc.plaintiffId, plaintiffPoints,
        '\u{2696} Tribunal "${tc.title}" - ${verdict == TribunalVerdict.guilty ? "Plainte acceptee" : "Plainte rejetee"}',
        category: 'tribunal', isBonus: plaintiffPoints > 0);

    await addPoints(tc.accusedId, accusedPoints,
        '\u{2696} Tribunal "${tc.title}" - ${verdict == TribunalVerdict.guilty ? "Reconnu coupable" : "Declare innocent"}',
        category: 'tribunal', isBonus: accusedPoints > 0);

    if (lawyerPoints != null) {
      for (final entry in lawyerPoints.entries) {
        if (entry.value != 0) {
          final participant = tc.participants.firstWhere(
            (p) => p.childId == entry.key,
            orElse: () => TribunalParticipant(childId: entry.key, role: TribunalRole.witness),
          );
          participant.pointsAwarded = entry.value;
          await addPoints(entry.key, entry.value,
              '\u{2696} Tribunal "${tc.title}" - Avocat',
              category: 'tribunal', isBonus: entry.value > 0);
        }
      }
    }

    if (witnessVerified != null && witnessPoints != null) {
      for (final w in tc.witnesses) {
        final verified = witnessVerified[w.childId] ?? true;
        final pts = witnessPoints[w.childId] ?? 0;
        w.testimonyVerified = verified;
        w.pointsAwarded = pts;
        if (pts != 0) {
          await addPoints(w.childId, pts,
              '\u{2696} Tribunal "${tc.title}" - Temoin ${verified ? "veridique" : "mensonger"}',
              category: 'tribunal', isBonus: pts > 0);
        }
      }
    }

    await _tribunalBox.put(caseId, jsonEncode(tc.toMap()));
    if (_firestore.isConnected) await _firestore.saveTribunalCase(tc.toMap());
    notifyListeners();
  }

  Future<void> addTribunalCase(Map<String, dynamic> tribunalCase) async {
    final tc = TribunalCase.fromMap(tribunalCase);
    _tribunalCases.insert(0, tc);
    await _tribunalBox.put(tc.id, jsonEncode(tc.toMap()));
    if (_firestore.isConnected) await _firestore.saveTribunalCase(tc.toMap());
    notifyListeners();
  }

  Future<void> updateTribunalCase(Map<String, dynamic> tribunalCase) async {
    final tc = TribunalCase.fromMap(tribunalCase);
    final index = _tribunalCases.indexWhere((t) => t.id == tc.id);
    if (index != -1) {
      _tribunalCases[index] = tc;
      await _tribunalBox.put(tc.id, jsonEncode(tc.toMap()));
      if (_firestore.isConnected) await _firestore.saveTribunalCase(tc.toMap());
      notifyListeners();
    }
  }

  Future<void> removeTribunalCase(String id) async {
    _tribunalCases.removeWhere((t) => t.id == id);
    await _tribunalBox.delete(id);
    if (_firestore.isConnected) await _firestore.deleteTribunalCase(id);
    notifyListeners();
  }

  List<TribunalCase> getTribunalForChild(String childId) =>
      _tribunalCases.where((t) => t.plaintiffId == childId || t.accusedId == childId).toList();

  // ===== RESET / CLEAR =====
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
    notifyListeners();
  }

  // ===== QUERIES =====
  List<HistoryEntry> getHistoryForChild(String childId) =>
      _history.where((h) => h.childId == childId).toList();

  List<HistoryEntry> getRecentHistory(String childId, {int limit = 10}) {
    final childHistory = getHistoryForChild(childId);
    childHistory.sort((a, b) => b.date.compareTo(a.date));
    return childHistory.take(limit).toList();
  }

  int getWeeklyPoints(String childId) {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final mondayStart = DateTime(monday.year, monday.month, monday.day);

    return _history
        .where((h) =>
            h.childId == childId &&
            h.date.isAfter(mondayStart) &&
            h.category != 'school_note' &&
            h.category != 'screentime' &&
            h.category != 'saturday_rating' &&
            h.category != 'immunity_used')
        .fold(0, (sum, h) => sum + h.points);
  }

  Map<String, int> getCategoryStats(String childId) {
    final childHistory = getHistoryForChild(childId);
    final stats = <String, int>{};
    for (var h in childHistory) {
      stats[h.category] = (stats[h.category] ?? 0) + h.points;
    }
    return stats;
  }

  // ===== SAVE ALL LOCAL =====
  Future<void> _saveAllLocal() async {
    for (var child in _children) {
      await _childrenBox.put(child.id, jsonEncode(child.toMap()));
    }
    for (var entry in _history) {
      await _historyBox.put(entry.id, jsonEncode(entry.toMap()));
    }
    for (var goal in _goals) {
      await _goalsBox.put(goal['id'], jsonEncode(goal));
    }
    for (var n in _notes) {
      await _notesBox.put(n.id, jsonEncode(n.toMap()));
    }
    for (var p in _punishmentLines) {
      await _punishmentLinesBox.put(p.id, jsonEncode(p.toMap()));
    }
    for (var i in _immunityLines) {
      await _immunityLinesBox.put(i.id, jsonEncode(i.toMap()));
    }
    for (var t in _tribunalCases) {
      await _tribunalBox.put(t.id, jsonEncode(t.toMap()));
    }
    for (var b in _customBadges) {
      await _customBadgesBox.put(b.id, jsonEncode(b.toMap()));
    }
  }
}
