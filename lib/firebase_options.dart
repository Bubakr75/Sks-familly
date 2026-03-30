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
  String? get familyId  => _familyId;
  bool get isConnected  => _familyId != null;

  String? _deviceId;
  String get deviceId => _deviceId ?? 'unknown';

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

  Timer?    _keepAliveTimer;
  DateTime  _lastDataReceived = DateTime.now();

  void Function(List<ChildModel>,      List<Map<String, dynamic>>)? onChildrenChanged;
  void Function(List<HistoryEntry>,    List<Map<String, dynamic>>)? onHistoryChanged;
  void Function(List<GoalModel>,       List<Map<String, dynamic>>)? onGoalsChanged;
  void Function(List<PunishmentLines>, List<Map<String, dynamic>>)? onPunishmentsChanged;
  void Function(List<NoteModel>)?       onNotesChanged;
  void Function(List<ImmunityLines>)?   onImmunitiesChanged;
  void Function(List<TradeModel>)?      onTradesChanged;
  void Function(List<TribunalCase>)?    onTribunalChanged;
  void Function(List<BadgeModel>)?      onBadgesChanged;
  void Function(Map<String, dynamic>)?  onScreenTimeChanged;

  // ─── Init ────────────────────────────────────────────────────
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
      }
    } catch (e) {
      if (kDebugMode) debugPrint('FirestoreService init error: $e');
    }
  }

  // ─── Dispose ────────────────────────────────────────────────
  void dispose() {
    _stopListening();
    _stopKeepAlive();
  }

  // ─── Générateurs ────────────────────────────────────────────
  String _generateDeviceId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rng = Random.secure(); // ✅ Random sécurisé
    return List.generate(16, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  String _generateFamilyCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure(); // ✅ Random sécurisé
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  // ─── Code famille ───────────────────────────────────────────
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
      if (!available) throw Exception('Ce code est déjà utilisé.');
    } else {
      code = _generateFamilyCode();
    }
    final docRef = await _db.collection('families').add({
      'code':        code,
      'createdAt':   FieldValue.serverTimestamp(),
      'memberCount': 1,
    });
    _familyId = docRef.id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('family_id',   _familyId!);
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
      await doc.reference.update({'memberCount': FieldValue.increment(1)});
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('family_id',   _familyId!);
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

  // ─── Keep-alive ─────────────────────────────────────────────
  void reconnect() {
    if (_familyId == null) return;
    _stopListening();
    _startListening();
    _lastDataReceived = DateTime.now();
  }

  void _startKeepAlive() {
    _stopKeepAlive();
    _lastDataReceived = DateTime.now();
    _keepAliveTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _checkConnection(),
    );
  }

  void _stopKeepAlive() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
  }

  void _checkConnection() {
    if (_familyId == null) return;
    final sec = DateTime.now().difference(_lastDataReceived).inSeconds;
    if (sec > 45) reconnect();
    _db.collection('families').doc(_familyId).get()
        .then((_) {})
        .catchError((_) => reconnect());
  }

  void _markDataReceived() => _lastDataReceived = DateTime.now();

  // ─── Listeners temps réel ───────────────────────────────────
  void _startListening() {
    if (_familyId == null) return;
    final fRef = _db.collection('families').doc(_familyId);

    _childrenSub = fRef.collection('children').snapshots().listen((s) {
      _markDataReceived();
      final list = <ChildModel>[];
      final raw  = <Map<String, dynamic>>[];
      for (final doc in s.docs) {
        final d = Map<String, dynamic>.from(doc.data());
        d['id'] = doc.id;
        try { list.add(ChildModel.fromMap(d)); raw.add(d); } catch (e) {
          if (kDebugMode) debugPrint('ChildModel parse error: $e');
        }
      }
      onChildrenChanged?.call(list, raw);
    }, onError: (_) => Future.delayed(const Duration(seconds: 5), reconnect));

    _historySub = fRef.collection('history').snapshots().listen((s) {
      _markDataReceived();
      final list = <HistoryEntry>[];
      final raw  = <Map<String, dynamic>>[];
      for (final doc in s.docs) {
        final d = Map<String, dynamic>.from(doc.data());
        d['id'] = doc.id;
        try { list.add(HistoryEntry.fromMap(d)); raw.add(d); } catch (e) {
          if (kDebugMode) debugPrint('HistoryEntry parse error: $e');
        }
      }
      list.sort((a, b) => b.date.compareTo(a.date));
      onHistoryChanged?.call(list, raw);
    }, onError: (_) => Future.delayed(const Duration(seconds: 5), reconnect));

    _goalsSub = fRef.collection('goals').snapshots().listen((s) {
      _markDataReceived();
      final list = <GoalModel>[];
      final raw  = <Map<String, dynamic>>[];
      for (final doc in s.docs) {
        final d = Map<String, dynamic>.from(doc.data());
        d['id'] = doc.id;
        try { list.add(GoalModel.fromMap(d)); raw.add(d); } catch (e) {
          if (kDebugMode) debugPrint('GoalModel parse error: $e');
        }
      }
      onGoalsChanged?.call(list, raw);
    }, onError: (_) => Future.delayed(const Duration(seconds: 5), reconnect));

    _punishmentsSub = fRef.collection('punishments').snapshots().listen((s) {
      _markDataReceived();
      final list = <PunishmentLines>[];
      final raw  = <Map<String, dynamic>>[];
      for (final doc in s.docs) {
        final d = Map<String, dynamic>.from(doc.data());
        d['id'] = doc.id;
        try { list.add(PunishmentLines.fromMap(d)); raw.add(d); } catch (e) {
          if (kDebugMode) debugPrint('PunishmentLines parse error: $e');
        }
      }
      onPunishmentsChanged?.call(list, raw);
    }, onError: (_) => Future.delayed(const Duration(seconds: 5), reconnect));

    _notesSub = fRef.collection('notes').snapshots().listen((s) {
      _markDataReceived();
      final list = s.docs.map((doc) {
        final d = Map<String, dynamic>.from(doc.data());
        d['id'] = doc.id;
        return NoteModel.fromMap(d);
      }).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      onNotesChanged?.call(list);
    }, onError: (_) => Future.delayed(const Duration(seconds: 5), reconnect));

    _immunitiesSub = fRef.collection('immunities').snapshots().listen((s) {
      _markDataReceived();
      final list = s.docs.map((doc) {
        final d = Map<String, dynamic>.from(doc.data());
        d['id'] = doc.id;
        return ImmunityLines.fromMap(d);
      }).toList();
      onImmunitiesChanged?.call(list);
    }, onError: (_) => Future.delayed(const Duration(seconds: 5), reconnect));

    _tradesSub = fRef.collection('trades').snapshots().listen((s) {
      _markDataReceived();
      final list = s.docs.map((doc) {
        final d = Map<String, dynamic>.from(doc.data());
        d['id'] = doc.id;
        return TradeModel.fromMap(d);
      }).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      onTradesChanged?.call(list);
    }, onError: (_) => Future.delayed(const Duration(seconds: 5), reconnect));

    _tribunalSub = fRef.collection('tribunal').snapshots().listen((s) {
      _markDataReceived();
      final list = s.docs.map((doc) {
        final d = Map<String, dynamic>.from(doc.data());
        d['id'] = doc.id;
        return TribunalCase.fromMap(d);
      }).toList();
      onTribunalChanged?.call(list);
    }, onError: (_) => Future.delayed(const Duration(seconds: 5), reconnect));

    _badgesSub = fRef.collection('custom_badges').snapshots().listen((s) {
      _markDataReceived();
      final list = s.docs.map((doc) {
        final d = Map<String, dynamic>.from(doc.data());
        d['id'] = doc.id;
        return BadgeModel.fromMap(d);
      }).toList();
      onBadgesChanged?.call(list);
    }, onError: (_) => Future.delayed(const Duration(seconds: 5), reconnect));

    _screenTimeSub = fRef.collection('screen_time').snapshots().listen((s) {
      _markDataReceived();
      final Map<String, dynamic> data = {};
      for (final doc in s.docs) { data[doc.id] = doc.data()['value']; }
      onScreenTimeChanged?.call(data);
    }, onError: (_) => Future.delayed(const Duration(seconds: 5), reconnect));
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
    _childrenSub    = null;
    _historySub     = null;
    _goalsSub       = null;
    _punishmentsSub = null;
    _notesSub       = null;
    _immunitiesSub  = null;
    _tradesSub      = null;
    _tribunalSub    = null;
    _badgesSub      = null;
    _screenTimeSub  = null;
  }

  // ─── WRITE : Children ───────────────────────────────────────
  Future<void> saveChild(ChildModel child) async {
    if (_familyId == null) return;
    try {
      final data = child.toMap();
      data['lastModifiedBy'] = deviceId;
      await _db.collection('families').doc(_familyId)
          .collection('children').doc(child.id).set(data);
    } catch (e) {
      if (kDebugMode) debugPrint('saveChild error: $e');
    }
  }

  // ✅ CORRIGÉ : suppression batchée (beaucoup plus rapide)
  Future<void> deleteChild(String childId) async {
    if (_familyId == null) return;
    try {
      final fRef = _db.collection('families').doc(_familyId);
      var batch = _db.batch();
      int ops = 0;

      Future<void> flushIfNeeded() async {
        if (ops >= 450) { await batch.commit(); batch = _db.batch(); ops = 0; }
      }

      // Suppression de l'enfant lui-même
      batch.delete(fRef.collection('children').doc(childId));
      ops++;

      // Suppression des sous-collections associées
      for (final col in ['history', 'goals', 'punishments', 'immunities']) {
        final docs = await fRef.collection(col)
            .where('childId', isEqualTo: childId).get();
        for (final doc in docs.docs) {
          batch.delete(doc.reference); ops++;
          await flushIfNeeded();
        }
      }
      // Trades
      for (final field in ['fromChildId', 'toChildId']) {
        final docs = await fRef.collection('trades')
            .where(field, isEqualTo: childId).get();
        for (final doc in docs.docs) {
          batch.delete(doc.reference); ops++;
          await flushIfNeeded();
        }
      }
      if (ops > 0) await batch.commit();
    } catch (e) {
      if (kDebugMode) debugPrint('deleteChild error: $e');
    }
  }

  // ─── WRITE : History ────────────────────────────────────────
  Future<void> saveHistoryEntry(HistoryEntry entry) async {
    if (_familyId == null) return;
    try {
      final data = entry.toMap();
      data['deviceId'] = deviceId;
      await _db.collection('families').doc(_familyId)
          .collection('history').doc(entry.id).set(data);
    } catch (e) {
      if (kDebugMode) debugPrint('saveHistoryEntry error: $e');
    }
  }

  Future<void> clearAllHistory() async {
    if (_familyId == null) return;
    try {
      var batch = _db.batch();
      int ops   = 0;
      final docs = await _db.collection('families').doc(_familyId)
          .collection('history').get();
      for (final doc in docs.docs) {
        batch.delete(doc.reference);
        ops++;
        if (ops >= 450) { await batch.commit(); batch = _db.batch(); ops = 0; }
      }
      if (ops > 0) await batch.commit();
    } catch (e) {
      if (kDebugMode) debugPrint('clearAllHistory error: $e');
    }
  }

  // ─── WRITE : Goals ──────────────────────────────────────────
  Future<void> saveGoal(GoalModel goal) async {
    if (_familyId == null) return;
    try {
      final data = goal.toMap();
      data['lastModifiedBy'] = deviceId;
      await _db.collection('families').doc(_familyId)
          .collection('goals').doc(goal.id).set(data);
    } catch (e) {
      if (kDebugMode) debugPrint('saveGoal error: $e');
    }
  }

  Future<void> deleteGoal(String goalId) async {
    if (_familyId == null) return;
    try {
      await _db.collection('families').doc(_familyId)
          .collection('goals').doc(goalId).delete();
    } catch (e) {
      if (kDebugMode) debugPrint('deleteGoal error: $e');
    }
  }

  // ─── WRITE : Punishments ────────────────────────────────────
  Future<void> savePunishment(PunishmentLines p) async {
    if (_familyId == null) return;
    try {
      final data = p.toMap();
      data['lastModifiedBy'] = deviceId;
      await _db.collection('families').doc(_familyId)
          .collection('punishments').doc(p.id).set(data);
    } catch (e) {
      if (kDebugMode) debugPrint('savePunishment error: $e');
    }
  }

  Future<void> deletePunishment(String pId) async {
    if (_familyId == null) return;
    try {
      await _db.collection('families').doc(_familyId)
          .collection('punishments').doc(pId).delete();
    } catch (e) {
      if (kDebugMode) debugPrint('deletePunishment error: $e');
    }
  }

  // ─── WRITE : Notes ──────────────────────────────────────────
  Future<void> saveNote(NoteModel note) async {
    if (_familyId == null) return;
    try {
      final data = note.toMap();
      data['lastModifiedBy'] = deviceId;
      await _db.collection('families').doc(_familyId)
          .collection('notes').doc(note.id).set(data);
    } catch (e) {
      if (kDebugMode) debugPrint('saveNote error: $e');
    }
  }

  Future<void> deleteNote(String noteId) async {
    if (_familyId == null) return;
    try {
      await _db.collection('families').doc(_familyId)
          .collection('notes').doc(noteId).delete();
    } catch (e) {
      if (kDebugMode) debugPrint('deleteNote error: $e');
    }
  }

  // ─── WRITE : Immunities ─────────────────────────────────────
  Future<void> saveImmunity(ImmunityLines im) async {
    if (_familyId == null) return;
    try {
      final data = im.toMap();
      data['lastModifiedBy'] = deviceId;
      await _db.collection('families').doc(_familyId)
          .collection('immunities').doc(im.id).set(data);
    } catch (e) {
      if (kDebugMode) debugPrint('saveImmunity error: $e');
    }
  }

  Future<void> deleteImmunity(String imId) async {
    if (_familyId == null) return;
    try {
      await _db.collection('families').doc(_familyId)
          .collection('immunities').doc(imId).delete();
    } catch (e) {
      if (kDebugMode) debugPrint('deleteImmunity error: $e');
    }
  }

  // ─── WRITE : Trades ─────────────────────────────────────────
  Future<void> saveTrade(TradeModel trade) async {
    if (_familyId == null) return;
    try {
      final data = trade.toMap();
      data['lastModifiedBy'] = deviceId;
      await _db.collection('families').doc(_familyId)
          .collection('trades').doc(trade.id).set(data);
    } catch (e) {
      if (kDebugMode) debugPrint('saveTrade error: $e');
    }
  }

  Future<void> deleteTrade(String tradeId) async {
    if (_familyId == null) return;
    try {
      await _db.collection('families').doc(_familyId)
          .collection('trades').doc(tradeId).delete();
    } catch (e) {
      if (kDebugMode) debugPrint('deleteTrade error: $e');
    }
  }

  // ─── WRITE : Tribunal ───────────────────────────────────────
  Future<void> saveTribunalCase(TribunalCase tc) async {
    if (_familyId == null) return;
    try {
      final data = tc.toMap();
      data['lastModifiedBy'] = deviceId;
      await _db.collection('families').doc(_familyId)
          .collection('tribunal').doc(tc.id).set(data);
    } catch (e) {
      if (kDebugMode) debugPrint('saveTribunalCase error: $e');
    }
  }

  Future<void> deleteTribunalCase(String tcId) async {
    if (_familyId == null) return;
    try {
      await _db.collection('families').doc(_familyId)
          .collection('tribunal').doc(tcId).delete();
    } catch (e) {
      if (kDebugMode) debugPrint('deleteTribunalCase error: $e');
    }
  }

  // ─── WRITE : Badges ─────────────────────────────────────────
  Future<void> saveCustomBadge(BadgeModel badge) async {
    if (_familyId == null) return;
    try {
      final data = badge.toMap();
      data['lastModifiedBy'] = deviceId;
      await _db.collection('families').doc(_familyId)
          .collection('custom_badges').doc(badge.id).set(data);
    } catch (e) {
      if (kDebugMode) debugPrint('saveCustomBadge error: $e');
    }
  }

  Future<void> deleteCustomBadge(String badgeId) async {
    if (_familyId == null) return;
    try {
      await _db.collection('families').doc(_familyId)
          .collection('custom_badges').doc(badgeId).delete();
    } catch (e) {
      if (kDebugMode) debugPrint('deleteCustomBadge error: $e');
    }
  }

  // ─── WRITE : Screen Time ────────────────────────────────────
  Future<void> saveScreenTimeValue(String key, dynamic value) async {
    if (_familyId == null) return;
    try {
      await _db.collection('families').doc(_familyId)
          .collection('screen_time').doc(key).set({
        'value':           value,
        'lastModifiedBy':  deviceId,
        'updatedAt':       FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) debugPrint('saveScreenTimeValue error: $e');
    }
  }

  // ─── Changement de code ─────────────────────────────────────
  Future<void> changeFamilyCode(String newCode) async {
    if (_familyId == null) throw Exception('Non connecté.');
    final cleanCode = newCode.toUpperCase().trim();
    if (cleanCode.length < 4 || cleanCode.length > 10) {
      throw Exception('Le code doit avoir entre 4 et 10 caractères.');
    }
    final query = await _db.collection('families')
        .where('code', isEqualTo: cleanCode)
        .limit(1)
        .get();
    if (query.docs.isNotEmpty && query.docs.first.id != _familyId) {
      throw Exception('Ce code est déjà utilisé par une autre famille.');
    }
    await _db.collection('families').doc(_familyId).update({'code': cleanCode});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('family_code', cleanCode);
  }

  // ─── Reset ──────────────────────────────────────────────────
  Future<void> resetAllScores() async {
    if (_familyId == null) return;
    try {
      final docs = await _db.collection('families').doc(_familyId)
          .collection('children').get();
      var batch = _db.batch();
      int ops   = 0;
      for (final doc in docs.docs) {
        batch.update(doc.reference, {
          'points':          0,
          'level':           1,
          'badgeIds':        [],
          'lastModifiedBy':  deviceId,
        });
        ops++;
        if (ops >= 450) { await batch.commit(); batch = _db.batch(); ops = 0; }
      }
      if (ops > 0) await batch.commit();
    } catch (e) {
      if (kDebugMode) debugPrint('resetAllScores error: $e');
    }
  }

  // ─── Upload complet ─────────────────────────────────────────
  Future<void> uploadAllData({
    required List<ChildModel>     children,
    required List<HistoryEntry>   history,
    required List<GoalModel>      goals,
    required List<PunishmentLines> punishments,
    required List<NoteModel>      notes,
    required List<ImmunityLines>  immunities,
    required List<TradeModel>     trades,
    required List<TribunalCase>   tribunalCases,
    required List<BadgeModel>     customBadges,
    required Map<String, dynamic> screenTimeData,
  }) async {
    if (_familyId == null) return;
    try {
      final fRef = _db.collection('families').doc(_familyId);
      var batch  = _db.batch();
      int ops    = 0;

      Future<void> flush() async {
        if (ops >= 450) { await batch.commit(); batch = _db.batch(); ops = 0; }
      }

      for (final c in children)       { final d = c.toMap();  d['lastModifiedBy'] = deviceId; batch.set(fRef.collection('children').doc(c.id),      d); ops++; await flush(); }
      for (final h in history)         { final d = h.toMap();  d['deviceId']        = deviceId; batch.set(fRef.collection('history').doc(h.id),       d); ops++; await flush(); }
      for (final g in goals)           { final d = g.toMap();  d['lastModifiedBy'] = deviceId; batch.set(fRef.collection('goals').doc(g.id),          d); ops++; await flush(); }
      for (final p in punishments)     { final d = p.toMap();  d['lastModifiedBy'] = deviceId; batch.set(fRef.collection('punishments').doc(p.id),    d); ops++; await flush(); }
      for (final n in notes)           { final d = n.toMap();  d['lastModifiedBy'] = deviceId; batch.set(fRef.collection('notes').doc(n.id),          d); ops++; await flush(); }
      for (final im in immunities)     { final d = im.toMap(); d['lastModifiedBy'] = deviceId; batch.set(fRef.collection('immunities').doc(im.id),    d); ops++; await flush(); }
      for (final t in trades)          { final d = t.toMap();  d['lastModifiedBy'] = deviceId; batch.set(fRef.collection('trades').doc(t.id),         d); ops++; await flush(); }
      for (final tc in tribunalCases)  { final d = tc.toMap(); d['lastModifiedBy'] = deviceId; batch.set(fRef.collection('tribunal').doc(tc.id),      d); ops++; await flush(); }
      for (final b in customBadges)    { final d = b.toMap();  d['lastModifiedBy'] = deviceId; batch.set(fRef.collection('custom_badges').doc(b.id),  d); ops++; await flush(); }
      for (final e in screenTimeData.entries) {
        batch.set(fRef.collection('screen_time').doc(e.key), {'value': e.value, 'lastModifiedBy': deviceId});
        ops++; await flush();
      }
      if (ops > 0) await batch.commit();
    } catch (e) {
      if (kDebugMode) debugPrint('uploadAllData error: $e');
    }
  }

  Future<void> uploadLocalData({
    required List<ChildModel>     children,
    required List<HistoryEntry>   history,
    required List<GoalModel>      goals,
    required List<PunishmentLines> punishments,
  }) async {
    await uploadAllData(
      children:      children,
      history:       history,
      goals:         goals,
      punishments:   punishments,
      notes:         [],
      immunities:    [],
      trades:        [],
      tribunalCases: [],
      customBadges:  [],
      screenTimeData: {},
    );
  }

  // ─── Force refresh ──────────────────────────────────────────
  Future<void> forceRefresh() async {
    if (_familyId == null) return;
    try {
      final fRef = _db.collection('families').doc(_familyId);
      const opts = GetOptions(source: Source.server);

      final cs = await fRef.collection('children').get(opts);
      final children = <ChildModel>[]; final cr = <Map<String, dynamic>>[];
      for (final doc in cs.docs) { final d = Map<String, dynamic>.from(doc.data()); d['id'] = doc.id; try { children.add(ChildModel.fromMap(d)); cr.add(d); } catch (_) {} }
      onChildrenChanged?.call(children, cr);

      final hs = await fRef.collection('history').get(opts);
      final history = <HistoryEntry>[]; final hr = <Map<String, dynamic>>[];
      for (final doc in hs.docs) { final d = Map<String, dynamic>.from(doc.data()); d['id'] = doc.id; try { history.add(HistoryEntry.fromMap(d)); hr.add(d); } catch (_) {} }
      history.sort((a, b) => b.date.compareTo(a.date));
      onHistoryChanged?.call(history, hr);

      final gs = await fRef.collection('goals').get(opts);
      final goals = <GoalModel>[]; final gr = <Map<String, dynamic>>[];
      for (final doc in gs.docs) { final d = Map<String, dynamic>.from(doc.data()); d['id'] = doc.id; try { goals.add(GoalModel.fromMap(d)); gr.add(d); } catch (_) {} }
      onGoalsChanged?.call(goals, gr);

      final ps = await fRef.collection('punishments').get(opts);
      final punishments = <PunishmentLines>[]; final pr = <Map<String, dynamic>>[];
      for (final doc in ps.docs) { final d = Map<String, dynamic>.from(doc.data()); d['id'] = doc.id; try { punishments.add(PunishmentLines.fromMap(d)); pr.add(d); } catch (_) {} }
      onPunishmentsChanged?.call(punishments, pr);

      final ns = await fRef.collection('notes').get(opts);
      final notes = ns.docs.map((doc) { final d = Map<String, dynamic>.from(doc.data()); d['id'] = doc.id; return NoteModel.fromMap(d); }).toList();
      notes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      onNotesChanged?.call(notes);

      final ims = await fRef.collection('immunities').get(opts);
      onImmunitiesChanged?.call(ims.docs.map((doc) { final d = Map<String, dynamic>.from(doc.data()); d['id'] = doc.id; return ImmunityLines.fromMap(d); }).toList());

      final ts = await fRef.collection('trades').get(opts);
      final trds = ts.docs.map((doc) { final d = Map<String, dynamic>.from(doc.data()); d['id'] = doc.id; return TradeModel.fromMap(d); }).toList();
      trds.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      onTradesChanged?.call(trds);

      final tcs = await fRef.collection('tribunal').get(opts);
      onTribunalChanged?.call(tcs.docs.map((doc) { final d = Map<String, dynamic>.from(doc.data()); d['id'] = doc.id; return TribunalCase.fromMap(d); }).toList());

      final bs = await fRef.collection('custom_badges').get(opts);
      onBadgesChanged?.call(bs.docs.map((doc) { final d = Map<String, dynamic>.from(doc.data()); d['id'] = doc.id; return BadgeModel.fromMap(d); }).toList());

      final sts = await fRef.collection('screen_time').get(opts);
      final Map<String, dynamic> stData = {};
      for (final doc in sts.docs) { stData[doc.id] = doc.data()['value']; }
      onScreenTimeChanged?.call(stData);

      _markDataReceived();
    } catch (e) {
      if (kDebugMode) debugPrint('forceRefresh error: $e');
      reconnect();
    }
  }
}
