import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/child_model.dart';
import '../models/history_entry.dart';
import '../models/goal_model.dart';
import '../models/punishment_lines.dart';
import '../models/note_model.dart';

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  String? _familyId;
  String? get familyId => _familyId;
  bool get isConnected => _familyId != null;

  // Unique device identifier to filter own changes
  String? _deviceId;
  String get deviceId => _deviceId ?? 'unknown';

  StreamSubscription? _childrenSub;
  StreamSubscription? _historySub;
  StreamSubscription? _goalsSub;
  StreamSubscription? _punishmentsSub;
  StreamSubscription? _notesSub;

  void Function(List<ChildModel>)? onChildrenChanged;
  void Function(List<HistoryEntry>)? onHistoryChanged;
  void Function(List<GoalModel>)? onGoalsChanged;
  void Function(List<PunishmentLines>)? onPunishmentsChanged;
  void Function(List<NoteModel>)? onNotesChanged;

  // NEW: callbacks that also pass the deviceId of who made the change
  void Function(List<Map<String, dynamic>>)? onHistoryRawChanged;
  void Function(List<Map<String, dynamic>>)? onPunishmentsRawChanged;
  void Function(List<Map<String, dynamic>>)? onGoalsRawChanged;
  void Function(List<Map<String, dynamic>>)? onChildrenRawChanged;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _familyId = prefs.getString('family_id');

      // Generate or retrieve unique device ID
      _deviceId = prefs.getString('device_id');
      if (_deviceId == null) {
        _deviceId = _generateDeviceId();
        await prefs.setString('device_id', _deviceId!);
      }

      if (_familyId != null) {
        _startListening();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('FirestoreService init error: $e');
    }
  }

  String _generateDeviceId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rng = Random();
    return List.generate(16, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  String _generateFamilyCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random();
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  Future<bool> isCodeAvailable(String code) async {
    final query = await _db
        .collection('families')
        .where('code', isEqualTo: code.toUpperCase().trim())
        .limit(1)
        .get();
    return query.docs.isEmpty;
  }

  Future<String> createFamily({String? customCode}) async {
    String code;
    if (customCode != null && customCode.trim().length >= 4) {
      code = customCode.toUpperCase().trim();
      final available = await isCodeAvailable(code);
      if (!available) {
        throw Exception('Ce code est deja utilise. Choisissez-en un autre.');
      }
    } else {
      code = _generateFamilyCode();
    }
    final docRef = await _db.collection('families').add({
      'code': code,
      'createdAt': FieldValue.serverTimestamp(),
      'memberCount': 1,
    });
    _familyId = docRef.id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('family_id', _familyId!);
    await prefs.setString('family_code', code);
    _startListening();
    return code;
  }

  Future<bool> joinFamily(String code) async {
    try {
      final cleanCode = code.toUpperCase().trim();
      if (cleanCode.length < 4 || cleanCode.length > 10) {
        if (kDebugMode) debugPrint('joinFamily: code length invalid: ${cleanCode.length}');
        return false;
      }
      if (kDebugMode) debugPrint('joinFamily: searching for code "$cleanCode"...');
      final query = await _db
          .collection('families')
          .where('code', isEqualTo: cleanCode)
          .limit(1)
          .get();
      if (kDebugMode) debugPrint('joinFamily: query returned ${query.docs.length} results');
      if (query.docs.isEmpty) {
        if (kDebugMode) debugPrint('joinFamily: code not found');
        return false;
      }
      final doc = query.docs.first;
      _familyId = doc.id;
      if (kDebugMode) debugPrint('joinFamily: found family $_familyId');
      await doc.reference.update({
        'memberCount': FieldValue.increment(1),
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('family_id', _familyId!);
      await prefs.setString('family_code', cleanCode);
      _startListening();
      if (kDebugMode) debugPrint('joinFamily: SUCCESS - connected to family');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('joinFamily ERROR: $e');
      rethrow;
    }
  }

  Future<String?> getFamilyCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('family_code');
  }

  Future<void> disconnectFamily() async {
    _stopListening();
    _familyId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('family_id');
    await prefs.remove('family_code');
  }

  // ===== REAL-TIME LISTENERS =====

  void _startListening() {
    if (_familyId == null) return;

    _childrenSub = _db
        .collection('families')
        .doc(_familyId)
        .collection('children')
        .snapshots()
        .listen((snapshot) {
      final children = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return ChildModel.fromMap(data);
      }).toList();

      // Also send raw data with deviceId info
      final rawList = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      onChildrenChanged?.call(children);
      onChildrenRawChanged?.call(rawList);
    }, onError: (e) {
      if (kDebugMode) debugPrint('Children listener error: $e');
    });

    _historySub = _db
        .collection('families')
        .doc(_familyId)
        .collection('history')
        .snapshots()
        .listen((snapshot) {
      final history = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return HistoryEntry.fromMap(data);
      }).toList();
      history.sort((a, b) => b.date.compareTo(a.date));

      final rawList = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      onHistoryChanged?.call(history);
      onHistoryRawChanged?.call(rawList);
    }, onError: (e) {
      if (kDebugMode) debugPrint('History listener error: $e');
    });

    _goalsSub = _db
        .collection('families')
        .doc(_familyId)
        .collection('goals')
        .snapshots()
        .listen((snapshot) {
      final goals = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return GoalModel.fromMap(data);
      }).toList();

      final rawList = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      onGoalsChanged?.call(goals);
      onGoalsRawChanged?.call(rawList);
    }, onError: (e) {
      if (kDebugMode) debugPrint('Goals listener error: $e');
    });

    _punishmentsSub = _db
        .collection('families')
        .doc(_familyId)
        .collection('punishments')
        .snapshots()
        .listen((snapshot) {
      final punishments = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return PunishmentLines.fromMap(data);
      }).toList();

      final rawList = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      onPunishmentsChanged?.call(punishments);
      onPunishmentsRawChanged?.call(rawList);
    }, onError: (e) {
      if (kDebugMode) debugPrint('Punishments listener error: $e');
    });

    _notesSub = _db
        .collection('families')
        .doc(_familyId)
        .collection('notes')
        .snapshots()
        .listen((snapshot) {
      final notes = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return NoteModel.fromMap(data);
      }).toList();
      notes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      onNotesChanged?.call(notes);
    }, onError: (e) {
      if (kDebugMode) debugPrint('Notes listener error: $e');
    });
  }

  void _stopListening() {
    _childrenSub?.cancel();
    _historySub?.cancel();
    _goalsSub?.cancel();
    _punishmentsSub?.cancel();
    _notesSub?.cancel();
  }

  // ===== WRITE OPERATIONS (now include deviceId) =====

  Future<void> saveChild(ChildModel child) async {
    if (_familyId == null) return;
    final data = child.toMap();
    data['lastModifiedBy'] = deviceId;
    await _db
        .collection('families')
        .doc(_familyId)
        .collection('children')
        .doc(child.id)
        .set(data);
  }

  Future<void> deleteChild(String childId) async {
    if (_familyId == null) return;
    await _db
        .collection('families')
        .doc(_familyId)
        .collection('children')
        .doc(childId)
        .delete();

    final historyDocs = await _db
        .collection('families')
        .doc(_familyId)
        .collection('history')
        .where('childId', isEqualTo: childId)
        .get();
    for (final doc in historyDocs.docs) await doc.reference.delete();

    final goalDocs = await _db
        .collection('families')
        .doc(_familyId)
        .collection('goals')
        .where('childId', isEqualTo: childId)
        .get();
    for (final doc in goalDocs.docs) await doc.reference.delete();

    final punishmentDocs = await _db
        .collection('families')
        .doc(_familyId)
        .collection('punishments')
        .where('childId', isEqualTo: childId)
        .get();
    for (final doc in punishmentDocs.docs) await doc.reference.delete();
  }

  Future<void> saveHistoryEntry(HistoryEntry entry) async {
    if (_familyId == null) return;
    final data = entry.toMap();
    data['deviceId'] = deviceId;
    await _db
        .collection('families')
        .doc(_familyId)
        .collection('history')
        .doc(entry.id)
        .set(data);
  }

  Future<void> saveGoal(GoalModel goal) async {
    if (_familyId == null) return;
    final data = goal.toMap();
    data['lastModifiedBy'] = deviceId;
    await _db
        .collection('families')
        .doc(_familyId)
        .collection('goals')
        .doc(goal.id)
        .set(data);
  }

  Future<void> deleteGoal(String goalId) async {
    if (_familyId == null) return;
    await _db
        .collection('families')
        .doc(_familyId)
        .collection('goals')
        .doc(goalId)
        .delete();
  }

  Future<void> savePunishment(PunishmentLines p) async {
    if (_familyId == null) return;
    final data = p.toMap();
    data['lastModifiedBy'] = deviceId;
    await _db
        .collection('families')
        .doc(_familyId)
        .collection('punishments')
        .doc(p.id)
        .set(data);
  }

  Future<void> deletePunishment(String pId) async {
    if (_familyId == null) return;
    await _db
        .collection('families')
        .doc(_familyId)
        .collection('punishments')
        .doc(pId)
        .delete();
  }

  Future<void> saveNote(NoteModel note) async {
    if (_familyId == null) return;
    final data = note.toMap();
    data['lastModifiedBy'] = deviceId;
    await _db
        .collection('families')
        .doc(_familyId)
        .collection('notes')
        .doc(note.id)
        .set(data);
  }

  Future<void> deleteNote(String noteId) async {
    if (_familyId == null) return;
    await _db
        .collection('families')
        .doc(_familyId)
        .collection('notes')
        .doc(noteId)
        .delete();
  }

  Future<void> clearAllHistory() async {
    if (_familyId == null) return;
    final docs = await _db
        .collection('families')
        .doc(_familyId)
        .collection('history')
        .get();
    for (final doc in docs.docs) await doc.reference.delete();
  }

  Future<void> resetAllScores() async {
    if (_familyId == null) return;
    final docs = await _db
        .collection('families')
        .doc(_familyId)
        .collection('children')
        .get();
    for (final doc in docs.docs) {
      await doc.reference.update({
        'points': 0,
        'level': 1,
        'badgeIds': [],
        'lastModifiedBy': deviceId,
      });
    }
  }

  Future<void> uploadLocalData({
    required List<ChildModel> children,
    required List<HistoryEntry> history,
    required List<GoalModel> goals,
    required List<PunishmentLines> punishments,
  }) async {
    if (_familyId == null) return;
    final batch = _db.batch();
    final familyRef = _db.collection('families').doc(_familyId);

    for (final child in children) {
      final data = child.toMap();
      data['lastModifiedBy'] = deviceId;
      batch.set(familyRef.collection('children').doc(child.id), data);
    }
    for (final h in history) {
      final data = h.toMap();
      data['deviceId'] = deviceId;
      batch.set(familyRef.collection('history').doc(h.id), data);
    }
    for (final g in goals) {
      final data = g.toMap();
      data['lastModifiedBy'] = deviceId;
      batch.set(familyRef.collection('goals').doc(g.id), data);
    }
    for (final p in punishments) {
      final data = p.toMap();
      data['lastModifiedBy'] = deviceId;
      batch.set(familyRef.collection('punishments').doc(p.id), data);
    }
    await batch.commit();
  }

  Future<void> uploadNotes(List<NoteModel> notes) async {
    if (_familyId == null) return;
    final batch = _db.batch();
    final familyRef = _db.collection('families').doc(_familyId);
    for (final n in notes) {
      final data = n.toMap();
      data['lastModifiedBy'] = deviceId;
      batch.set(familyRef.collection('notes').doc(n.id), data);
    }
    await batch.commit();
  }
}
