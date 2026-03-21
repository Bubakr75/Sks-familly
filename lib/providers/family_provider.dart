import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../models/child_model.dart';
import '../models/note_model.dart';
import '../models/history_entry.dart';
import '../services/firestore_sync_service.dart';

class FamilyProvider extends ChangeNotifier {
  final _uuid = const Uuid();
  late final FirestoreSyncService _firestore;

  // ===== HIVE BOXES =====
  late Box _childrenBox;
  late Box _historyBox;
  late Box _goalsBox;
  late Box _punishmentsBox;
  late Box _immunitiesBox;
  late Box _notesBox;
  late Box _tribunalBox;
  late Box _badgesBox;
  late Box _parentBonusBox;

  // ===== STATE =====
  List<ChildModel> _children = [];
  List<HistoryEntry> _history = [];
  List<Map<String, dynamic>> _goals = [];
  List<Map<String, dynamic>> _punishments = [];
  List<Map<String, dynamic>> _immunities = [];
  List<NoteModel> _notes = [];
  List<Map<String, dynamic>> _tribunalCases = [];
  List<String> _unlockedBadges = [];
  Map<String, int> _parentBonusMinutes = {};

  String? _familyCode;

  // ===== GETTERS =====
  List<ChildModel> get children => _children;
  List<HistoryEntry> get history => _history;
  List<Map<String, dynamic>> get goals => _goals;
  List<Map<String, dynamic>> get punishments => _punishments;
  List<Map<String, dynamic>> get immunities => _immunities;
  List<NoteModel> get notes => _notes;
  List<Map<String, dynamic>> get tribunalCases => _tribunalCases;
  List<String> get unlockedBadges => _unlockedBadges;
  String? get familyCode => _familyCode;

  // ===== INIT =====
  Future<void> init() async {
    _childrenBox = await Hive.openBox('children');
    _historyBox = await Hive.openBox('history');
    _goalsBox = await Hive.openBox('goals');
    _punishmentsBox = await Hive.openBox('punishments');
    _immunitiesBox = await Hive.openBox('immunities');
    _notesBox = await Hive.openBox('notes');
    _tribunalBox = await Hive.openBox('tribunal');
    _badgesBox = await Hive.openBox('badges');
    _parentBonusBox = await Hive.openBox('parentBonus');

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
        _punishments = list;
        _saveAllLocal();
        notifyListeners();
      },
      onImmunitiesUpdated: (list) {
        _immunities = list;
        _saveAllLocal();
        notifyListeners();
      },
      onNotesUpdated: (list) {
        _notes = list;
        _saveAllLocal();
        notifyListeners();
      },
      onTribunalUpdated: (list) {
        _tribunalCases = list;
        _saveAllLocal();
        notifyListeners();
      },
    );

    _familyCode = _firestore.familyCode;
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
    _punishments = _punishmentsBox.values
        .map((e) => Map<String, dynamic>.from(jsonDecode(e)))
        .toList();
    _immunities = _immunitiesBox.values
        .map((e) => Map<String, dynamic>.from(jsonDecode(e)))
        .toList();
    _notes = _notesBox.values
        .map((e) => NoteModel.fromMap(Map<String, dynamic>.from(jsonDecode(e))))
        .toList();
    _tribunalCases = _tribunalBox.values
        .map((e) => Map<String, dynamic>.from(jsonDecode(e)))
        .toList();
    _unlockedBadges = _badgesBox.values.map((e) => e.toString()).toList();

    // Load parent bonus
    for (var key in _parentBonusBox.keys) {
      _parentBonusMinutes[key.toString()] = _parentBonusBox.get(key) ?? 0;
    }
  }

  // ===== FAMILY CODE =====
  Future<void> joinFamily(String code) async {
    await _firestore.joinFamily(code);
    _familyCode = code;
    notifyListeners();
  }

  Future<String> createFamily() async {
    final code = await _firestore.createFamily();
    _familyCode = code;
    notifyListeners();
    return code;
  }

  // ===== CHILDREN =====
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
    if (_firestore.isConnected) await _firestore.saveChild(child);
    notifyListeners();
  }

  Future<void> updateChild(ChildModel child) async {
    final index = _children.indexWhere((c) => c.id == child.id);
    if (index != -1) {
      _children[index] = child;
      await _childrenBox.put(child.id, jsonEncode(child.toMap()));
      if (_firestore.isConnected) await _firestore.saveChild(child);
      notifyListeners();
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

  /// Récupère les notes "school_note" d'un enfant pour une semaine donnée (lun-ven)
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

  /// Moyenne des notes scolaires de la semaine (sur 20)
  double getWeeklySchoolAverage(String childId, {DateTime? referenceDate}) {
    final ref = referenceDate ?? DateTime.now();
    final notes = getSchoolNotesForWeek(childId, ref);
    if (notes.isEmpty) return -1; // pas de note
    double sum = 0;
    for (var n in notes) {
      sum += n.points;
    }
    return sum / notes.length;
  }

  /// Récupère toutes les entrées de comportement de la semaine (bonus, pénalités, etc. sauf school_note)
  List<HistoryEntry> getBehaviorEntriesForWeek(String childId, DateTime weekStart) {
    final monday = weekStart.subtract(Duration(days: weekStart.weekday - 1));
    final mondayStart = DateTime(monday.year, monday.month, monday.day);
    final fridayEnd = DateTime(monday.year, monday.month, monday.day + 4, 23, 59, 59);

    return _history.where((h) {
      return h.childId == childId &&
          h.category != 'school_note' &&
          h.category != 'screentime' &&
          h.date.isAfter(mondayStart.subtract(const Duration(seconds: 1))) &&
          h.date.isBefore(fridayEnd.add(const Duration(seconds: 1)));
    }).toList();
  }

  /// Note de comportement de la semaine sur 20 (basée sur bonus/pénalités)
  double getWeeklyBehaviorScore(String childId, {DateTime? referenceDate}) {
    final ref = referenceDate ?? DateTime.now();
    final entries = getBehaviorEntriesForWeek(childId, ref);
    if (entries.isEmpty) return 10; // note par défaut si rien

    int totalBonus = 0;
    int totalPenalty = 0;
    for (var e in entries) {
      if (e.isBonus && e.points > 0) {
        totalBonus += e.points;
      } else if (!e.isBonus || e.points < 0) {
        totalPenalty += e.points.abs();
      }
    }

    // Base 10/20, +1 par tranche de 5 pts bonus, -1 par tranche de 5 pts pénalité
    double score = 10 + (totalBonus / 5) - (totalPenalty / 5);
    return score.clamp(0, 20);
  }

  /// Note globale de la semaine (combinée) sur 20
  /// 50% notes scolaires + 50% comportement
  /// Si pas de notes scolaires, 100% comportement
  double getWeeklyGlobalScore(String childId, {DateTime? referenceDate}) {
    final ref = referenceDate ?? DateTime.now();
    final schoolAvg = getWeeklySchoolAverage(childId, referenceDate: ref);
    final behaviorScore = getWeeklyBehaviorScore(childId, referenceDate: ref);

    if (schoolAvg < 0) {
      // Pas de notes scolaires cette semaine : 100% comportement
      return behaviorScore;
    }

    // 50% notes scolaires + 50% comportement
    return (schoolAvg * 0.5) + (behaviorScore * 0.5);
  }

  /// Convertit une note globale sur 20 en minutes d'écran (max 180 = 3h)
  int _scoreToMinutes(double score) {
    if (score >= 18) return 180; // 3h
    if (score >= 16) return 150; // 2h30
    if (score >= 14) return 120; // 2h
    if (score >= 12) return 90;  // 1h30
    if (score >= 10) return 60;  // 1h
    if (score >= 8) return 30;   // 30min
    return 0;
  }

  /// Temps d'écran du SAMEDI en minutes (basé sur lun-ven)
  int getSaturdayMinutes(String childId, {DateTime? referenceDate}) {
    final ref = referenceDate ?? DateTime.now();
    final globalScore = getWeeklyGlobalScore(childId, referenceDate: ref);
    final base = _scoreToMinutes(globalScore);
    final bonus = _parentBonusMinutes[childId] ?? 0;
    return (base + bonus).clamp(0, 360); // max 6h avec bonus
  }

  /// Récupère la note de comportement du samedi (catégorie 'saturday_rating')
  double getSaturdayBehaviorRating(String childId, {DateTime? referenceDate}) {
    final ref = referenceDate ?? DateTime.now();
    // Trouver le samedi de cette semaine
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

    if (ratings.isEmpty) return -1; // pas encore noté
    // Prendre la dernière note
    ratings.sort((a, b) => b.date.compareTo(a.date));
    return ratings.first.points.toDouble();
  }

  /// Temps d'écran du DIMANCHE en minutes (basé sur comportement du samedi)
  int getSundayMinutes(String childId, {DateTime? referenceDate}) {
    final ref = referenceDate ?? DateTime.now();
    final saturdayRating = getSaturdayBehaviorRating(childId, referenceDate: ref);
    if (saturdayRating < 0) {
      // Pas encore de note samedi : utiliser la même note que samedi par défaut
      return getSaturdayMinutes(childId, referenceDate: ref);
    }
    final base = _scoreToMinutes(saturdayRating);
    final bonus = _parentBonusMinutes[childId] ?? 0;
    return (base + bonus).clamp(0, 360);
  }

  /// Note globale affichée (sur 20)
  double getGlobalScoreDisplay(String childId) {
    return getWeeklyGlobalScore(childId);
  }

  /// Temps d'écran total du week-end
  int getTotalWeekendMinutes(String childId) {
    return getSaturdayMinutes(childId) + getSundayMinutes(childId);
  }

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

  /// Noter le comportement du samedi (pour calculer le dimanche)
  Future<void> rateSaturdayBehavior(String childId, int rating) async {
    final now = DateTime.now();
    final entry = HistoryEntry(
      id: _uuid.v4(),
      childId: childId,
      points: rating,
      reason: 'Note comportement samedi : $rating/20',
      category: 'saturday_rating',
      isBonus: true,
      date: now,
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
      await updateChild(child);
    }
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

  // ===== PUNISHMENTS =====
  Future<void> addPunishment(Map<String, dynamic> punishment) async {
    _punishments.add(punishment);
    await _punishmentsBox.put(punishment['id'], jsonEncode(punishment));
    if (_firestore.isConnected) await _firestore.savePunishment(punishment);
    notifyListeners();
  }

  Future<void> updatePunishment(Map<String, dynamic> punishment) async {
    final index = _punishments.indexWhere((p) => p['id'] == punishment['id']);
    if (index != -1) {
      _punishments[index] = punishment;
      await _punishmentsBox.put(punishment['id'], jsonEncode(punishment));
      if (_firestore.isConnected) await _firestore.savePunishment(punishment);
      notifyListeners();
    }
  }

  Future<void> removePunishment(String id) async {
    _punishments.removeWhere((p) => p['id'] == id);
    await _punishmentsBox.delete(id);
    if (_firestore.isConnected) await _firestore.deletePunishment(id);
    notifyListeners();
  }

  List<Map<String, dynamic>> getPunishmentsForChild(String childId) =>
      _punishments.where((p) => p['childId'] == childId).toList();

  // ===== IMMUNITIES =====
  Future<void> addImmunity(Map<String, dynamic> immunity) async {
    _immunities.add(immunity);
    await _immunitiesBox.put(immunity['id'], jsonEncode(immunity));
    if (_firestore.isConnected) await _firestore.saveImmunity(immunity);
    notifyListeners();
  }

  Future<void> removeImmunity(String id) async {
    _immunities.removeWhere((i) => i['id'] == id);
    await _immunitiesBox.delete(id);
    if (_firestore.isConnected) await _firestore.deleteImmunity(id);
    notifyListeners();
  }

  List<Map<String, dynamic>> getImmunitiesForChild(String childId) =>
      _immunities.where((i) => i['childId'] == childId).toList();

  bool hasActiveImmunity(String childId, String type) {
    final now = DateTime.now();
    return _immunities.any((i) =>
        i['childId'] == childId &&
        i['type'] == type &&
        DateTime.parse(i['expiresAt']).isAfter(now));
  }

  // ===== NOTES (commentaires texte) =====
  Future<void> addNote(NoteModel note) async {
    _notes.add(note);
    await _notesBox.put(note.id, jsonEncode(note.toMap()));
    if (_firestore.isConnected) await _firestore.saveNote(note);
    notifyListeners();
  }

  Future<void> updateNote(NoteModel note) async {
    final index = _notes.indexWhere((n) => n.id == note.id);
    if (index != -1) {
      _notes[index] = note;
      await _notesBox.put(note.id, jsonEncode(note.toMap()));
      if (_firestore.isConnected) await _firestore.saveNote(note);
      notifyListeners();
    }
  }

  Future<void> removeNote(String id) async {
    _notes.removeWhere((n) => n.id == id);
    await _notesBox.delete(id);
    if (_firestore.isConnected) await _firestore.deleteNote(id);
    notifyListeners();
  }

  Future<void> togglePinNote(String noteId) async {
    final note = _notes.firstWhere((n) => n.id == noteId);
    note.isPinned = !note.isPinned;
    await updateNote(note);
  }

  List<NoteModel> getNotesForChild(String childId) =>
      _notes.where((n) => n.childId == childId).toList();

  // ===== TRIBUNAL =====
  Future<void> addTribunalCase(Map<String, dynamic> tribunalCase) async {
    _tribunalCases.add(tribunalCase);
    await _tribunalBox.put(tribunalCase['id'], jsonEncode(tribunalCase));
    if (_firestore.isConnected) await _firestore.saveTribunalCase(tribunalCase);
    notifyListeners();
  }

  Future<void> updateTribunalCase(Map<String, dynamic> tribunalCase) async {
    final index = _tribunalCases.indexWhere((t) => t['id'] == tribunalCase['id']);
    if (index != -1) {
      _tribunalCases[index] = tribunalCase;
      await _tribunalBox.put(tribunalCase['id'], jsonEncode(tribunalCase));
      if (_firestore.isConnected) await _firestore.saveTribunalCase(tribunalCase);
      notifyListeners();
    }
  }

  Future<void> removeTribunalCase(String id) async {
    _tribunalCases.removeWhere((t) => t['id'] == id);
    await _tribunalBox.delete(id);
    if (_firestore.isConnected) await _firestore.deleteTribunalCase(id);
    notifyListeners();
  }

  List<Map<String, dynamic>> getTribunalForChild(String childId) =>
      _tribunalCases.where((t) => t['childId'] == childId).toList();

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
            h.category != 'saturday_rating')
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
    for (var p in _punishments) {
      await _punishmentsBox.put(p['id'], jsonEncode(p));
    }
    for (var i in _immunities) {
      await _immunitiesBox.put(i['id'], jsonEncode(i));
    }
    for (var n in _notes) {
      await _notesBox.put(n.id, jsonEncode(n.toMap()));
    }
    for (var t in _tribunalCases) {
      await _tribunalBox.put(t['id'], jsonEncode(t));
    }
  }
}
