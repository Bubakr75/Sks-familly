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
    final query = await _db.collection('families').where('code', isEqualTo: code.toUpperCase().trim()).limit(1).get();
    return query.docs.isEmpty;
  }

  Future<String> createFamily({String? customCode}) async {
    String code;
    if (customCode != null && customCode.trim().length >= 4) {
      code = customCode.toUpperCase().trim();
      final available = await isCodeAvailable(code);
      if (!available) throw Exception('Ce code est deja utilise.');
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
      final query = await _db.collection('families').where('code', isEqualTo: cleanCode).limit(1).get();
      if (query.docs.isEmpty) return false;
      final doc = query.docs.first;
      _familyId = doc.id;
      await doc.reference.update({'memberCount': FieldValue.increment(1)});
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
    _stopListening();
    _startListening();
    _lastDataReceived = DateTime.now();
  }

  void _startKeepAlive() {
    _stopKeepAlive();
    _lastDataReceived = DateTime.now();
    _keepAliveTimer = Timer.periodic(const Duration(seconds: 15), (_) => _checkConnection());
  }

  void _stopKeepAlive() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
  }

  void _checkConnection() {
    if (_familyId == null) return;
    final sec = DateTime.now().difference(_lastDataReceived).inSeconds;
    if (sec > 45) reconnect();
    _db.collection('families').doc(_familyId).get().then((_) {}).catchError((e) => reconnect());
  }

  void _markDataReceived() => _lastDataReceived = DateTime.now();

  // ===== REAL-TIME LISTENERS (10 COLLECTIONS) =====
  void _startListening() {
    if (_familyId == null) return;
    final fRef = _db.collection('families').doc(_familyId);

    _childrenSub = fRef.collection('children').snapshots().listen((s) {
      _markDataReceived();
      final list = <ChildModel>[];
      final raw = <Map<String, dynamic>>[];
      for (final doc in s.docs) {
        final d = doc.data();
        d['id'] = doc.id;
        list.add(ChildModel.fromMap(d));
        raw.add(Map<String, dynamic>.from(d));
      }
      onChildrenChanged?.call(list, raw);
    }, onError: (e) => Future.delayed(const Duration(seconds: 5), () => reconnect()));

    _historySub = fRef.collection('history').snapshots().listen((s) {
      _markDataReceived();
      final list = <HistoryEntry>[];
      final raw = <Map<String, dynamic>>[];
      for (final doc in s.docs) {
        final d = doc.data();
        d['id'] = doc.id;
        list.add(HistoryEntry.fromMap(d));
        raw.add(Map<String, dynamic>.from(d));
      }
      list.sort((a, b) => b.date.compareTo(a.date));
      onHistoryChanged?.call(list, raw);
    }, onError: (e) => Future.delayed(const Duration(seconds: 5), () => reconnect()));

    _goalsSub = fRef.collection('goals').snapshots().listen((s) {
      _markDataReceived();
      final list = <GoalModel>[];
      final raw = <Map<String, dynamic>>[];
      for (final doc in s.docs) {
        final d = doc.data();
        d['id'] = doc.id;
        list.add(GoalModel.fromMap(d));
        raw.add(Map<String, dynamic>.from(d));
      }
      onGoalsChanged?.call(list, raw);
    }, onError: (e) => Future.delayed(const Duration(seconds: 5), () => reconnect()));

    _punishmentsSub = fRef.collection('punishments').snapshots().listen((s) {
      _markDataReceived();
      final list = <PunishmentLines>[];
      final raw = <Map<String, dynamic>>[];
      for (final doc in s.docs) {
        final d = doc.data();
        d['id'] = doc.id;
        list.add(PunishmentLines.fromMap(d));
        raw.add(Map<String, dynamic>.from(d));
      }
      onPunishmentsChanged?.call(list, raw);
    }, onError: (e) => Future.delayed(const Duration(seconds: 5), () => reconnect()));

    _notesSub = fRef.collection('notes').snapshots().listen((s) {
      _markDataReceived();
      final list = s.docs.map((doc) {
        final d = doc.data();
        d['id'] = doc.id;
        return NoteModel.fromMap(d);
      }).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      onNotesChanged?.call(list);
    }, onError: (e) => Future.delayed(const Duration(seconds: 5), () => reconnect()));

    _immunitiesSub = fRef.collection('immunities').snapshots().listen((s) {
      _markDataReceived();
      final list = s.docs.map((doc) {
        final d = doc.data();
        d['id'] = doc.id;
        return ImmunityLines.fromMap(d);
      }).toList();
      onImmunitiesChanged?.call(list);
    }, onError: (e) => Future.delayed(const Duration(seconds: 5), () => reconnect()));

    _tradesSub = fRef.collection('trades').snapshots().listen((s) {
      _markDataReceived();
      final list = s.docs.map((doc) {
        final d = doc.data();
        d['id'] = doc.id;
        return TradeModel.fromMap(d);
      }).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      onTradesChanged?.call(list);
    }, onError: (e) => Future.delayed(const Duration(seconds: 5), () => reconnect()));

    _tribunalSub = fRef.collection('tribunal').snapshots().listen((s) {
      _markDataReceived();
      final list = s.docs.map((doc) {
        final d = doc.data();
        d['id'] = doc.id;
        return TribunalCase.fromMap(d);
      }).toList();
      onTribunalChanged?.call(list);
    }, onError: (e) => Future.delayed(const Duration(seconds: 5), () => reconnect()));

    _badgesSub = fRef.collection('custom_badges').snapshots().listen((s) {
      _markDataReceived();
      final list = s.docs.map((doc) {
        final d = doc.data();
        d['id'] = doc.id;
        return BadgeModel.fromMap(d);
      }).toList();
      onBadgesChanged?.call(list);
    }, onError: (e) => Future.delayed(const Duration(seconds: 5), () => reconnect()));

    _screenTimeSub = fRef.collection('screen_time').snapshots().listen((s) {
      _markDataReceived();
      final Map<String, dynamic> data = {};
      for (final doc in s.docs) {
        data[doc.id] = doc.data()['value'];
      }
      onScreenTimeChanged?.call(data);
    }, onError: (e) => Future.delayed(const Duration(seconds: 5), () => reconnect()));
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
    for (final col in ['history', 'goals', 'punishments', 'immunities']) {
      final docs = await _db.collection('families').doc(_familyId).collection(col).where('childId', isEqualTo: childId).get();
      for (final doc in docs.docs) await doc.reference.delete();
    }
    final t1 = await _db.collection('families').doc(_familyId).collection('trades').where('fromChildId', isEqualTo: childId).get();
    for (final doc in t1.docs) await doc.reference.delete();
    final t2 = await _db.collection('families').doc(_familyId).collection('trades').where('toChildId', isEqualTo: childId).get();
    for (final doc in t2.docs) await doc.reference.delete();
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

  // ===== UPLOAD ALL =====
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
    var batch = _db.batch();
    int ops = 0;

    Future<void> flush() async {
      if (ops >= 450) {
        await batch.commit();
        batch = _db.batch();
        ops = 0;
      }
    }

    for (final c in children) { final d = c.toMap(); d['lastModifiedBy'] = deviceId; batch.set(fRef.collection('children').doc(c.id), d); ops++; await flush(); }
    for (final h in history) { final d = h.toMap(); d['deviceId'] = deviceId; batch.set(fRef.collection('history').doc(h.id), d); ops++; await flush(); }
    for (final g in goals) { final d = g.toMap(); d['lastModifiedBy'] = deviceId; batch.set(fRef.collection('goals').doc(g.id), d); ops++; await flush(); }
    for (final p in punishments) { final d = p.toMap(); d['lastModifiedBy'] = deviceId; batch.set(fRef.collection('punishments').doc(p.id), d); ops++; await flush(); }
    for (final n in notes) { final d = n.toMap(); d['lastModifiedBy'] = deviceId; batch.set(fRef.collection('notes').doc(n.id), d); ops++; await flush(); }
    for (final im in immunities) { final d = im.toMap(); d['lastModifiedBy'] = deviceId; batch.set(fRef.collection('immunities').doc(im.id), d); ops++; await flush(); }
    for (final t in trades) { final d = t.toMap(); d['lastModifiedBy'] = deviceId; batch.set(fRef.collection('trades').doc(t.id), d); ops++; await flush(); }
    for (final tc in tribunalCases) { final d = tc.toMap(); d['lastModifiedBy'] = deviceId; batch.set(fRef.collection('tribunal').doc(tc.id), d); ops++; await flush(); }
    for (final b in customBadges) { final d = b.toMap(); d['lastModifiedBy'] = deviceId; batch.set(fRef.collection('custom_badges').doc(b.id), d); ops++; await flush(); }
    for (final e in screenTimeData.entries) { batch.set(fRef.collection('screen_time').doc(e.key), {'value': e.value, 'lastModifiedBy': deviceId}); ops++; await flush(); }

    if (ops > 0) await batch.commit();
  }

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
      final d = n.toMap();
      d['lastModifiedBy'] = deviceId;
      batch.set(fRef.collection('notes').doc(n.id), d);
    }
    await batch.commit();
  }

  // ===== FORCE REFRESH =====
  Future<void> forceRefresh() async {
    if (_familyId == null) return;
    try {
      final fRef = _db.collection('families').doc(_familyId);
      final opts = const GetOptions(source: Source.server);

      final cs = await fRef.collection('children').get(opts);
      final children = <ChildModel>[];
      final cr = <Map<String, dynamic>>[];
      for (final doc in cs.docs) { final d = doc.data(); d['id'] = doc.id; children.add(ChildModel.fromMap(d)); cr.add(Map<String, dynamic>.from(d)); }
      onChildrenChanged?.call(children, cr);

      final hs = await fRef.collection('history').get(opts);
      final history = <HistoryEntry>[];
      final hr = <Map<String, dynamic>>[];
      for (final doc in hs.docs) { final d = doc.data(); d['id'] = doc.id; history.add(HistoryEntry.fromMap(d)); hr.add(Map<String, dynamic>.from(d)); }
      history.sort((a, b) => b.date.compareTo(a.date));
      onHistoryChanged?.call(history, hr);

      final gs = await fRef.collection('goals').get(opts);
      final goals = <GoalModel>[];
      final gr = <Map<String, dynamic>>[];
      for (final doc in gs.docs) { final d = doc.data(); d['id'] = doc.id; goals.add(GoalModel.fromMap(d)); gr.add(Map<String, dynamic>.from(d)); }
      onGoalsChanged?.call(goals, gr);

      final ps = await fRef.collection('punishments').get(opts);
      final punishments = <PunishmentLines>[];
      final pr = <Map<String, dynamic>>[];
      for (final doc in ps.docs) { final d = doc.data(); d['id'] = doc.id; punishments.add(PunishmentLines.fromMap(d)); pr.add(Map<String, dynamic>.from(d)); }
      onPunishmentsChanged?.call(punishments, pr);

      final ns = await fRef.collection('notes').get(opts);
      final notes = ns.docs.map((doc) { final d = doc.data(); d['id'] = doc.id; return NoteModel.fromMap(d); }).toList();
      notes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      onNotesChanged?.call(notes);

      final ims = await fRef.collection('immunities').get(opts);
      onImmunitiesChanged?.call(ims.docs.map((doc) { final d = doc.data(); d['id'] = doc.id; return ImmunityLines.fromMap(d); }).toList());

      final ts = await fRef.collection('trades').get(opts);
      final trades = ts.docs.map((doc) { final d = doc.data(); d['id'] = doc.id; return TradeModel.fromMap(d); }).toList();
      trades.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      onTradesChanged?.call(trades);

      final tcs = await fRef.collection('tribunal').get(opts);
      onTribunalChanged?.call(tcs.docs.map((doc) { final d = doc.data(); d['id'] = doc.id; return TribunalCase.fromMap(d); }).toList());

      final bs = await fRef.collection('custom_badges').get(opts);
      onBadgesChanged?.call(bs.docs.map((doc) { final d = doc.data(); d['id'] = doc.id; return BadgeModel.fromMap(d); }).toList());

      final sts = await fRef.collection('screen_time').get(opts);
      final Map<String, dynamic> stData = {};
      for (final doc in sts.docs) { stData[doc.id] = doc.data()['value']; }
      onScreenTimeChanged?.call(stData);

      _markDataReceived();
    } catch (e) {
      reconnect();
    }
  }
}
