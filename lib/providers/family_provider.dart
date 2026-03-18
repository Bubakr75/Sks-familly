import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/child_model.dart';
import '../models/history_entry.dart';
import '../models/goal_model.dart';
import '../models/badge_model.dart';
import '../models/punishment_lines.dart';
import '../models/immunity_lines.dart';
import '../models/note_model.dart';
import '../models/tribunal_model.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';

class FamilyProvider extends ChangeNotifier {
  List<ChildModel> _children = [];
  List<HistoryEntry> _history = [];
  List<GoalModel> _goals = [];
  List<PunishmentLines> _punishments = [];
  List<ImmunityLines> _immunities = [];
  List<NoteModel> _notes = [];
  List<BadgeModel> _customBadges = [];
  List<TribunalCase> _tribunalCases = [];
  final _uuid = const Uuid();
  final _firestore = FirestoreService();

  late Box _childrenBox;
  late Box _historyBox;
  late Box _goalsBox;
  late Box _punishmentsBox;
  late Box _immunitiesBox;
  late Box _notesBox;
  late Box _customBadgesBox;
  late Box _tribunalBox;

  List<ChildModel> get children => _children;
  List<HistoryEntry> get history => _history;
  List<GoalModel> get goals => _goals;
  List<PunishmentLines> get punishments => _punishments;
  List<ImmunityLines> get immunities => _immunities;
  List<NoteModel> get notes => _notes;
  List<BadgeModel> get customBadges => _customBadges;
  List<TribunalCase> get tribunalCases => _tribunalCases;
  bool get isSyncEnabled => _firestore.isConnected;
  String? get familyId => _firestore.familyId;

  // Tribunal queries
  List<TribunalCase> get activeTribunalCases =>
      _tribunalCases.where((t) => !t.isClosed).toList()
        ..sort((a, b) => b.filedDate.compareTo(a.filedDate));

  List<TribunalCase> get closedTribunalCases =>
      _tribunalCases.where((t) => t.isClosed).toList()
        ..sort((a, b) => b.filedDate.compareTo(a.filedDate));

  List<TribunalCase> getTribunalCasesForChild(String childId) =>
      _tribunalCases.where((t) =>
          t.plaintiffId == childId ||
          t.accusedId == childId ||
          t.participants.any((p) => p.childId == childId)).toList()
        ..sort((a, b) => b.filedDate.compareTo(a.filedDate));

  int getTribunalWins(String childId) =>
      _tribunalCases.where((t) =>
          t.status == TribunalStatus.verdict &&
          ((t.plaintiffId == childId && t.verdict == TribunalVerdict.guilty) ||
           (t.accusedId == childId && t.verdict == TribunalVerdict.innocent))).length;

  int getTribunalLosses(String childId) =>
      _tribunalCases.where((t) =>
          t.status == TribunalStatus.verdict &&
          ((t.plaintiffId == childId && t.verdict == TribunalVerdict.innocent) ||
           (t.accusedId == childId && t.verdict == TribunalVerdict.guilty))).length;

  List<BadgeModel> get allBadges {
    final all = List<BadgeModel>.from(BadgeModel.defaultBadges);
    all.addAll(_customBadges);
    all.sort((a, b) => a.requiredPoints.compareTo(b.requiredPoints));
    return all;
  }

  List<ChildModel> get childrenSorted {
    final sorted = List<ChildModel>.from(_children);
    sorted.sort((a, b) => b.points.compareTo(a.points));
    return sorted;
  }

  Future<void> init() async {
    _childrenBox = await Hive.openBox('children');
    _historyBox = await Hive.openBox('history');
    _goalsBox = await Hive.openBox('goals');
    _punishmentsBox = await Hive.openBox('punishments');
    _immunitiesBox = await Hive.openBox('immunities');
    _notesBox = await Hive.openBox('notes');
    _customBadgesBox = await Hive.openBox('customBadges');
    _tribunalBox = await Hive.openBox('tribunal');
    _loadLocalData();

    _firestore.onChildrenChanged = _onCloudChildrenChanged;
    _firestore.onHistoryChanged = _onCloudHistoryChanged;
    _firestore.onGoalsChanged = _onCloudGoalsChanged;
    _firestore.onPunishmentsChanged = _onCloudPunishmentsChanged;
    _firestore.onNotesChanged = _onCloudNotesChanged;

    await _firestore.init();
  }

  void reconnectFirestore() {
    _firestore.reconnect();
  }

  void _loadLocalData() {
    _children = _childrenBox.values.map((e) => ChildModel.fromMap(Map<String, dynamic>.from(jsonDecode(e)))).toList();
    _history = _historyBox.values.map((e) => HistoryEntry.fromMap(Map<String, dynamic>.from(jsonDecode(e)))).toList();
    _goals = _goalsBox.values.map((e) => GoalModel.fromMap(Map<String, dynamic>.from(jsonDecode(e)))).toList();
    _punishments = _punishmentsBox.values.map((e) => PunishmentLines.fromMap(Map<String, dynamic>.from(jsonDecode(e)))).toList();
    _immunities = _immunitiesBox.values.map((e) => ImmunityLines.fromMap(Map<String, dynamic>.from(jsonDecode(e)))).toList();
    _notes = _notesBox.values.map((e) => NoteModel.fromMap(Map<String, dynamic>.from(jsonDecode(e)))).toList();
    _customBadges = _customBadgesBox.values.map((e) => BadgeModel.fromMap(Map<String, dynamic>.from(jsonDecode(e)))).toList();
    _tribunalCases = _tribunalBox.values.map((e) => TribunalCase.fromMap(Map<String, dynamic>.from(jsonDecode(e)))).toList();
    _notes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _history.sort((a, b) => b.date.compareTo(a.date));
    _tribunalCases.sort((a, b) => b.filedDate.compareTo(a.filedDate));
    notifyListeners();
  }

  final Set<String> _knownHistoryIds = {};
  final Set<String> _knownPunishmentIds = {};
  final Map<String, int> _knownPunishmentProgress = {};
  final Set<String> _knownBadgeKeys = {};
  final Set<String> _knownGoalCompletions = {};
  bool _initialLoadDone = false;

  String get _myDeviceId => _firestore.deviceId;

  bool _isFromOtherDevice(String? deviceId) {
    if (deviceId == null || deviceId.isEmpty) return true;
    return deviceId != _myDeviceId;
  }

  String? _getDeviceIdFromRaw(List<Map<String, dynamic>> rawList, String id, String field) {
    for (final raw in rawList) {
      if (raw['id'] == id) return raw[field] as String?;
    }
    return null;
  }

  void _onCloudChildrenChanged(List<ChildModel> cloudChildren, List<Map<String, dynamic>> rawList) {
    if (_initialLoadDone) {
      for (final child in cloudChildren) {
        final deviceId = _getDeviceIdFromRaw(rawList, child.id, 'lastModifiedBy');
        if (_isFromOtherDevice(deviceId)) {
          for (final badgeId in child.badgeIds) {
            final key = '${child.id}_$badgeId';
            if (!_knownBadgeKeys.contains(key)) {
              final badge = allBadges.where((b) => b.id == badgeId).firstOrNull;
              if (badge != null) NotificationService.notifyBadge(child.name, badge.name);
            }
          }
        }
      }
    }
    _knownBadgeKeys.clear();
    for (final child in cloudChildren) {
      for (final badgeId in child.badgeIds) {
        _knownBadgeKeys.add('${child.id}_$badgeId');
      }
    }
    _children = cloudChildren;
    _childrenBox.clear().then((_) { for (var c in _children) _childrenBox.put(c.id, jsonEncode(c.toMap())); });
    notifyListeners();
  }

  void _onCloudHistoryChanged(List<HistoryEntry> cloudHistory, List<Map<String, dynamic>> rawList) {
    if (_initialLoadDone) {
      for (final entry in cloudHistory) {
        if (!_knownHistoryIds.contains(entry.id)) {
          final deviceId = _getDeviceIdFromRaw(rawList, entry.id, 'deviceId');
          if (_isFromOtherDevice(deviceId)) {
            final child = _children.where((c) => c.id == entry.childId).firstOrNull;
            final childName = child?.name ?? 'Enfant';
            if (entry.isBonus) {
              NotificationService.notifyBonus(childName, entry.points, entry.reason);
            } else {
              NotificationService.notifyPenalty(childName, entry.points, entry.reason);
            }
          }
        }
      }
    }
    _knownHistoryIds.clear();
    for (final h in cloudHistory) _knownHistoryIds.add(h.id);
    _history = cloudHistory;
    _historyBox.clear().then((_) { for (var h in _history) _historyBox.put(h.id, jsonEncode(h.toMap())); });
    if (!_initialLoadDone) _initialLoadDone = true;
    notifyListeners();
  }

  void _onCloudGoalsChanged(List<GoalModel> cloudGoals, List<Map<String, dynamic>> rawList) {
    if (_initialLoadDone) {
      for (final goal in cloudGoals) {
        if (goal.completed && !_knownGoalCompletions.contains(goal.id)) {
          final deviceId = _getDeviceIdFromRaw(rawList, goal.id, 'lastModifiedBy');
          if (_isFromOtherDevice(deviceId)) {
            final child = _children.where((c) => c.id == goal.childId).firstOrNull;
            NotificationService.notifyGoalCompleted(child?.name ?? 'Enfant', goal.title);
          }
        }
      }
    }
    _knownGoalCompletions.clear();
    for (final g in cloudGoals) { if (g.completed) _knownGoalCompletions.add(g.id); }
    _goals = cloudGoals;
    _goalsBox.clear().then((_) { for (var g in _goals) _goalsBox.put(g.id, jsonEncode(g.toMap())); });
    notifyListeners();
  }

  void _onCloudPunishmentsChanged(List<PunishmentLines> cloudPunishments, List<Map<String, dynamic>> rawList) {
    if (_initialLoadDone) {
      for (final p in cloudPunishments) {
        final deviceId = _getDeviceIdFromRaw(rawList, p.id, 'lastModifiedBy');
        if (_isFromOtherDevice(deviceId)) {
          if (!_knownPunishmentIds.contains(p.id)) {
            final child = _children.where((c) => c.id == p.childId).firstOrNull;
            NotificationService.notifyPunishment(child?.name ?? 'Enfant', p.text, p.totalLines);
          } else {
            final oldProgress = _knownPunishmentProgress[p.id] ?? 0;
            if (p.completedLines > oldProgress) {
              final child = _children.where((c) => c.id == p.childId).firstOrNull;
              NotificationService.notifyPunishmentProgress(child?.name ?? 'Enfant', p.completedLines, p.totalLines);
            }
          }
        }
      }
    }
    _knownPunishmentIds.clear();
    _knownPunishmentProgress.clear();
    for (final p in cloudPunishments) { _knownPunishmentIds.add(p.id); _knownPunishmentProgress[p.id] = p.completedLines; }
    _punishments = cloudPunishments;
    _punishmentsBox.clear().then((_) { for (var p in _punishments) _punishmentsBox.put(p.id, jsonEncode(p.toMap())); });
    notifyListeners();
  }

  void _onCloudNotesChanged(List<NoteModel> cloudNotes) {
    _notes = cloudNotes;
    _notesBox.clear().then((_) { for (var n in _notes) _notesBox.put(n.id, jsonEncode(n.toMap())); });
    notifyListeners();
  }

  Future<String> createFamily({String? customCode}) async {
    final code = await _firestore.createFamily(customCode: customCode);
    await _firestore.uploadLocalData(children: _children, history: _history, goals: _goals, punishments: _punishments);
    if (_notes.isNotEmpty) await _firestore.uploadNotes(_notes);
    notifyListeners();
    return code;
  }

  Future<bool> joinFamily(String code) async {
    final success = await _firestore.joinFamily(code);
    if (success) notifyListeners();
    return success;
  }

  Future<String?> getFamilyCode() async { return _firestore.getFamilyCode(); }
  Future<void> disconnectFamily() async { await _firestore.disconnectFamily(); notifyListeners(); }

  // === CHILDREN ===
  Future<void> addChild(String name, String avatar) async {
    final child = ChildModel(id: _uuid.v4(), name: name, avatar: avatar);
    _children.add(child);
    await _childrenBox.put(child.id, jsonEncode(child.toMap()));
    if (_firestore.isConnected) await _firestore.saveChild(child);
    notifyListeners();
  }

  Future<void> updateChild(String id, String name, String avatar) async {
    final idx = _children.indexWhere((c) => c.id == id);
    if (idx != -1) {
      _children[idx].name = name;
      _children[idx].avatar = avatar;
      await _childrenBox.put(id, jsonEncode(_children[idx].toMap()));
      if (_firestore.isConnected) await _firestore.saveChild(_children[idx]);
      notifyListeners();
    }
  }

  Future<void> updateChildPhoto(String id, String photoBase64) async {
    final idx = _children.indexWhere((c) => c.id == id);
    if (idx != -1) {
      _children[idx].photoBase64 = photoBase64;
      await _childrenBox.put(id, jsonEncode(_children[idx].toMap()));
      if (_firestore.isConnected) await _firestore.saveChild(_children[idx]);
      notifyListeners();
    }
  }

  Future<void> removeChild(String id) async {
    _children.removeWhere((c) => c.id == id);
    await _childrenBox.delete(id);
    _history.removeWhere((h) => h.childId == id);
    _goals.removeWhere((g) => g.childId == id);
    _punishments.removeWhere((p) => p.childId == id);
    _immunities.removeWhere((im) => im.childId == id);
    await _saveAllLocal();
    if (_firestore.isConnected) await _firestore.deleteChild(id);
    notifyListeners();
  }

  // === POINTS ===
  Future<void> addPoints(String childId, int points, String reason, String category, {bool isBonus = true, String? proofPhotoBase64}) async {
    final idx = _children.indexWhere((c) => c.id == childId);
    if (idx != -1) {
      _children[idx].points += points;
      if (_children[idx].points < 0) _children[idx].points = 0;
      _updateLevel(_children[idx]);
      _checkBadges(_children[idx]);
      await _childrenBox.put(childId, jsonEncode(_children[idx].toMap()));
      final entry = HistoryEntry(id: _uuid.v4(), childId: childId, points: points, reason: reason, category: category, isBonus: isBonus, proofPhotoBase64: proofPhotoBase64);
      _history.insert(0, entry);
      await _historyBox.put(entry.id, jsonEncode(entry.toMap()));
      _knownHistoryIds.add(entry.id);
      if (_firestore.isConnected) {
        await _firestore.saveChild(_children[idx]);
        await _firestore.saveHistoryEntry(entry);
      }
      notifyListeners();
    }
  }

  void _updateLevel(ChildModel child) {
    if (child.points >= 300) { child.level = 6; }
    else if (child.points >= 220) { child.level = 5; }
    else if (child.points >= 150) { child.level = 4; }
    else if (child.points >= 90) { child.level = 3; }
    else if (child.points >= 40) { child.level = 2; }
    else { child.level = 1; }
  }

  void _checkBadges(ChildModel child) {
    for (final badge in allBadges) {
      if (child.points >= badge.requiredPoints && !child.badgeIds.contains(badge.id)) {
        child.badgeIds.add(badge.id);
      }
    }
  }

  Future<void> resetAllScores() async {
    for (var child in _children) { child.points = 0; child.level = 1; child.badgeIds.clear(); await _childrenBox.put(child.id, jsonEncode(child.toMap())); }
    if (_firestore.isConnected) await _firestore.resetAllScores();
    notifyListeners();
  }

  Future<void> clearHistory() async {
    _history.clear();
    await _historyBox.clear();
    if (_firestore.isConnected) await _firestore.clearAllHistory();
    notifyListeners();
  }

  // === CUSTOM BADGES ===
  Future<void> addCustomBadge(String name, String description, int requiredPoints, String powerType) async {
    final badge = BadgeModel(
      id: 'custom_${_uuid.v4()}',
      name: name,
      icon: powerType,
      description: description,
      requiredPoints: requiredPoints,
      powerType: powerType,
      isCustom: true,
    );
    _customBadges.add(badge);
    await _customBadgesBox.put(badge.id, jsonEncode(badge.toMap()));
    for (var child in _children) {
      _checkBadges(child);
      await _childrenBox.put(child.id, jsonEncode(child.toMap()));
    }
    notifyListeners();
  }

  Future<void> updateCustomBadge(String badgeId, String name, String description, int requiredPoints, String powerType) async {
    final idx = _customBadges.indexWhere((b) => b.id == badgeId);
    if (idx != -1) {
      _customBadges[idx].name = name;
      _customBadges[idx].description = description;
      _customBadges[idx].requiredPoints = requiredPoints;
      _customBadges[idx].powerType = powerType;
      _customBadges[idx].icon = powerType;
      await _customBadgesBox.put(badgeId, jsonEncode(_customBadges[idx].toMap()));
      notifyListeners();
    }
  }

  Future<void> removeCustomBadge(String badgeId) async {
    _customBadges.removeWhere((b) => b.id == badgeId);
    await _customBadgesBox.delete(badgeId);
    for (var child in _children) {
      child.badgeIds.remove(badgeId);
      await _childrenBox.put(child.id, jsonEncode(child.toMap()));
    }
    notifyListeners();
  }

  // === GOALS ===
  Future<void> addGoal(String childId, String title, int targetPoints) async {
    final goal = GoalModel(id: _uuid.v4(), childId: childId, title: title, targetPoints: targetPoints);
    _goals.add(goal);
    await _goalsBox.put(goal.id, jsonEncode(goal.toMap()));
    if (_firestore.isConnected) await _firestore.saveGoal(goal);
    notifyListeners();
  }

  Future<void> toggleGoal(String goalId) async {
    final idx = _goals.indexWhere((g) => g.id == goalId);
    if (idx != -1) {
      _goals[idx].completed = !_goals[idx].completed;
      if (_goals[idx].completed) _knownGoalCompletions.add(goalId);
      await _goalsBox.put(goalId, jsonEncode(_goals[idx].toMap()));
      if (_firestore.isConnected) await _firestore.saveGoal(_goals[idx]);
      notifyListeners();
    }
  }

  Future<void> removeGoal(String goalId) async {
    _goals.removeWhere((g) => g.id == goalId);
    await _goalsBox.delete(goalId);
    if (_firestore.isConnected) await _firestore.deleteGoal(goalId);
    notifyListeners();
  }

  // === PUNISHMENTS ===
  Future<void> addPunishment(String childId, String text, int lines) async {
    final p = PunishmentLines(id: _uuid.v4(), childId: childId, text: text, totalLines: lines);
    _punishments.add(p);
    _knownPunishmentIds.add(p.id);
    _knownPunishmentProgress[p.id] = 0;
    await _punishmentsBox.put(p.id, jsonEncode(p.toMap()));
    if (_firestore.isConnected) await _firestore.savePunishment(p);
    notifyListeners();
  }

  Future<void> updatePunishmentProgress(String punishmentId, int linesToAdd) async {
    final idx = _punishments.indexWhere((p) => p.id == punishmentId);
    if (idx == -1) return;
    final p = _punishments[idx];
    p.completedLines = (p.completedLines + linesToAdd).clamp(0, p.totalLines);
    _knownPunishmentProgress[p.id] = p.completedLines;
    await _punishmentsBox.put(punishmentId, jsonEncode(p.toMap()));
    if (_firestore.isConnected) await _firestore.savePunishment(p);
    notifyListeners();
  }

  Future<void> addPhotoToPunishment(String punishmentId, String photoBase64) async {
    final idx = _punishments.indexWhere((p) => p.id == punishmentId);
    if (idx == -1) return;
    _punishments[idx].photoUrls.add(photoBase64);
    await _punishmentsBox.put(punishmentId, jsonEncode(_punishments[idx].toMap()));
    if (_firestore.isConnected) await _firestore.savePunishment(_punishments[idx]);
    notifyListeners();
  }

  Future<void> removePhotoFromPunishment(String punishmentId, int photoIndex) async {
    final idx = _punishments.indexWhere((p) => p.id == punishmentId);
    if (idx == -1) return;
    if (photoIndex >= 0 && photoIndex < _punishments[idx].photoUrls.length) {
      _punishments[idx].photoUrls.removeAt(photoIndex);
      await _punishmentsBox.put(punishmentId, jsonEncode(_punishments[idx].toMap()));
      if (_firestore.isConnected) await _firestore.savePunishment(_punishments[idx]);
      notifyListeners();
    }
  }

  Future<void> incrementPunishmentLines(String pId) async {
    final idx = _punishments.indexWhere((p) => p.id == pId);
    if (idx != -1 && !_punishments[idx].isCompleted) {
      _punishments[idx].completedLines++;
      _knownPunishmentProgress[pId] = _punishments[idx].completedLines;
      await _punishmentsBox.put(pId, jsonEncode(_punishments[idx].toMap()));
      if (_firestore.isConnected) await _firestore.savePunishment(_punishments[idx]);
      notifyListeners();
    }
  }

  Future<void> removePunishment(String pId) async {
    _punishments.removeWhere((p) => p.id == pId);
    await _punishmentsBox.delete(pId);
    if (_firestore.isConnected) await _firestore.deletePunishment(pId);
    notifyListeners();
  }

  Future<void> addPunishmentPhoto(String pId, String photoBase64) async {
    final idx = _punishments.indexWhere((p) => p.id == pId);
    if (idx != -1) {
      _punishments[idx].photoUrls.add(photoBase64);
      await _punishmentsBox.put(pId, jsonEncode(_punishments[idx].toMap()));
      if (_firestore.isConnected) await _firestore.savePunishment(_punishments[idx]);
      notifyListeners();
    }
  }

  Future<void> removePunishmentPhoto(String pId, int photoIndex) async {
    final idx = _punishments.indexWhere((p) => p.id == pId);
    if (idx != -1 && photoIndex < _punishments[idx].photoUrls.length) {
      _punishments[idx].photoUrls.removeAt(photoIndex);
      await _punishmentsBox.put(pId, jsonEncode(_punishments[idx].toMap()));
      if (_firestore.isConnected) await _firestore.savePunishment(_punishments[idx]);
      notifyListeners();
    }
  }

  // === IMMUNITIES ===
  Future<void> addImmunity(String childId, String reason, int lines, {DateTime? expiresAt}) async {
    final im = ImmunityLines(id: _uuid.v4(), childId: childId, reason: reason, lines: lines, expiresAt: expiresAt);
    _immunities.add(im);
    await _immunitiesBox.put(im.id, jsonEncode(im.toMap()));
    notifyListeners();
  }

  Future<void> removeImmunity(String imId) async {
    _immunities.removeWhere((im) => im.id == imId);
    await _immunitiesBox.delete(imId);
    notifyListeners();
  }

  Future<void> useImmunityOnPunishment(String immunityId, String punishmentId, int linesToUse) async {
    final imIdx = _immunities.indexWhere((im) => im.id == immunityId);
    final pIdx = _punishments.indexWhere((p) => p.id == punishmentId);
    if (imIdx == -1 || pIdx == -1) return;
    final im = _immunities[imIdx];
    final p = _punishments[pIdx];
    if (!im.isUsable) return;
    final remaining = p.totalLines - p.completedLines;
    final actualUse = linesToUse.clamp(0, im.availableLines.clamp(0, remaining));
    if (actualUse <= 0) return;
    _immunities[imIdx].usedLines += actualUse;
    _punishments[pIdx].completedLines += actualUse;
    _knownPunishmentProgress[punishmentId] = _punishments[pIdx].completedLines;
    await _immunitiesBox.put(immunityId, jsonEncode(_immunities[imIdx].toMap()));
    await _punishmentsBox.put(punishmentId, jsonEncode(_punishments[pIdx].toMap()));
    if (_firestore.isConnected) await _firestore.savePunishment(_punishments[pIdx]);
    notifyListeners();
  }

  int getTotalAvailableImmunity(String childId) {
    return _immunities.where((im) => im.childId == childId && im.isUsable).fold<int>(0, (sum, im) => sum + im.availableLines);
  }

  List<ImmunityLines> getUsableImmunitiesForChild(String childId) {
    return _immunities.where((im) => im.childId == childId && im.isUsable).toList();
  }

  List<ImmunityLines> getImmunitiesForChild(String childId) =>
      _immunities.where((im) => im.childId == childId).toList();

  // === NOTES ===
  Future<void> addNote(String childId, String text, {String authorName = 'Parent'}) async {
    final note = NoteModel(id: _uuid.v4(), childId: childId, text: text, authorName: authorName);
    _notes.insert(0, note);
    await _notesBox.put(note.id, jsonEncode(note.toMap()));
    if (_firestore.isConnected) await _firestore.saveNote(note);
    notifyListeners();
  }

  Future<void> updateNote(String noteId, String newText) async {
    final idx = _notes.indexWhere((n) => n.id == noteId);
    if (idx != -1) {
      _notes[idx].text = newText;
      await _notesBox.put(noteId, jsonEncode(_notes[idx].toMap()));
      if (_firestore.isConnected) await _firestore.saveNote(_notes[idx]);
      notifyListeners();
    }
  }

  Future<void> toggleNotePin(String noteId) async {
    final idx = _notes.indexWhere((n) => n.id == noteId);
    if (idx != -1) {
      _notes[idx].isPinned = !_notes[idx].isPinned;
      await _notesBox.put(noteId, jsonEncode(_notes[idx].toMap()));
      if (_firestore.isConnected) await _firestore.saveNote(_notes[idx]);
      notifyListeners();
    }
  }

  Future<void> removeNote(String noteId) async {
    _notes.removeWhere((n) => n.id == noteId);
    await _notesBox.delete(noteId);
    if (_firestore.isConnected) await _firestore.deleteNote(noteId);
    notifyListeners();
  }

  List<NoteModel> getNotesForChild(String childId) {
    final childNotes = _notes.where((n) => n.childId == childId).toList();
    childNotes.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      return b.createdAt.compareTo(a.createdAt);
    });
    return childNotes;
  }

  // === TRIBUNAL ===
  Future<TribunalCase> fileTribunalCase({
    required String title,
    required String description,
    required String plaintiffId,
    required String accusedId,
    String? prosecutionLawyerId,
    String? defenseLawyerId,
    List<String>? witnessIds,
    DateTime? scheduledDate,
  }) async {
    final tribunalCase = TribunalCase(
      id: _uuid.v4(),
      title: title,
      description: description,
      plaintiffId: plaintiffId,
      accusedId: accusedId,
      status: scheduledDate != null ? TribunalStatus.scheduled : TribunalStatus.filed,
      scheduledDate: scheduledDate,
    );

    // Ajouter les participants
    tribunalCase.participants.add(TribunalParticipant(childId: plaintiffId, role: TribunalRole.plaintiff));
    tribunalCase.participants.add(TribunalParticipant(childId: accusedId, role: TribunalRole.accused));

    if (prosecutionLawyerId != null) {
      tribunalCase.participants.add(TribunalParticipant(childId: prosecutionLawyerId, role: TribunalRole.prosecutionLawyer));
    }
    if (defenseLawyerId != null) {
      tribunalCase.participants.add(TribunalParticipant(childId: defenseLawyerId, role: TribunalRole.defenseLawyer));
    }
    if (witnessIds != null) {
      for (final wId in witnessIds) {
        tribunalCase.participants.add(TribunalParticipant(childId: wId, role: TribunalRole.witness));
      }
    }

    _tribunalCases.insert(0, tribunalCase);
    await _tribunalBox.put(tribunalCase.id, jsonEncode(tribunalCase.toMap()));
    notifyListeners();
    return tribunalCase;
  }

  Future<void> scheduleTribunalHearing(String caseId, DateTime date) async {
    final idx = _tribunalCases.indexWhere((t) => t.id == caseId);
    if (idx == -1) return;
    _tribunalCases[idx].scheduledDate = date;
    _tribunalCases[idx].status = TribunalStatus.scheduled;
    await _tribunalBox.put(caseId, jsonEncode(_tribunalCases[idx].toMap()));
    notifyListeners();
  }

  Future<void> startTribunalHearing(String caseId) async {
    final idx = _tribunalCases.indexWhere((t) => t.id == caseId);
    if (idx == -1) return;
    _tribunalCases[idx].status = TribunalStatus.inProgress;
    await _tribunalBox.put(caseId, jsonEncode(_tribunalCases[idx].toMap()));
    notifyListeners();
  }

  Future<void> startTribunalDeliberation(String caseId) async {
    final idx = _tribunalCases.indexWhere((t) => t.id == caseId);
    if (idx == -1) return;
    _tribunalCases[idx].status = TribunalStatus.deliberation;
    await _tribunalBox.put(caseId, jsonEncode(_tribunalCases[idx].toMap()));
    notifyListeners();
  }

  Future<void> addTestimony(String caseId, String childId, String testimony) async {
    final idx = _tribunalCases.indexWhere((t) => t.id == caseId);
    if (idx == -1) return;
    final pIdx = _tribunalCases[idx].participants.indexWhere((p) => p.childId == childId);
    if (pIdx != -1) {
      _tribunalCases[idx].participants[pIdx].testimony = testimony;
      await _tribunalBox.put(caseId, jsonEncode(_tribunalCases[idx].toMap()));
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
    final idx = _tribunalCases.indexWhere((t) => t.id == caseId);
    if (idx == -1) return;

    final tc = _tribunalCases[idx];
    tc.status = TribunalStatus.verdict;
    tc.verdict = verdict;
    tc.verdictReason = reason;
    tc.verdictDate = DateTime.now();
    tc.plaintiffPoints = plaintiffPoints;
    tc.accusedPoints = accusedPoints;

    // Appliquer points au plaignant
    if (plaintiffPoints != 0) {
      await addPoints(
        tc.plaintiffId,
        plaintiffPoints,
        'Tribunal: ${tc.title} - ${verdict == TribunalVerdict.guilty ? "Plainte validee" : verdict == TribunalVerdict.innocent ? "Plainte rejetee" : "Classe sans suite"}',
        'tribunal',
        isBonus: plaintiffPoints > 0,
      );
    }

    // Appliquer points a l accuse
    if (accusedPoints != 0) {
      await addPoints(
        tc.accusedId,
        accusedPoints,
        'Tribunal: ${tc.title} - ${verdict == TribunalVerdict.guilty ? "Reconnu coupable" : verdict == TribunalVerdict.innocent ? "Declare innocent" : "Classe sans suite"}',
        'tribunal',
        isBonus: accusedPoints > 0,
      );
    }

    // Appliquer points aux avocats
    if (lawyerPoints != null) {
      for (final entry in lawyerPoints.entries) {
        if (entry.value != 0) {
          final participant = tc.participants.where((p) => p.childId == entry.key).firstOrNull;
          final roleLabel = participant?.role == TribunalRole.prosecutionLawyer ? 'Avocat accusation' : 'Avocat defense';
          participant?.pointsAwarded = entry.value;
          await addPoints(
            entry.key,
            entry.value,
            'Tribunal: ${tc.title} - $roleLabel',
            'tribunal',
            isBonus: entry.value > 0,
          );
        }
      }
    }

    // Verifier et appliquer points aux temoins
    if (witnessVerified != null && witnessPoints != null) {
      for (final entry in witnessVerified.entries) {
        final wIdx = tc.participants.indexWhere((p) => p.childId == entry.key && p.role == TribunalRole.witness);
        if (wIdx != -1) {
          tc.participants[wIdx].testimonyVerified = entry.value;
          final pts = witnessPoints[entry.key] ?? 0;
          tc.participants[wIdx].pointsAwarded = pts;
          if (pts != 0) {
            await addPoints(
              entry.key,
              pts,
              'Tribunal: ${tc.title} - ${entry.value ? "Bon temoignage" : "Faux temoignage"}',
              'tribunal',
              isBonus: pts > 0,
            );
          }
        }
      }
    }

    await _tribunalBox.put(caseId, jsonEncode(tc.toMap()));
    notifyListeners();
  }

  Future<void> dismissTribunalCase(String caseId) async {
    final idx = _tribunalCases.indexWhere((t) => t.id == caseId);
    if (idx == -1) return;
    _tribunalCases[idx].status = TribunalStatus.closed;
    _tribunalCases[idx].verdict = TribunalVerdict.dismissed;
    _tribunalCases[idx].verdictDate = DateTime.now();
    await _tribunalBox.put(caseId, jsonEncode(_tribunalCases[idx].toMap()));
    notifyListeners();
  }

  Future<void> removeTribunalCase(String caseId) async {
    _tribunalCases.removeWhere((t) => t.id == caseId);
    await _tribunalBox.delete(caseId);
    notifyListeners();
  }

  TribunalCase? getTribunalCase(String caseId) {
    try { return _tribunalCases.firstWhere((t) => t.id == caseId); } catch (_) { return null; }
  }

  // === QUERIES ===
  List<HistoryEntry> getHistoryForChild(String childId) => _history.where((h) => h.childId == childId).toList();
  List<HistoryEntry> getHistoryForDate(DateTime date) => _history.where((h) => h.date.year == date.year && h.date.month == date.month && h.date.day == date.day).toList();
  List<GoalModel> getGoalsForChild(String childId) => _goals.where((g) => g.childId == childId).toList();
  List<PunishmentLines> getPunishmentsForChild(String childId) => _punishments.where((p) => p.childId == childId).toList();

  List<BadgeModel> getBadgesForChild(ChildModel child) =>
      allBadges.where((b) => child.badgeIds.contains(b.id)).toList();

  ChildModel? getChild(String id) {
    try { return _children.firstWhere((c) => c.id == id); } catch (_) { return null; }
  }

  Map<String, int> getWeeklyStats(String childId) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    final stats = <String, int>{};
    for (var i = 0; i < 7; i++) {
      final day = weekStart.add(Duration(days: i));
      final dayHistory = _history.where((h) => h.childId == childId && h.date.year == day.year && h.date.month == day.month && h.date.day == day.day && h.isBonus);
      int total = 0;
      for (var h in dayHistory) total += h.points;
      stats[days[i]] = total;
    }
    return stats;
  }

  Future<void> _saveAllLocal() async {
    await _historyBox.clear();
    for (var h in _history) await _historyBox.put(h.id, jsonEncode(h.toMap()));
    await _goalsBox.clear();
    for (var g in _goals) await _goalsBox.put(g.id, jsonEncode(g.toMap()));
    await _punishmentsBox.clear();
    for (var p in _punishments) await _punishmentsBox.put(p.id, jsonEncode(p.toMap()));
    await _immunitiesBox.clear();
    for (var im in _immunities) await _immunitiesBox.put(im.id, jsonEncode(im.toMap()));
    await _notesBox.clear();
    for (var n in _notes) await _notesBox.put(n.id, jsonEncode(n.toMap()));
    await _tribunalBox.clear();
    for (var t in _tribunalCases) await _tribunalBox.put(t.id, jsonEncode(t.toMap()));
  }
}
