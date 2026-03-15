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
import '../services/firestore_service.dart';
import '../services/notification_service.dart';

class FamilyProvider extends ChangeNotifier {
  List<ChildModel> _children = [];
  List<HistoryEntry> _history = [];
  List<GoalModel> _goals = [];
  List<PunishmentLines> _punishments = [];
  List<ImmunityLines> _immunities = [];
  List<NoteModel> _notes = [];
  final _uuid = const Uuid();
  final _firestore = FirestoreService();

  late Box _childrenBox;
  late Box _historyBox;
  late Box _goalsBox;
  late Box _punishmentsBox;
  late Box _immunitiesBox;
  late Box _notesBox;

  List<ChildModel> get children => _children;
  List<HistoryEntry> get history => _history;
  List<GoalModel> get goals => _goals;
  List<PunishmentLines> get punishments => _punishments;
  List<ImmunityLines> get immunities => _immunities;
  List<NoteModel> get notes => _notes;

  bool get isSyncEnabled => _firestore.isConnected;
  String? get familyId => _firestore.familyId;

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
    _loadLocalData();

    _firestore.onChildrenChanged = _onCloudChildrenChanged;
    _firestore.onHistoryChanged = _onCloudHistoryChanged;
    _firestore.onGoalsChanged = _onCloudGoalsChanged;
    _firestore.onPunishmentsChanged = _onCloudPunishmentsChanged;
    _firestore.onNotesChanged = _onCloudNotesChanged;
    await _firestore.init();
  }

  void _loadLocalData() {
    _children = _childrenBox.values
        .map((e) => ChildModel.fromMap(Map<String, dynamic>.from(jsonDecode(e))))
        .toList();
    _history = _historyBox.values
        .map((e) => HistoryEntry.fromMap(Map<String, dynamic>.from(jsonDecode(e))))
        .toList();
    _goals = _goalsBox.values
        .map((e) => GoalModel.fromMap(Map<span class="cursor">█</span>
