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
import '../models/immunity_lines.dart';
import '../models/trade_model.dart';
import '../models/tribunal_model.dart';
import '../models/badge_model.dart';

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  String? _familyId;
  String? get familyId => _familyId;
  bool get isConnected => _familyId != null;

  String? _deviceId;
  String get deviceId => _deviceId ?? 'unknown';

  // ===== SUBSCRIPTIONS =====
  StreamSubscription? _childrenSub;
  StreamSubscription? _historySub;
  StreamSubscription? _goalsSub;
  StreamSubscription? _punishmentsSub;
  StreamSubscription? _notesSub;
  StreamSubscription? _immunitiesSub;
  StreamSubscription? _tradesSub;
  StreamSubscription? _tribunalSub;
  StreamSubscription? _badgesSub;
  StreamSubscription? _screenTimeSub;

  Timer? _keepAliveTimer;
  DateTime _lastDataReceived = DateTime.now();

  // ===== CALLBACKS =====
  void Function(List<ChildModel>, List<Map<String, dynamic>>)? onChildrenChanged;
  void Function(List<HistoryEntry>, List<Map<String, dynamic>>)? onHistoryChanged;
  void Function(List<GoalModel>, List<Map<String, dynamic>>)? onGoalsChanged;
  void Function(List<PunishmentLines>, List<Map<String, dynamic>>)? onPunishmentsChanged;
  void Function(List<NoteModel>)? onNotesChanged;
  void Function(List<ImmunityLines>)? onImmunitiesChanged;
  void Function(List<TradeModel>)? onTradesChanged;
  void Function(List<TribunalCase>)? onTribunalChanged;
  void Function(List<BadgeModel>)? onBadgesChanged;
  void Function(Map<String, dynamic>)? onScreenTimeChanged;

  // ===== INIT =====
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _familyId = prefs.getString('family_id');

      _deviceId = prefs.getString('device_id');
      if (_deviceId == null) {
        _deviceId = _generateDeviceId();
        await prefs.setString('device_id', _deviceId!);
      }

      if (_familyId != null) {
        _startListening();
        _startKeepAlive();
        if (kDebugMode) debugPrint('FirestoreService: auto-reconnected to family $_familyId');
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

  // ===== CREATE / JOIN / DISCONNECT =====
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
    _startKeepAlive();
    return code;
  }

  Future<bool> joinFamily(String code) async {
    try {
      final cleanCode = code.toUpperCase().trim();
      if (cleanCode.length < 4 || cleanCode.length > 10) return false;

      final query = await _db
          .collection('families')
          .where('code', isEqualTo: cleanCode)
          .limit(1)
          .get();

      if (query.docs.isEmpty) return false;

      final doc = query.docs.first;
      _familyId = doc.id;

      await doc.reference.update({
        'memberCount': FieldValue.increment(1),
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('family_id', _familyId!);
      await prefs.setString('family_code', cleanCode);
      _startListening();
      _startKeepAlive();
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
    _stopKeepAlive();
    _familyId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('family_id');
    await prefs.remove('family_code');
  }

  void reconnect() {
    if (_familyId == null) return;
    if (kDebugMode) debugPrint('FirestoreService: reconnecting listeners...');
    _stopListening();
    _startListening();
    _lastDataReceived = DateTime.now();
  }

  // ===== KEEP ALIVE =====
  void _startKeepAlive() {
    _stopKeepAlive();
    _lastDataReceived = DateTime.now();
    _keepAliveTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _checkConnection();
    });
  }

  void _stopKeepAlive() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
  }

  void _checkConnection() {
    if (_familyId == null) return;
    final secondsSinceLastData = DateTime.now().difference(_lastDataReceived).inSeconds;
    if (secondsSinceLastData > 45) {
      if (kDebugMode) debugPrint('KeepAlive: No data for 45s, reconnecting...');
      reconnect();
    }
    _db.collection('families').doc(_familyId).get().then((_) {}).catchError((e) {
      if (kDebugMode) debugPrint('KeepAlive ping failed: $e, reconnecting...');
      reconnect();
    });
  }

  void _markDataReceived() {
    _lastDataReceived = DateTime.now();
  }

  // ===== REAL-TIME LISTENERS =====
  void _startListening() {
    if (_familyId == null) return;
    final fRef = _db.collection('families').doc(_familyId);

    // Children
    _childrenSub = fRef.collection('children').snapshots().listen((snapshot) {
      _markDataReceived();
      final children = <ChildModel>[];
      final rawList = <Map<String, dynamic>>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        children.add(ChildModel.fromMap(data));
        rawList.add(Map<String, dynamic>.from(data));
      }
      onChildrenChanged?.call(children, rawList);
    }, onError: (e) {
      if (kDebugMode) debugPrint('Children listener error: $e');
      Future.delayed(const Duration(seconds: 5), () => reconnect());
    });

    // History
    _historySub = fRef.collection('history').snapshots().listen((snapshot) {
      _markDataReceived();
      final history = <HistoryEntry>[];
      final rawList = <Map<String, dynamic>>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        history.add(HistoryEntry.fromMap(data));
        rawList.add(Map<String, dynamic>.from(data));
      }
      history.sort((a, b) => b.date.compareTo(a.date));
      onHistoryChanged?.call(history, rawList);
    }, onError: (e) {
      if (kDebugMode) debugPrint('History listener error: $e');
      Future.delayed(const Duration(seconds: 5), () => reconnect());
    });

    // Goals
    _goalsSub = fRef.collection('goals').snapshots().listen((snapshot) {
      _markDataReceived();
      final goals = <GoalModel>[];
      final rawList = <Map<String, dynamic>>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        goals.add(GoalModel.fromMap(data));
        rawList.add(Map<String, dynamic>.from(data));
      }
      onGoalsChanged?.call(goals, rawList);
    }, onError: (e) {
      if (kDebugMode) debugPrint('Goals listener error: $e');
      Future.delayed(const Duration(seconds: 5), () => reconnect());
    });

    // Punishments
    _punishmentsSub = fRef.collection('punishments').snapshots().listen((snapshot) {
      _markDataReceived();
      final punishments = <PunishmentLines>[];
      final rawList = <Map<String, dynamic>>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        punishments.add(PunishmentLines.fromMap(data));
        rawList.add(Map<String, dynamic>.from(data));
      }
      onPunishmentsChanged?.call(punishments, rawList);
    }, onError: (e) {
      if (kDebugMode) debugPrint('Punishments listener error: $e');
      Future.delayed(const Duration(seconds: 5), () => reconnect());
    });

    // Notes
    _notesSub = fRef.collection('notes').snapshots().listen((snapshot) {
      _markDataReceived();
      final notes = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return NoteModel.fromMap(data);
      }).toList();
      notes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      onNotesChanged?.call(notes);
    }, onError: (e) {
      if (kDebugMode) debugPrint('Notes listener error: $e');
      Future.delayed(const Duration(seconds: 5), () => reconnect());
    });

    // Immunities
    _immunitiesSub = fRef.collection('immunities').snapshots().listen((snapshot) {
      _markDataReceived();
      final immunities = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return ImmunityLines.fromMap(data);
      }).toList();
      onImmunitiesChanged?.call(immunities);
    }, onError: (e) {
      if (kDebugMode) debugPrint('Immunities listener error: $e');
      Future.delayed(const Duration(seconds: 5), () => reconnect());
    });

    // Trades
    _tradesSub = fRef.collection('trades').snapshots().listen((snapshot) {
      _markDataReceived();
      final trades = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return TradeModel.fromMap(data);
      }).toList();
      trades.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      onTradesChanged?.call(trades);
    }, onError: (e) {
      if (kDebugMode) debugPrint('Trades listener error: $e');
      Future.delayed(const Duration(seconds: 5), () => reconnect());
    });

    // Tribunal
    _tribunalSub = fRef.collection('tribunal').snapshots().listen((snapshot) {
      _markDataReceived();
      final cases = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return TribunalCase.fromMap(data);
      }).toList();
      onTribunalChanged?.call(cases);
    }, onError: (e) {
      if (kDebugMode) debugPrint('Tribunal listener error: $e');
      Future.delayed(const Duration(seconds: 5), () => reconnect());
    });

    // Custom Badges
    _badgesSub = fRef.collection('custom_badges').snapshots().listen((snapshot) {
      _markDataReceived();
      final badges = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return BadgeModel.fromMap(data);
      }).toList();
      onBadgesChanged?.call(badges);
    }, onError: (e) {
      if (kDebugMode) debugPrint('Badges listener error: $e');
      Future.delayed(const Duration(seconds: 5), () => reconnect());
    });

    // Screen Time
    _screenTimeSub = fRef.collection('screen_time').snapshots().listen((snapshot) {
      _markDataReceived();
      final Map<String, dynamic> screenData = {};
      for (final doc in snapshot.docs) {
        screenData[doc.id] = doc.data()['value'];
      }
      onScreenTimeChanged?.call(screenData);
    }, onError: (e) {
      if (kDebugMode) debugPrint('ScreenTime listener error: $e');
      Future.delayed(const Duration(seconds: 5), () => reconnect());
    });

    if (kDebugMode) debugPrint('All Firestore listeners started (10 collections)');
  }

  void _stopListening() {
    _childrenSub?.cancel();
    _historySub?.cancel();
    _goalsSub?.cancel();
    _punishmentsSub?.cancel();
    _notesSub?.cancel();
    _immunitiesSub?.cancel();
    _tradesSub?.cancel();
    _tribunalSub?.cancel();
    _badgesSub?.cancel();
    _screenTimeSub?.cancel();
    _childrenSub = null;
    _historySub = null;
    _goalsSub = null;
    _punishmentsSub = null;
    _notesSub = null;
    _immunitiesSub = null;
    _tradesSub = null;
    _tribunalSub = null;
    _badgesSub = null;
    _screenTimeSub = null;
  }
  // ===== WRITE: CHILDREN =====
  Future<void> saveChild(ChildModel child) async {
    if (_familyId == null) return;
    final data = child.toMap();
    data['lastModifiedBy'] = deviceId;
    await _db.collection('families').doc(_familyId).collection('children').doc(child.id).set(data);
  }

  Future<void> deleteChild(String childId) async {
    if (_familyId == null) return;
    await _db.collection('families').doc(_familyId).collection('children').doc(childId).delete();
    final collections = ['history', 'goals', 'punishments', 'immunities', 'trades', 'tribunal'];
    for (final col in collections) {
      final docs = await _db.collection('families').doc(_familyId).collection(col).where('childId', isEqualTo: childId).get();
      for (final doc in docs.docs) await doc.reference.delete();
    }
    // Trades where child is buyer
    final buyerTrades = await _db.collection('families').doc(_familyId).collection('trades').where('toChildId', isEqualTo: childId).get();
    for (final doc in buyerTrades.docs) await doc.reference.delete();
    // Trades where child is seller
    final sellerTrades = await _db.collection('families').doc(_familyId).collection('trades').where('fromChildId', isEqualTo: childId).get();
    for (final doc in sellerTrades.docs) await doc.reference.delete();
  }

  // ===== WRITE: HISTORY =====
  Future<void> saveHistoryEntry(HistoryEntry entry) async {
    if (_familyId == null) return;
    final data = entry.toMap();
    data['deviceId'] = deviceId;
    await _db.collection('families').doc(_familyId).collection('history').doc(entry.id).set(data);
  }

  Future<void> clearAllHistory() async {
    if (_familyId == null) return;
    final docs = await _db.collection('families').doc(_familyId).collection('history').get();
    for (final doc in docs.docs) await doc.reference.delete();
  }

  // ===== WRITE: GOALS =====
  Future<void> saveGoal(GoalModel goal) async {
    if (_familyId == null) return;
    final data = goal.toMap();
    data['lastModifiedBy'] = deviceId;
    await _db.collection('families').doc(_familyId).collection('goals').doc(goal.id).set(data);
  }

  Future<void> deleteGoal(String goalId) async {
    if (_familyId == null) return;
    await _db.collection('families').doc(_familyId).collection('goals').doc(goalId).delete();
  }

  // ===== WRITE: PUNISHMENTS =====
  Future<void> savePunishment(PunishmentLines p) async {
    if (_familyId == null) return;
    final data = p.toMap();
    data['lastModifiedBy'] = deviceId;
    await _db.collection('families').doc(_familyId).collection('punishments').doc(p.id).set(data);
  }

  Future<void> deletePunishment(String pId) async {
    if (_familyId == null) return;
    await _db.collection('families').doc(_familyId).collection('punishments').doc(pId).delete();
  }

  // ===== WRITE: NOTES =====
  Future<void> saveNote(NoteModel note) async {
    if (_familyId == null) return;
    final data = note.toMap();
    data['lastModifiedBy'] = deviceId;
    await _db.collection('families').doc(_familyId).collection('notes').doc(note.id).set(data);
  }

  Future<void> deleteNote(String noteId) async {
    if (_familyId == null) return;
    await _db.collection('families').doc(_familyId).collection('notes').doc(noteId).delete();
  }

  // ===== WRITE: IMMUNITIES =====
  Future<void> saveImmunity(ImmunityLines im) async {
    if (_familyId == null) return;
    final data = im.toMap();
    data['lastModifiedBy'] = deviceId;
    await _db.collection('families').doc(_familyId).collection('immunities').doc(im.id).set(data);
  }

  Future<void> deleteImmunity(String imId) async {
    if (_familyId == null) return;
    await _db.collection('families').doc(_familyId).collection('immunities').doc(imId).delete();
  }

  // ===== WRITE: TRADES =====
  Future<void> saveTrade(TradeModel trade) async {
    if (_familyId == null) return;
    final data = trade.toMap();
    data['lastModifiedBy'] = deviceId;
    await _db.collection('families').doc(_familyId).collection('trades').doc(trade.id).set(data);
  }

  Future<void> deleteTrade(String tradeId) async {
    if (_familyId == null) return;
    await _db.collection('families').doc(_familyId).collection('trades').doc(tradeId).delete();
  }

  // ===== WRITE: TRIBUNAL =====
  Future<void> saveTribunalCase(TribunalCase tc) async {
    if (_familyId == null) return;
    final data = tc.toMap();
    data['lastModifiedBy'] = deviceId;
    await _db.collection('families').doc(_familyId).collection('tribunal').doc(tc.id).set(data);
  }

  Future<void> deleteTribunalCase(String tcId) async {
    if (_familyId == null) return;
    await _db.collection('families').doc(_familyId).collection('tribunal').doc(tcId).delete();
  }

  // ===== WRITE: CUSTOM BADGES =====
  Future<void> saveCustomBadge(BadgeModel badge) async {
    if (_familyId == null) return;
    final data = badge.toMap();
    data['lastModifiedBy'] = deviceId;
    await _db.collection('families').doc(_familyId).collection('custom_badges').doc(badge.id).set(data);
  }

  Future<void> deleteCustomBadge(String badgeId) async {
    if (_familyId == null) return;
    await _db.collection('families').doc(_familyId).collection('custom_badges').doc(badgeId).delete();
  }

  // ===== WRITE: SCREEN TIME =====
  Future<void> saveScreenTimeValue(String key, dynamic value) async {
    if (_familyId == null) return;
    await _db.collection('families').doc(_familyId).collection('screen_time').doc(key).set({
      'value': value,
      'lastModifiedBy': deviceId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ===== RESET =====
  Future<void> resetAllScores() async {
    if (_familyId == null) return;
    final docs = await _db.collection('families').doc(_familyId).collection('children').get();
    for (final doc in docs.docs) {
      await doc.reference.update({'points': 0, 'level': 1, 'badgeIds': [], 'lastModifiedBy': deviceId});
    }
  }

  // ===== UPLOAD ALL LOCAL DATA =====
  Future<void> uploadAllData({
    required List<ChildModel> children,
    required List<HistoryEntry> history,
    required List<GoalModel> goals,
    required List<PunishmentLines> punishments,
    required List<NoteModel> notes,
    required List<ImmunityLines> immunities,
    required List<TradeModel> trades,
    required List<TribunalCase> tribunalCases,
    required List<BadgeModel> customBadges,
    required Map<String, dynamic> screenTimeData,
  }) async {
    if (_familyId == null) return;
    final fRef = _db.collection('families').doc(_familyId);

    // Use multiple batches (Firestore limit = 500 ops per batch)
    var batch = _db.batch();
    int opCount = 0;

    Future<void> commitIfNeeded() async {
      if (opCount >= 450) {
        await batch.commit();
        batch = _db.batch();
        opCount = 0;
      }
    }

    for (final child in children) {
      final data = child.toMap();
      data['lastModifiedBy'] = deviceId;
      batch.set(fRef.collection('children').doc(child.id), data);
      opCount++;
      await commitIfNeeded();
    }

    for (final h in history) {
      final data = h.toMap();
      data['deviceId'] = deviceId;
      batch.set(fRef.collection('history').doc(h.id), data);
      opCount++;
      await commitIfNeeded();
    }

    for (final g in goals) {
      final data = g.toMap();
      data['lastModifiedBy'] = deviceId;
      batch.set(fRef.collection('goals').doc(g.id), data);
      opCount++;
      await commitIfNeeded();
    }

    for (final p in punishments) {
      final data = p.toMap();
      data['lastModifiedBy'] = deviceId;
      batch.set(fRef.collection('punishments').doc(p.id), data);
      opCount++;
      await commitIfNeeded();
    }

    for (final n in notes) {
      final data = n.toMap();
      data['lastModifiedBy'] = deviceId;
      batch.set(fRef.collection('notes').doc(n.id), data);
      opCount++;
      await commitIfNeeded();
    }

    for (final im in immunities) {
      final data = im.toMap();
      data['lastModifiedBy'] = deviceId;
      batch.set(fRef.collection('immunities').doc(im.id), data);
      opCount++;
      await commitIfNeeded();
    }

    for (final t in trades) {
      final data = t.toMap();
      data['lastModifiedBy'] = deviceId;
      batch.set(fRef.collection('trades').doc(t.id), data);
      opCount++;
      await commitIfNeeded();
    }

    for (final tc in tribunalCases) {
      final data = tc.toMap();
      data['lastModifiedBy'] = deviceId;
      batch.set(fRef.collection('tribunal').doc(tc.id), data);
      opCount++;
      await commitIfNeeded();
    }

    for (final b in customBadges) {
      final data = b.toMap();
      data['lastModifiedBy'] = deviceId;
      batch.set(fRef.collection('custom_badges').doc(b.id), data);
      opCount++;
      await commitIfNeeded();
    }

    for (final entry in screenTimeData.entries) {
      batch.set(fRef.collection('screen_time').doc(entry.key), {
        'value': entry.value,
        'lastModifiedBy': deviceId,
      });
      opCount++;
      await commitIfNeeded();
    }

    if (opCount > 0) {
      await batch.commit();
    }

    if (kDebugMode) debugPrint('All local data uploaded to Firestore');
  }

  // Legacy methods for backward compatibility
  Future<void> uploadLocalData({
    required List<ChildModel> children,
    required List<HistoryEntry> history,
    required List<GoalModel> goals,
    required List<PunishmentLines> punishments,
  }) async {
    await uploadAllData(
      children: children,
      history: history,
      goals: goals,
      punishments: punishments,
      notes: [],
      immunities: [],
      trades: [],
      tribunalCases: [],
      customBadges: [],
      screenTimeData: {},
    );
  }

  Future<void> uploadNotes(List<NoteModel> notes) async {
    if (_familyId == null) return;
    final batch = _db.batch();
    final fRef = _db.collection('families').doc(_familyId);
    for (final n in notes) {
      final data = n.toMap();
      data['lastModifiedBy'] = deviceId;
      batch.set(fRef.collection('notes').doc(n.id), data);
    }
    await batch.commit();
  }

  // ===== FORCE REFRESH =====
  Future<void> forceRefresh() async {
    if (_familyId == null) return;
    if (kDebugMode) debugPrint('FirestoreService: force refresh all data...');
    try {
      final fRef = _db.collection('families').doc(_familyId);
      final opts = const GetOptions(source: Source.server);

      final childrenSnap = await fRef.collection('children').get(opts);
      final children = <ChildModel>[];
      final childrenRaw = <Map<String, dynamic>>[];
      for (final doc in childrenSnap.docs) {
        final data = doc.data(); data['id'] = doc.id;
        children.add(ChildModel.fromMap(data));
        childrenRaw.add(Map<String, dynamic>.from(data));
      }
      onChildrenChanged?.call(children, childrenRaw);

      final historySnap = await fRef.collection('history').get(opts);
      final history = <HistoryEntry>[];
      final historyRaw = <Map<String, dynamic>>[];
      for (final doc in historySnap.docs) {
        final data = doc.data(); data['id'] = doc.id;
        history.add(HistoryEntry.fromMap(data));
        historyRaw.add(Map<String, dynamic>.from(data));
      }
      history.sort((a, b) => b.date.compareTo(a.date));
      onHistoryChanged?.call(history, historyRaw);

      final goalsSnap = await fRef.collection('goals').get(opts);
      final goals = <GoalModel>[];
      final goalsRaw = <Map<String, dynamic>>[];
      for (final doc in goalsSnap.docs) {
        final data = doc.data(); data['id'] = doc.id;
        goals.add(GoalModel.fromMap(data));
        goalsRaw.add(Map<String, dynamic>.from(data));
      }
      onGoalsChanged?.call(goals, goalsRaw);

      final punishmentsSnap = await fRef.collection('punishments').get(opts);
      final punishments = <PunishmentLines>[];
      final punishmentsRaw = <Map<String, dynamic>>[];
      for (final doc in punishmentsSnap.docs) {
        final data = doc.data(); data['id'] = doc.id;
        punishments.add(PunishmentLines.fromMap(data));
        punishmentsRaw.add(Map<String, dynamic>.from(data));
      }
      onPunishmentsChanged?.call(punishments, punishmentsRaw);

      final notesSnap = await fRef.collection('notes').get(opts);
      final notes = notesSnap.docs.map((doc) {
        final data = doc.data(); data['id'] = doc.id;
        return NoteModel.fromMap(data);
      }).toList();
      notes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      onNotesChanged?.call(notes);

      final immunitiesSnap = await fRef.collection('immunities').get(opts);
      final immunities = immunitiesSnap.docs.map((doc) {
        final data = doc.data(); data['id'] = doc.id;
        return ImmunityLines.fromMap(data);
      }).toList();
      onImmunitiesChanged?.call(immunities);

      final tradesSnap = await fRef.collection('trades').get(opts);
      final trades = tradesSnap.docs.map((doc) {
        final data = doc.data(); data['id'] = doc.id;
        return TradeModel.fromMap(data);
      }).toList();
      trades.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      onTradesChanged?.call(trades);

      final tribunalSnap = await fRef.collection('tribunal').get(opts);
      final cases = tribunalSnap.docs.map((doc) {
        final data = doc.data(); data['id'] = doc.id;
        return TribunalCase.fromMap(data);
      }).toList();
      onTribunalChanged?.call(cases);

      final badgesSnap = await fRef.collection('custom_badges').get(opts);
      final badges = badgesSnap.docs.map((doc) {
        final data = doc.data(); data['id'] = doc.id;
        return BadgeModel.fromMap(data);
      }).toList();
      onBadgesChanged?.call(badges);

      final screenTimeSnap = await fRef.collection('screen_time').get(opts);
      final Map<String, dynamic> screenData = {};
      for (final doc in screenTimeSnap.docs) {
        screenData[doc.id] = doc.data()['value'];
      }
      onScreenTimeChanged?.call(screenData);

      _markDataReceived();
      if (kDebugMode) debugPrint('Force refresh completed (10 collections)');
    } catch (e) {
      if (kDebugMode) debugPrint('Force refresh error: $e');
      reconnect();
    }
  }
}
