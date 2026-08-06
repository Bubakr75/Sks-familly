import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
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
import '../models/pending_request.dart';
import '../models/parent_profile.dart';
import '../models/sks_wallet.dart';
import '../utils/web_reconnect.dart';
import 'fcm_service.dart';
import 'family_management_service.dart';

class FirestoreService {
  static const walletFunctionsRegion = 'us-central1';

  @visibleForTesting
  static Map<String, dynamic> buildPointActionPayload({
    required String familyId,
    required String actionId,
    required String childId,
    required int amount,
    required String reason,
    required String category,
    required bool isBonus,
    String? photoStoragePath,
    int? penaltyLinesCount,
    String? penaltyLinesInstruction,
  }) {
    return {
      'familyId': familyId,
      'actionId': actionId,
      'childId': childId,
      'amount': amount,
      'reason': reason.trim(),
      'category': category.trim(),
      'isBonus': isBonus,
      if (photoStoragePath != null) 'photoStoragePath': photoStoragePath,
      if (penaltyLinesCount != null) 'penaltyLinesCount': penaltyLinesCount,
      if (penaltyLinesInstruction != null)
        'penaltyLinesInstruction': penaltyLinesInstruction.trim(),
    };
  }

  @visibleForTesting
  static Map<String, dynamic> buildWalletAdjustmentPayload({
    required String familyId,
    required String childId,
    required String operationId,
    required String type,
    required int amount,
    required String reason,
  }) {
    return {
      'familyId': familyId,
      'childId': childId,
      'operationId': operationId,
      'type': type,
      'amount': amount,
      'reason': reason.trim(),
    };
  }

  @visibleForTesting
  static Map<String, String?> buildApprovedLocalMembershipData({
    required String familyId,
    required String familyCode,
    required String role,
    String? childId,
    bool allowOwner = false,
  }) {
    final cleanFamilyId = familyId.trim();
    final cleanCode = familyCode.trim().toUpperCase();
    final cleanRole = role.trim().toLowerCase();
    final cleanChildId = childId?.trim();

    if (cleanFamilyId.isEmpty ||
        cleanFamilyId.contains('/') ||
        RegExp(r'[\u0000-\u001f]').hasMatch(cleanFamilyId)) {
      throw ArgumentError.value(familyId, 'familyId', 'Identifiant invalide.');
    }

    if (cleanCode.length < 4 ||
        cleanCode.length > 10 ||
        !RegExp(r'^[A-Z0-9]+$').hasMatch(cleanCode)) {
      throw ArgumentError.value(
        familyCode,
        'familyCode',
        'Code famille invalide.',
      );
    }

    final isAllowedOwner = allowOwner && cleanRole == 'owner';

    if (!isAllowedOwner && cleanRole != 'parent' && cleanRole != 'child') {
      throw ArgumentError.value(role, 'role', 'Rôle approuvé invalide.');
    }

    if (cleanRole == 'child') {
      if (cleanChildId == null ||
          cleanChildId.isEmpty ||
          cleanChildId.contains('/') ||
          RegExp(r'[\u0000-\u001f]').hasMatch(cleanChildId)) {
        throw ArgumentError.value(
          childId,
          'childId',
          'Profil enfant approuvé invalide.',
        );
      }
    } else if (cleanChildId != null && cleanChildId.isNotEmpty) {
      throw ArgumentError.value(
        childId,
        'childId',
        'Un parent ne doit pas être rattaché à un profil enfant.',
      );
    }

    return {
      'family_id': cleanFamilyId,
      'family_code': isAllowedOwner ? cleanCode : null,
      'family_member_role': cleanRole,
      'family_member_child_id': cleanRole == 'child' ? cleanChildId : null,
    };
  }

  @visibleForTesting
  static Map<String, dynamic> buildNewFamilyData({
    required String code,
    required String ownerUid,
    required Object createdAt,
  }) {
    return {
      'code': code,
      'createdAt': createdAt,
      'memberCount': 1,
      'ownerUid': ownerUid,
      'schemaVersion': 2,
      'migrationStatus': 'native',
    };
  }

  @visibleForTesting
  static Map<String, dynamic> buildOwnerMemberData({
    required String ownerUid,
    required Object createdAt,
    required Object approvedAt,
  }) {
    return {
      'uid': ownerUid,
      'role': 'owner',
      'childId': null,
      'active': true,
      'createdAt': createdAt,
      'approvedBy': ownerUid,
      'approvedAt': approvedAt,
    };
  }

  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  String? _familyId;
  String? get familyId => _familyId;
  bool get isConnected => _familyId != null;

  String? _memberRole;
  String? get memberRole => _memberRole;

  String? _memberChildId;
  String? get memberChildId => _memberChildId;

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
  StreamSubscription? _requestsSub;
  StreamSubscription? _joinRequestsSub;
  StreamSubscription? _screenTimeSub;
  StreamSubscription? _parentProfilesSub;
  StreamSubscription? _choresSub;
  StreamSubscription? _rewardsSub;
  StreamSubscription? _purchasesSub;
  StreamSubscription? _walletsSub;

  Timer? _keepAliveTimer;
  DateTime _lastDataReceived = DateTime.now();

  void Function(List<ChildModel>, List<Map<String, dynamic>>)?
      onChildrenChanged;
  void Function(List<HistoryEntry>, List<Map<String, dynamic>>)?
      onHistoryChanged;
  void Function(List<GoalModel>, List<Map<String, dynamic>>)? onGoalsChanged;
  void Function(List<PunishmentLines>, List<Map<String, dynamic>>)?
      onPunishmentsChanged;
  void Function(List<NoteModel>)? onNotesChanged;
  void Function(List<ImmunityLines>)? onImmunitiesChanged;
  void Function(List<TradeModel>)? onTradesChanged;
  void Function(List<TribunalCase>)? onTribunalChanged;
  void Function(List<BadgeModel>)? onBadgesChanged;
  void Function(List<PendingRequest>)? onRequestsChanged;
  void Function(List<Map<String, dynamic>>)? onJoinRequestsChanged;
  void Function(Map<String, dynamic>)? onScreenTimeChanged;
  void Function(List<ParentProfile>)? onParentProfilesChanged;
  void Function(List<Map<String, dynamic>>)? onChoresChanged;
  void Function(List<Map<String, dynamic>>)? onRewardsChanged;
  void Function(List<Map<String, dynamic>>)? onPurchasesChanged;
  void Function(List<SksWallet>)? onWalletsChanged;

  // ─── Init ────────────────────────────────────────────────────
  Future<void> init() async {
    try {
      // Configuration Firestore pour iOS Safari Web (long-polling)
      if (kIsWeb) {
        try {
          _db.settings = const Settings(
            persistenceEnabled: true,
            sslEnabled: true,
            webExperimentalForceLongPolling: true,
            webExperimentalAutoDetectLongPolling: false,
          );
          if (kDebugMode) debugPrint('Firestore: long-polling force sur Web');
        } catch (e) {
          if (kDebugMode) debugPrint('Firestore settings error: $e');
        }
      }

      final prefs = await SharedPreferences.getInstance();
      _familyId = prefs.getString('family_id');
      _memberRole = prefs.getString('family_member_role');
      _memberChildId = prefs.getString('family_member_child_id');
      _deviceId = prefs.getString('device_id');
      if (_deviceId == null) {
        _deviceId = _generateDeviceId();
        await prefs.setString('device_id', _deviceId!);
      }

      // Attacher les ecouteurs Web (visibilitychange, online, focus)
      // pour reconnecter Firestore quand l'onglet revient au premier plan
      _startWebLifecycleHandlers();

      if (_familyId != null) {
        // Le push n'est qu'une alerte : il ne doit jamais retarder les
        // listeners Firestore Web qui alimentent la boîte de réception.
        // Android conserve son initialisation historique, déjà fiable.
        if (kIsWeb) {
          unawaited(FcmService().registerToken());
        } else {
          await FcmService().registerToken();
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('FirestoreService init error: $e');
    }
  }

  void _startWebLifecycleHandlers() {
    try {
      attachWebReconnectHandlers(() {
        if (kDebugMode) debugPrint('Web lifecycle event: reconnect Firestore');
        reconnect();
      });
    } catch (e) {
      if (kDebugMode) debugPrint('Web lifecycle error: $e');
    }
  }

  // ─── Dispose ─────────────────────────────────────────────────
  void dispose() {
    _stopListening();
    _stopKeepAlive();
  }

  // ─── Générateurs ─────────────────────────────────────────────
  String _generateDeviceId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rng = Random.secure();
    return List.generate(16, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  static const _pendingFamilyCreationIdKey = 'pending_family_creation_id_v1';

  Future<String> createFamily({String? customCode}) async {
    final prefs = await SharedPreferences.getInstance();

    var familyId = prefs.getString(
      _pendingFamilyCreationIdKey,
    );

    if (familyId == null || familyId.trim().isEmpty) {
      familyId = _db.collection('families').doc().id;

      final pendingSaved = await prefs.setString(
        _pendingFamilyCreationIdKey,
        familyId,
      );

      if (!pendingSaved) {
        throw StateError(
          'Impossible de préparer la création localement.',
        );
      }
    }

    final result = await FamilyManagementService().createFamily(
      familyId: familyId,
      customCode: customCode,
    );

    final previousFamilyId = prefs.getString('family_id');
    final previousFamilyCode = prefs.getString('family_code');
    final previousRole = prefs.getString(
      'family_member_role',
    );
    final previousChildId = prefs.getString(
      'family_member_child_id',
    );

    Future<void> restorePreference(
      String key,
      String? value,
    ) async {
      if (value == null) {
        await prefs.remove(key);
      } else {
        await prefs.setString(key, value);
      }
    }

    Future<void> requireSet(
      String key,
      String value,
    ) async {
      final saved = await prefs.setString(key, value);

      if (!saved) {
        throw StateError(
          'Impossible d’enregistrer $key localement.',
        );
      }
    }

    try {
      await requireSet('family_member_role', 'owner');
      await prefs.remove('family_member_child_id');
      await requireSet('family_code', result.code);

      // family_id reste volontairement la dernière clé
      // d’activation écrite.
      await requireSet('family_id', result.familyId);
    } catch (_) {
      await restorePreference(
        'family_member_role',
        previousRole,
      );
      await restorePreference(
        'family_member_child_id',
        previousChildId,
      );
      await restorePreference(
        'family_code',
        previousFamilyCode,
      );
      await restorePreference(
        'family_id',
        previousFamilyId,
      );
      rethrow;
    }

    _familyId = result.familyId;
    _memberRole = 'owner';
    _memberChildId = null;

    await prefs.remove(_pendingFamilyCreationIdKey);

    await FcmService().registerToken();
    _startListening();
    _startKeepAlive();

    return result.code;
  }

  Future<String> migrateLegacyFamily({
    required String migrationSecret,
  }) async {
    final currentFamilyId = _familyId;

    if (currentFamilyId == null) {
      throw StateError(
        'Aucune ancienne famille n’est active sur cet appareil.',
      );
    }

    final result = await FamilyManagementService().migrateLegacyFamily(
      familyId: currentFamilyId,
      migrationSecret: migrationSecret,
    );

    await activateApprovedFamily(
      familyId: result.familyId,
      familyCode: result.code,
      role: 'owner',
      allowOwner: true,
    );

    return result.code;
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
      await prefs.setString('family_id', _familyId!);
      await prefs.setString('family_code', cleanCode);
      await FcmService().registerToken();
      _startListening();
      _startKeepAlive();
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('joinFamily ERROR: $e');
      rethrow;
    }
  }

  Future<void> activateApprovedFamily({
    required String familyId,
    required String familyCode,
    required String role,
    String? childId,
    bool allowOwner = false,
  }) async {
    final membership = buildApprovedLocalMembershipData(
      familyId: familyId,
      familyCode: familyCode,
      role: role,
      childId: childId,
      allowOwner: allowOwner,
    );

    final approvedFamilyId = membership['family_id']!;
    final approvedCode = membership['family_code'];
    final approvedRole = membership['family_member_role']!;
    final approvedChildId = membership['family_member_child_id'];

    if (_familyId != null && _familyId != approvedFamilyId) {
      throw StateError(
        'Cet appareil est déjà connecté à une autre famille.',
      );
    }

    final prefs = await SharedPreferences.getInstance();

    final previousFamilyId = prefs.getString('family_id');
    final previousFamilyCode = prefs.getString('family_code');
    final previousRole = prefs.getString('family_member_role');
    final previousChildId = prefs.getString('family_member_child_id');

    Future<void> restorePreference(String key, String? value) async {
      if (value == null) {
        await prefs.remove(key);
      } else {
        await prefs.setString(key, value);
      }
    }

    Future<void> requireSet(String key, String value) async {
      final saved = await prefs.setString(key, value);
      if (!saved) {
        throw StateError('Impossible d’enregistrer $key localement.');
      }
    }

    try {
      // family_id est volontairement écrit en dernier. Tant que cette clé
      // n’existe pas, un redémarrage ne lance aucun listener familial.
      await requireSet('family_member_role', approvedRole);

      if (approvedChildId == null) {
        await prefs.remove('family_member_child_id');
      } else {
        await requireSet('family_member_child_id', approvedChildId);
      }

      if (approvedCode == null) {
        await prefs.remove('family_code');
      } else {
        await requireSet('family_code', approvedCode);
      }
      await requireSet('family_id', approvedFamilyId);
    } catch (_) {
      await restorePreference('family_member_role', previousRole);
      await restorePreference('family_member_child_id', previousChildId);
      await restorePreference('family_code', previousFamilyCode);
      await restorePreference('family_id', previousFamilyId);
      rethrow;
    }

    _stopListening();
    _stopKeepAlive();

    _familyId = approvedFamilyId;
    _memberRole = approvedRole;
    _memberChildId = approvedChildId;

    await FcmService().registerToken();
    _startListening();
    _startKeepAlive();
  }

  Future<void> verifyApprovedFamilyAccess(String familyId) async {
    final cleanFamilyId = familyId.trim();
    if (cleanFamilyId.isEmpty ||
        cleanFamilyId.contains('/') ||
        RegExp(r'[\u0000-\u001f]').hasMatch(cleanFamilyId)) {
      throw ArgumentError.value(
        familyId,
        'familyId',
        'Identifiant familial invalide.',
      );
    }

    const server = GetOptions(source: Source.server);
    final familyRef = _db.collection('families').doc(cleanFamilyId);
    final familySnapshot = await familyRef.get(server);
    if (!familySnapshot.exists) {
      throw StateError('La famille approuvée est introuvable.');
    }

    // Cette lecture vérifie aussi que les règles reconnaissent déjà le membre
    // actif avant toute persistance locale.
    await familyRef.collection('children').limit(1).get(server);
  }

  Future<String?> getFamilyCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('family_code');
  }

  Future<void> applyServerAccessContext({
    required String familyId,
    required String role,
    String? familyCode,
  }) async {
    if (_familyId != familyId) {
      throw StateError('Le contexte concerne une autre famille.');
    }
    if (!['owner', 'manager', 'parent', 'child'].contains(role)) {
      throw ArgumentError.value(role, 'role', 'Rôle familial invalide.');
    }
    final prefs = await SharedPreferences.getInstance();
    final roleSaved = await prefs.setString('family_member_role', role);
    if (!roleSaved) {
      throw StateError('Impossible d’enregistrer le rôle familial.');
    }
    if (familyCode == null) {
      await prefs.remove('family_code');
    } else {
      final codeSaved = await prefs.setString('family_code', familyCode);
      if (!codeSaved) {
        throw StateError('Impossible d’enregistrer le code familial.');
      }
    }
    final roleChanged = _memberRole != role;
    _memberRole = role;
    if (roleChanged && _familyId != null) {
      _stopListening();
      _startListening();
    }
  }

  Future<void> disconnectFamily() async {
    _stopListening();
    _stopKeepAlive();
    _familyId = null;
    _memberRole = null;
    _memberChildId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('family_id');
    await prefs.remove('family_code');
    await prefs.remove('family_member_role');
    await prefs.remove('family_member_child_id');
  }

  // ─── Keep-alive ──────────────────────────────────────────────
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
    _db
        .collection('families')
        .doc(_familyId)
        .get()
        .then((_) {})
        .catchError((_) {
      reconnect();
    });
  }

  void _markDataReceived() => _lastDataReceived = DateTime.now();

  // ─── Listeners temps réel ────────────────────────────────────
  void _startListening() {
    if (_familyId == null) return;
    final fRef = _db.collection('families').doc(_familyId);

    _childrenSub = fRef.collection('children').snapshots().listen((s) {
      _markDataReceived();
      final list = <ChildModel>[];
      final raw = <Map<String, dynamic>>[];
      for (final doc in s.docs) {
        final d = Map<String, dynamic>.from(doc.data());
        d['id'] = doc.id;
        try {
          list.add(ChildModel.fromMap(d));
          raw.add(d);
        } catch (e) {
          if (kDebugMode) debugPrint('ChildModel parse error: $e');
        }
      }
      onChildrenChanged?.call(list, raw);
    }, onError: (_) => Future.delayed(const Duration(seconds: 5), reconnect));

    _historySub = fRef.collection('history').snapshots().listen((s) {
      _markDataReceived();
      final list = <HistoryEntry>[];
      final raw = <Map<String, dynamic>>[];
      for (final doc in s.docs) {
        final d = Map<String, dynamic>.from(doc.data());
        d['id'] = doc.id;
        try {
          list.add(HistoryEntry.fromMap(d));
          raw.add(d);
        } catch (e) {
          if (kDebugMode) debugPrint('HistoryEntry parse error: $e');
        }
      }
      list.sort((a, b) => b.date.compareTo(a.date));
      onHistoryChanged?.call(list, raw);
    }, onError: (_) => Future.delayed(const Duration(seconds: 5), reconnect));

    _goalsSub = fRef.collection('goals').snapshots().listen((s) {
      _markDataReceived();
      final list = <GoalModel>[];
      final raw = <Map<String, dynamic>>[];
      for (final doc in s.docs) {
        final d = Map<String, dynamic>.from(doc.data());
        d['id'] = doc.id;
        try {
          list.add(GoalModel.fromMap(d));
          raw.add(d);
        } catch (e) {
          if (kDebugMode) debugPrint('GoalModel parse error: $e');
        }
      }
      onGoalsChanged?.call(list, raw);
    }, onError: (_) => Future.delayed(const Duration(seconds: 5), reconnect));

    _punishmentsSub = fRef.collection('punishments').snapshots().listen((s) {
      _markDataReceived();
      final list = <PunishmentLines>[];
      final raw = <Map<String, dynamic>>[];
      for (final doc in s.docs) {
        final d = Map<String, dynamic>.from(doc.data());
        d['id'] = doc.id;
        try {
          list.add(PunishmentLines.fromMap(d));
          raw.add(d);
        } catch (e) {
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

    Query<Map<String, dynamic>> requestsQuery = fRef.collection('requests');
    if (_memberRole == 'child' && _memberChildId != null) {
      requestsQuery = requestsQuery.where('childId', isEqualTo: _memberChildId);
    }
    _requestsSub = requestsQuery.snapshots().listen((s) {
      _markDataReceived();
      // 🔔 Ne garder que les demandes "pending" pour le badge cloche
      final list = s.docs
          .map((doc) {
            final d = Map<String, dynamic>.from(doc.data());
            d['id'] = doc.id;
            return PendingRequest.fromMap(d);
          })
          .where((r) => r.isPending)
          .toList();
      onRequestsChanged?.call(list);
    }, onError: (_) => Future.delayed(const Duration(seconds: 5), reconnect));

    if (const ['owner', 'manager', 'familyAdmin', 'parent']
        .contains(_memberRole)) {
      _joinRequestsSub =
          fRef.collection('join_requests').snapshots().listen((snapshot) {
        _markDataReceived();
        final list = snapshot.docs.map((doc) {
          final data = Map<String, dynamic>.from(doc.data());
          data['id'] = doc.id;
          return data;
        }).where((data) {
          final status = data['status']?.toString() ?? '';
          return status == 'pending' ||
              status == 'sent' ||
              status == 'received';
        }).toList();
        onJoinRequestsChanged?.call(list);
      }, onError: (_) => Future.delayed(const Duration(seconds: 5), reconnect));
    }

    _screenTimeSub = fRef.collection('screen_time').snapshots().listen((s) {
      _markDataReceived();
      final Map<String, dynamic> data = {};
      for (final doc in s.docs) {
        data[doc.id] = doc.data()['value'];
      }
      onScreenTimeChanged?.call(data);
    }, onError: (_) => Future.delayed(const Duration(seconds: 5), reconnect));

    // ─── Profils parents ───
    _parentProfilesSub =
        fRef.collection('parent_profiles').snapshots().listen((s) {
      _markDataReceived();
      final list = s.docs.map((doc) {
        final d = Map<String, dynamic>.from(doc.data());
        d['id'] = doc.id;
        return ParentProfile.fromMap(d);
      }).toList();
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      onParentProfilesChanged?.call(list);
    }, onError: (_) => Future.delayed(const Duration(seconds: 5), reconnect));

    // ─── Chores (tâches checklist) ───
    _choresSub = fRef.collection('chores').snapshots().listen((s) {
      _markDataReceived();
      final list = s.docs.map((doc) {
        final d = Map<String, dynamic>.from(doc.data());
        d['id'] = doc.id;
        return d;
      }).toList();
      onChoresChanged?.call(list);
    }, onError: (_) => Future.delayed(const Duration(seconds: 5), reconnect));

    // ─── Récompenses boutique ───
    _rewardsSub = fRef.collection('rewards').snapshots().listen((s) {
      _markDataReceived();
      final list = s.docs.map((doc) {
        final d = Map<String, dynamic>.from(doc.data());
        d['id'] = doc.id;
        return d;
      }).toList();
      onRewardsChanged?.call(list);
    }, onError: (_) => Future.delayed(const Duration(seconds: 5), reconnect));

    // ─── Achats boutique ───
    _purchasesSub = fRef.collection('purchases').snapshots().listen((s) {
      _markDataReceived();
      final list = s.docs.map((doc) {
        final d = Map<String, dynamic>.from(doc.data());
        d['id'] = doc.id;
        return d;
      }).toList();
      onPurchasesChanged?.call(list);
    }, onError: (_) => Future.delayed(const Duration(seconds: 5), reconnect));

    final wallets = fRef.collection('wallets');
    if (_memberRole == 'child' && _memberChildId != null) {
      _walletsSub = wallets.doc(_memberChildId).snapshots().listen((doc) {
        _markDataReceived();
        final list = <SksWallet>[];
        if (doc.exists && doc.data() != null) {
          final data = Map<String, dynamic>.from(doc.data()!);
          data['childId'] = doc.id;
          list.add(SksWallet.fromMap(data));
        }
        onWalletsChanged?.call(list);
      }, onError: (_) => Future.delayed(const Duration(seconds: 5), reconnect));
    } else {
      _walletsSub = wallets.snapshots().listen((snapshot) {
        _markDataReceived();
        final list = snapshot.docs.map((doc) {
          final data = Map<String, dynamic>.from(doc.data());
          data['childId'] = doc.id;
          return SksWallet.fromMap(data);
        }).toList();
        onWalletsChanged?.call(list);
      }, onError: (_) => Future.delayed(const Duration(seconds: 5), reconnect));
    }
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
    _requestsSub?.cancel();
    _joinRequestsSub?.cancel();
    _screenTimeSub?.cancel();
    _parentProfilesSub?.cancel();
    _choresSub?.cancel();
    _rewardsSub?.cancel();
    _purchasesSub?.cancel();
    _walletsSub?.cancel();
    _childrenSub = null;
    _historySub = null;
    _goalsSub = null;
    _punishmentsSub = null;
    _notesSub = null;
    _immunitiesSub = null;
    _tradesSub = null;
    _tribunalSub = null;
    _badgesSub = null;
    _requestsSub = null;
    _joinRequestsSub = null;
    _screenTimeSub = null;
    _parentProfilesSub = null;
    _choresSub = null;
    _rewardsSub = null;
    _purchasesSub = null;
    _walletsSub = null;
  }

  void startRealtimeSync() {
    if (_familyId == null) return;
    _stopListening();
    _startListening();
    _startKeepAlive();
  }

  Future<void> markFamilyInboxRead() async {
    final currentFamilyId = _familyId;
    if (currentFamilyId == null) return;
    await FirebaseFunctions.instance.httpsCallable('markFamilyInboxRead').call({
      'familyId': currentFamilyId,
    });
  }

  /// Enregistre une action de points dans une transaction côté serveur.
  Future<Map<String, dynamic>> recordPointAction({
    required String actionId,
    required String childId,
    required int amount,
    required String reason,
    required String category,
    required bool isBonus,
    String? photoStoragePath,
    int? penaltyLinesCount,
    String? penaltyLinesInstruction,
  }) async {
    final currentFamilyId = _familyId;
    if (currentFamilyId == null) {
      throw StateError('Aucune famille connectée.');
    }
    final result = await FirebaseFunctions.instanceFor(
      region: walletFunctionsRegion,
    ).httpsCallable('recordPointAction').call(buildPointActionPayload(
          familyId: currentFamilyId,
          actionId: actionId,
          childId: childId,
          amount: amount,
          reason: reason,
          category: category,
          isBonus: isBonus,
          photoStoragePath: photoStoragePath,
          penaltyLinesCount: penaltyLinesCount,
          penaltyLinesInstruction: penaltyLinesInstruction,
        ));
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<Map<String, dynamic>> updatePenaltyLines({
    required String punishmentId,
    required bool hasPenaltyLines,
    int? count,
    String? instruction,
  }) async {
    final currentFamilyId = _familyId;
    if (currentFamilyId == null) {
      throw StateError('Aucune famille connectée.');
    }
    final result = await FirebaseFunctions.instanceFor(
      region: walletFunctionsRegion,
    ).httpsCallable('updatePenaltyLines').call({
      'familyId': currentFamilyId,
      'punishmentId': punishmentId,
      'hasPenaltyLines': hasPenaltyLines,
      if (count != null) 'penaltyLinesCount': count,
      if (instruction != null) 'penaltyLinesInstruction': instruction.trim(),
    });
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<Map<String, dynamic>> completePenaltyLines(String punishmentId) async {
    final currentFamilyId = _familyId;
    if (currentFamilyId == null) {
      throw StateError('Aucune famille connectée.');
    }
    final result = await FirebaseFunctions.instanceFor(
      region: walletFunctionsRegion,
    ).httpsCallable('completePenaltyLines').call({
      'familyId': currentFamilyId,
      'punishmentId': punishmentId,
    });
    return Map<String, dynamic>.from(result.data as Map);
  }

  /// Synchronise le nom du membre authentifié avant une action sensible.
  Future<void> syncMemberDisplayName(String displayName) async {
    final currentFamilyId = _familyId;
    final cleanName = displayName.trim();
    if (currentFamilyId == null || cleanName.isEmpty) return;
    await FirebaseFunctions.instanceFor(
      region: walletFunctionsRegion,
    ).httpsCallable('setMemberDisplayName').call({
      'familyId': currentFamilyId,
      'displayName': cleanName,
    });
  }

  Stream<List<SksWalletOperation>> watchWalletOperations(String childId) {
    if (_familyId == null) return const Stream.empty();
    return _db
        .collection('families')
        .doc(_familyId)
        .collection('wallets')
        .doc(childId)
        .collection('operations')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = Map<String, dynamic>.from(doc.data());
              data['id'] = doc.id;
              return SksWalletOperation.fromMap(data);
            }).toList());
  }

  Future<SksWalletAdjustmentResult> adjustWallet({
    required String childId,
    required String operationId,
    required String type,
    required int amount,
    required String reason,
  }) async {
    final currentFamilyId = _familyId;
    if (currentFamilyId == null) {
      throw StateError('Aucune famille connectée.');
    }
    final result = await FirebaseFunctions.instanceFor(
      region: walletFunctionsRegion,
    ).httpsCallable('adjustWallet').call(buildWalletAdjustmentPayload(
          familyId: currentFamilyId,
          childId: childId,
          operationId: operationId,
          type: type,
          amount: amount,
          reason: reason,
        ));
    return SksWalletAdjustmentResult.fromData(result.data);
  }

  /// Exécute une opération sensible côté serveur.
  ///
  /// Le client ne transmet jamais de solde, de prix ni de rôle : la Function
  /// les relit dans Firestore et applique l'opération dans une transaction.
  Future<Map<String, dynamic>> performFamilyOperation({
    required String operation,
    required String operationId,
    String? childId,
    String? rewardId,
    String? caseId,
    String? tradeId,
    String? toChildId,
    String? vote,
    int? minutes,
    int? immunityLines,
    String? description,
  }) async {
    final currentFamilyId = _familyId;
    if (currentFamilyId == null) {
      throw StateError('Aucune famille connectée.');
    }
    final payload = <String, dynamic>{
      'familyId': currentFamilyId,
      'operation': operation,
      'operationId': operationId,
      if (childId != null) 'childId': childId,
      if (rewardId != null) 'rewardId': rewardId,
      if (caseId != null) 'caseId': caseId,
      if (tradeId != null) 'tradeId': tradeId,
      if (toChildId != null) 'toChildId': toChildId,
      if (vote != null) 'vote': vote,
      if (minutes != null) 'minutes': minutes,
      if (immunityLines != null) 'immunityLines': immunityLines,
      if (description != null) 'description': description.trim(),
    };
    final result = await FirebaseFunctions.instance
        .httpsCallable('performFamilyOperation')
        .call(payload);
    return Map<String, dynamic>.from(result.data as Map);
  }

  // ─── WRITE : Children ────────────────────────────────────────
  Future<void> saveChild(ChildModel child) async {
    if (_familyId == null) return;
    try {
      final data = child.toMap();
      data['lastModifiedBy'] = deviceId;
      await _db
          .collection('families')
          .doc(_familyId)
          .collection('children')
          .doc(child.id)
          .set(data);
    } catch (e) {
      if (kDebugMode) debugPrint('saveChild error: $e');
    }
  }

  Future<void> deleteChild(String childId) async {
    if (_familyId == null) return;
    try {
      final fRef = _db.collection('families').doc(_familyId);
      var batch = _db.batch();
      int ops = 0;

      Future<void> flushIfNeeded() async {
        if (ops >= 450) {
          await batch.commit();
          batch = _db.batch();
          ops = 0;
        }
      }

      batch.delete(fRef.collection('children').doc(childId));
      ops++;

      for (final col in ['history', 'goals', 'punishments', 'immunities']) {
        final docs = await fRef
            .collection(col)
            .where('childId', isEqualTo: childId)
            .get();
        for (final doc in docs.docs) {
          batch.delete(doc.reference);
          ops++;
          await flushIfNeeded();
        }
      }

      for (final field in ['fromChildId', 'toChildId']) {
        final docs = await fRef
            .collection('trades')
            .where(field, isEqualTo: childId)
            .get();
        for (final doc in docs.docs) {
          batch.delete(doc.reference);
          ops++;
          await flushIfNeeded();
        }
      }

      if (ops > 0) await batch.commit();
    } catch (e) {
      if (kDebugMode) debugPrint('deleteChild error: $e');
    }
  }

  // ─── WRITE : History ─────────────────────────────────────────
  Future<void> saveHistoryEntry(HistoryEntry entry) async {
    final currentFamilyId = _familyId;
    if (currentFamilyId == null) return;
    await FirebaseFunctions.instanceFor(
      region: walletFunctionsRegion,
    ).httpsCallable('recordHistoryEvent').call({
      'familyId': currentFamilyId,
      'eventId': entry.id,
      'childId': entry.childId,
      'points': entry.points,
      'reason': entry.reason,
      'category': entry.category,
      'isBonus': entry.isBonus,
      if (entry.transferId != null) 'transferId': entry.transferId,
      if (entry.counterpartyChildId != null)
        'counterpartyChildId': entry.counterpartyChildId,
    });
  }

  /// Écriture groupée atomique d'un transfert de points entre deux enfants.
  /// Met à jour les deux enfants et crée les deux entrées d'historique en un
  /// seul WriteBatch pour garantir la cohérence.
  Future<void> transferPointsBatch({
    required ChildModel fromChild,
    required ChildModel toChild,
    required HistoryEntry outEntry,
    required HistoryEntry inEntry,
  }) async {
    if (_familyId == null) return;
    try {
      final batch = _db.batch();
      final familyDoc = _db.collection('families').doc(_familyId);

      // 1. Enfant source (débité)
      final fromData = fromChild.toMap();
      fromData['lastModifiedBy'] = deviceId;
      batch.set(familyDoc.collection('children').doc(fromChild.id), fromData);

      // 2. Enfant destination (crédité)
      final toData = toChild.toMap();
      toData['lastModifiedBy'] = deviceId;
      batch.set(familyDoc.collection('children').doc(toChild.id), toData);

      // 3. Historique source (transfert sortant)
      final outData = outEntry.toMap();
      outData['deviceId'] = deviceId;
      batch.set(familyDoc.collection('history').doc(outEntry.id), outData);

      // 4. Historique destination (transfert entrant)
      final inData = inEntry.toMap();
      inData['deviceId'] = deviceId;
      batch.set(familyDoc.collection('history').doc(inEntry.id), inData);

      await batch.commit();
    } catch (e) {
      if (kDebugMode) debugPrint('transferPointsBatch error: $e');
      rethrow;
    }
  }

  Future<void> clearAllHistory() async {
    if (_familyId == null) return;
    try {
      var batch = _db.batch();
      int ops = 0;
      final docs = await _db
          .collection('families')
          .doc(_familyId)
          .collection('history')
          .get();
      for (final doc in docs.docs) {
        batch.delete(doc.reference);
        ops++;
        if (ops >= 450) {
          await batch.commit();
          batch = _db.batch();
          ops = 0;
        }
      }
      if (ops > 0) await batch.commit();
    } catch (e) {
      if (kDebugMode) debugPrint('clearAllHistory error: $e');
    }
  }

  // ─── WRITE : Goals ───────────────────────────────────────────
  Future<void> saveGoal(GoalModel goal) async {
    if (_familyId == null) return;
    try {
      final data = goal.toMap();
      data['lastModifiedBy'] = deviceId;
      await _db
          .collection('families')
          .doc(_familyId)
          .collection('goals')
          .doc(goal.id)
          .set(data);
    } catch (e) {
      if (kDebugMode) debugPrint('saveGoal error: $e');
    }
  }

  Future<void> deleteHistoryEntry(String entryId) async {
    if (_familyId == null) return;
    try {
      await _db
          .collection('families')
          .doc(_familyId)
          .collection('history')
          .doc(entryId)
          .delete();
    } catch (e) {
      if (kDebugMode) debugPrint('deleteHistoryEntry error: $e');
    }
  }

  Future<void> deleteGoal(String goalId) async {
    if (_familyId == null) return;
    try {
      await _db
          .collection('families')
          .doc(_familyId)
          .collection('goals')
          .doc(goalId)
          .delete();
    } catch (e) {
      if (kDebugMode) debugPrint('deleteGoal error: $e');
    }
  }

  // ─── WRITE : Punishments ─────────────────────────────────────
  Future<void> savePunishment(PunishmentLines p) async {
    if (_familyId == null) return;
    try {
      final data = p.toMap();
      data['lastModifiedBy'] = deviceId;
      await _db
          .collection('families')
          .doc(_familyId)
          .collection('punishments')
          .doc(p.id)
          .set(data);
    } catch (e) {
      if (kDebugMode) debugPrint('savePunishment error: $e');
    }
  }

  Future<void> saveRequest(PendingRequest r) async {
    if (_familyId == null) return;
    // Relance l'exception pour que FamilyProvider puisse détecter l'échec
    final data = r.toMap();
    data['lastModifiedBy'] = deviceId;
    await _db
        .collection('families')
        .doc(_familyId)
        .collection('requests')
        .doc(r.id)
        .set(data);
  }

  Future<void> deleteRequest(String rId) async {
    if (_familyId == null) return;
    try {
      await _db
          .collection('families')
          .doc(_familyId)
          .collection('requests')
          .doc(rId)
          .delete();
    } catch (e) {
      if (kDebugMode) debugPrint('deleteRequest error: $e');
    }
  }

  Future<void> deletePunishment(String pId) async {
    if (_familyId == null) return;
    try {
      await _db
          .collection('families')
          .doc(_familyId)
          .collection('punishments')
          .doc(pId)
          .delete();
    } catch (e) {
      if (kDebugMode) debugPrint('deletePunishment error: $e');
    }
  }

  // ─── WRITE : Notes ───────────────────────────────────────────
  Future<void> saveNote(NoteModel note) async {
    if (_familyId == null) return;
    try {
      final data = note.toMap();
      data['lastModifiedBy'] = deviceId;
      await _db
          .collection('families')
          .doc(_familyId)
          .collection('notes')
          .doc(note.id)
          .set(data);
    } catch (e) {
      if (kDebugMode) debugPrint('saveNote error: $e');
    }
  }

  Future<void> deleteNote(String noteId) async {
    if (_familyId == null) return;
    try {
      await _db
          .collection('families')
          .doc(_familyId)
          .collection('notes')
          .doc(noteId)
          .delete();
    } catch (e) {
      if (kDebugMode) debugPrint('deleteNote error: $e');
    }
  }

  // ─── WRITE : Immunities ──────────────────────────────────────
  Future<void> saveImmunity(ImmunityLines im) async {
    if (_familyId == null) return;
    try {
      final data = im.toMap();
      data['lastModifiedBy'] = deviceId;
      await _db
          .collection('families')
          .doc(_familyId)
          .collection('immunities')
          .doc(im.id)
          .set(data);
    } catch (e) {
      if (kDebugMode) debugPrint('saveImmunity error: $e');
    }
  }

  Future<void> deleteImmunity(String imId) async {
    if (_familyId == null) return;
    try {
      await _db
          .collection('families')
          .doc(_familyId)
          .collection('immunities')
          .doc(imId)
          .delete();
    } catch (e) {
      if (kDebugMode) debugPrint('deleteImmunity error: $e');
    }
  }

  // ─── WRITE : Trades ──────────────────────────────────────────
  Future<void> saveTrade(TradeModel trade) async {
    if (_familyId == null) return;
    try {
      final data = trade.toMap();
      data['lastModifiedBy'] = deviceId;
      await _db
          .collection('families')
          .doc(_familyId)
          .collection('trades')
          .doc(trade.id)
          .set(data);
    } catch (e) {
      if (kDebugMode) debugPrint('saveTrade error: $e');
    }
  }

  Future<void> deleteTrade(String tradeId) async {
    if (_familyId == null) return;
    try {
      await _db
          .collection('families')
          .doc(_familyId)
          .collection('trades')
          .doc(tradeId)
          .delete();
    } catch (e) {
      if (kDebugMode) debugPrint('deleteTrade error: $e');
    }
  }

  // ─── WRITE : Tribunal ────────────────────────────────────────
  Future<void> saveTribunalCase(TribunalCase tc) async {
    if (_familyId == null) return;
    try {
      final data = tc.toMap();
      data['lastModifiedBy'] = deviceId;
      await _db
          .collection('families')
          .doc(_familyId)
          .collection('tribunal')
          .doc(tc.id)
          .set(data);
    } catch (e) {
      if (kDebugMode) debugPrint('saveTribunalCase error: $e');
    }
  }

  Future<void> deleteTribunalCase(String tcId) async {
    if (_familyId == null) return;
    try {
      await _db
          .collection('families')
          .doc(_familyId)
          .collection('tribunal')
          .doc(tcId)
          .delete();
    } catch (e) {
      if (kDebugMode) debugPrint('deleteTribunalCase error: $e');
    }
  }

  // ─── WRITE : Badges ──────────────────────────────────────────
  Future<void> saveCustomBadge(BadgeModel badge) async {
    if (_familyId == null) return;
    try {
      final data = badge.toMap();
      data['lastModifiedBy'] = deviceId;
      await _db
          .collection('families')
          .doc(_familyId)
          .collection('custom_badges')
          .doc(badge.id)
          .set(data);
    } catch (e) {
      if (kDebugMode) debugPrint('saveCustomBadge error: $e');
    }
  }

  Future<void> deleteCustomBadge(String badgeId) async {
    if (_familyId == null) return;
    try {
      await _db
          .collection('families')
          .doc(_familyId)
          .collection('custom_badges')
          .doc(badgeId)
          .delete();
    } catch (e) {
      if (kDebugMode) debugPrint('deleteCustomBadge error: $e');
    }
  }

  // ─── BOUTIQUE : Récompenses ──────────────────────────────────
  Future<void> saveReward(Map<String, dynamic> data, String id) async {
    if (_familyId == null) return;
    try {
      await _db
          .collection('families')
          .doc(_familyId)
          .collection('rewards')
          .doc(id)
          .set(data);
    } catch (e) {
      if (kDebugMode) debugPrint('saveReward error: $e');
    }
  }

  Future<void> deleteReward(String id) async {
    if (_familyId == null) return;
    try {
      // Tombstone conservé dans Firestore pour que tous les appareils
      // sachent que cette récompense doit être supprimée localement.
      await _db
          .collection('families')
          .doc(_familyId)
          .collection('rewards')
          .doc(id)
          .set({
        'id': id,
        'isDeleted': true,
        'deletedAt': FieldValue.serverTimestamp(),
        'lastModifiedBy': deviceId,
      });
    } catch (e) {
      if (kDebugMode) debugPrint('deleteReward error: $e');
    }
  }

  Future<void> savePurchase(Map<String, dynamic> data) async {
    if (_familyId == null) return;
    try {
      // 🔒 Utilise un ID stable (défini par l'appelant) au lieu de .add()
      final purchaseId = data['id'] as String? ??
          'purch_${DateTime.now().millisecondsSinceEpoch}';
      await _db
          .collection('families')
          .doc(_familyId)
          .collection('purchases')
          .doc(purchaseId)
          .set(data);
    } catch (e) {
      if (kDebugMode) debugPrint('savePurchase error: $e');
    }
  }

  // ─── CHORES (tâches checklist) ──────────────────────────────
  Future<void> saveChore(Map<String, dynamic> data, String id) async {
    if (_familyId == null) return;
    try {
      await _db
          .collection('families')
          .doc(_familyId)
          .collection('chores')
          .doc(id)
          .set(data);
    } catch (e) {
      if (kDebugMode) debugPrint('saveChore error: $e');
    }
  }

  Future<void> deleteChore(String id) async {
    if (_familyId == null) return;
    try {
      await _db
          .collection('families')
          .doc(_familyId)
          .collection('chores')
          .doc(id)
          .delete();
    } catch (e) {
      if (kDebugMode) debugPrint('deleteChore error: $e');
    }
  }

  // ─── SCREEN TIME ACCOUNTS ───────────────────────────────────
  Future<void> saveScreenTimeAccount(
      String childId, Map<String, dynamic> data) async {
    if (_familyId == null) return;
    try {
      await _db
          .collection('families')
          .doc(_familyId)
          .collection('screen_time_accounts')
          .doc(childId)
          .set(data);
    } catch (e) {
      if (kDebugMode) debugPrint('saveScreenTimeAccount error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> loadScreenTimeAccounts() async {
    if (_familyId == null) return [];
    try {
      final snap = await _db
          .collection('families')
          .doc(_familyId)
          .collection('screen_time_accounts')
          .get();
      return snap.docs.map((doc) {
        final d = Map<String, dynamic>.from(doc.data());
        d['childId'] = doc.id;
        return d;
      }).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('loadScreenTimeAccounts error: $e');
      return [];
    }
  }

  // ─── WRITE : Screen Time ─────────────────────────────────────
  Future<void> saveScreenTimeValue(String key, dynamic value) async {
    if (_familyId == null) return;
    try {
      await _db
          .collection('families')
          .doc(_familyId)
          .collection('screen_time')
          .doc(key)
          .set({
        'value': value,
        'lastModifiedBy': deviceId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) debugPrint('saveScreenTimeValue error: $e');
    }
  }

  // ─── Changement de code ──────────────────────────────────────
  Future<void> changeFamilyCode(String newCode) async {
    final familyId = _familyId;

    if (familyId == null) {
      throw StateError('Non connecté.');
    }

    final result = await FamilyManagementService().changeFamilyCode(
      familyId: familyId,
      newCode: newCode,
    );

    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setString(
      'family_code',
      result.code,
    );

    if (!saved) {
      throw StateError(
        'Le code a été modifié sur le serveur, mais pas '
        'sur cet appareil.',
      );
    }

    await FcmService().registerToken();
  }

  // ─── Reset ───────────────────────────────────────────────────
  Future<void> resetAllScores() async {
    if (_familyId == null) return;
    try {
      final docs = await _db
          .collection('families')
          .doc(_familyId)
          .collection('children')
          .get();
      var batch = _db.batch();
      int ops = 0;
      for (final doc in docs.docs) {
        batch.update(doc.reference, {
          'points': 0,
          'level': 1,
          'badgeIds': [],
          'lastModifiedBy': deviceId,
        });
        ops++;
        if (ops >= 450) {
          await batch.commit();
          batch = _db.batch();
          ops = 0;
        }
      }
      if (ops > 0) await batch.commit();
    } catch (e) {
      if (kDebugMode) debugPrint('resetAllScores error: $e');
    }
  }

  // ─── Upload complet ──────────────────────────────────────────
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
    try {
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

      for (final c in children) {
        final d = c.toMap();
        d['lastModifiedBy'] = deviceId;
        batch.set(fRef.collection('children').doc(c.id), d);
        ops++;
        await flush();
      }
      for (final h in history) {
        final d = h.toMap();
        d['deviceId'] = deviceId;
        batch.set(fRef.collection('history').doc(h.id), d);
        ops++;
        await flush();
      }
      for (final g in goals) {
        final d = g.toMap();
        d['lastModifiedBy'] = deviceId;
        batch.set(fRef.collection('goals').doc(g.id), d);
        ops++;
        await flush();
      }
      for (final p in punishments) {
        final d = p.toMap();
        d['lastModifiedBy'] = deviceId;
        batch.set(fRef.collection('punishments').doc(p.id), d);
        ops++;
        await flush();
      }
      for (final n in notes) {
        final d = n.toMap();
        d['lastModifiedBy'] = deviceId;
        batch.set(fRef.collection('notes').doc(n.id), d);
        ops++;
        await flush();
      }
      for (final im in immunities) {
        final d = im.toMap();
        d['lastModifiedBy'] = deviceId;
        batch.set(fRef.collection('immunities').doc(im.id), d);
        ops++;
        await flush();
      }
      for (final t in trades) {
        final d = t.toMap();
        d['lastModifiedBy'] = deviceId;
        batch.set(fRef.collection('trades').doc(t.id), d);
        ops++;
        await flush();
      }
      for (final tc in tribunalCases) {
        final d = tc.toMap();
        d['lastModifiedBy'] = deviceId;
        batch.set(fRef.collection('tribunal').doc(tc.id), d);
        ops++;
        await flush();
      }
      for (final b in customBadges) {
        final d = b.toMap();
        d['lastModifiedBy'] = deviceId;
        batch.set(fRef.collection('custom_badges').doc(b.id), d);
        ops++;
        await flush();
      }
      for (final e in screenTimeData.entries) {
        batch.set(fRef.collection('screen_time').doc(e.key),
            {'value': e.value, 'lastModifiedBy': deviceId});
        ops++;
        await flush();
      }
      if (ops > 0) await batch.commit();
    } catch (e) {
      if (kDebugMode) debugPrint('uploadAllData error: $e');
    }
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

  // ─── Force refresh ───────────────────────────────────────────
  Future<void> forceRefresh({bool throwOnError = false}) async {
    if (_familyId == null) return;
    try {
      final fRef = _db.collection('families').doc(_familyId);
      const opts = GetOptions(source: Source.server);

      final cs = await fRef.collection('children').get(opts);
      final children = <ChildModel>[];
      final cr = <Map<String, dynamic>>[];
      for (final doc in cs.docs) {
        final d = Map<String, dynamic>.from(doc.data());
        d['id'] = doc.id;
        try {
          children.add(ChildModel.fromMap(d));
          cr.add(d);
        } catch (_) {}
      }
      onChildrenChanged?.call(children, cr);

      final hs = await fRef.collection('history').get(opts);
      final history = <HistoryEntry>[];
      final hr = <Map<String, dynamic>>[];
      for (final doc in hs.docs) {
        final d = Map<String, dynamic>.from(doc.data());
        d['id'] = doc.id;
        try {
          history.add(HistoryEntry.fromMap(d));
          hr.add(d);
        } catch (_) {}
      }
      history.sort((a, b) => b.date.compareTo(a.date));
      onHistoryChanged?.call(history, hr);

      final gs = await fRef.collection('goals').get(opts);
      final goals = <GoalModel>[];
      final gr = <Map<String, dynamic>>[];
      for (final doc in gs.docs) {
        final d = Map<String, dynamic>.from(doc.data());
        d['id'] = doc.id;
        try {
          goals.add(GoalModel.fromMap(d));
          gr.add(d);
        } catch (_) {}
      }
      onGoalsChanged?.call(goals, gr);

      final ps = await fRef.collection('punishments').get(opts);
      final punishments = <PunishmentLines>[];
      final pr = <Map<String, dynamic>>[];
      for (final doc in ps.docs) {
        final d = Map<String, dynamic>.from(doc.data());
        d['id'] = doc.id;
        try {
          punishments.add(PunishmentLines.fromMap(d));
          pr.add(d);
        } catch (_) {}
      }
      onPunishmentsChanged?.call(punishments, pr);

      final ns = await fRef.collection('notes').get(opts);
      final notes = ns.docs.map((doc) {
        final d = Map<String, dynamic>.from(doc.data());
        d['id'] = doc.id;
        return NoteModel.fromMap(d);
      }).toList();
      notes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      onNotesChanged?.call(notes);

      final ims = await fRef.collection('immunities').get(opts);
      onImmunitiesChanged?.call(ims.docs.map((doc) {
        final d = Map<String, dynamic>.from(doc.data());
        d['id'] = doc.id;
        return ImmunityLines.fromMap(d);
      }).toList());

      final ts = await fRef.collection('trades').get(opts);
      final trades = ts.docs.map((doc) {
        final d = Map<String, dynamic>.from(doc.data());
        d['id'] = doc.id;
        return TradeModel.fromMap(d);
      }).toList();
      trades.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      onTradesChanged?.call(trades);

      final tcs = await fRef.collection('tribunal').get(opts);
      onTribunalChanged?.call(tcs.docs.map((doc) {
        final d = Map<String, dynamic>.from(doc.data());
        d['id'] = doc.id;
        return TribunalCase.fromMap(d);
      }).toList());

      final bs = await fRef.collection('custom_badges').get(opts);
      onBadgesChanged?.call(bs.docs.map((doc) {
        final d = Map<String, dynamic>.from(doc.data());
        d['id'] = doc.id;
        return BadgeModel.fromMap(d);
      }).toList());

      final sts = await fRef.collection('screen_time').get(opts);
      final Map<String, dynamic> stData = {};
      for (final doc in sts.docs) {
        stData[doc.id] = doc.data()['value'];
      }
      onScreenTimeChanged?.call(stData);

      _markDataReceived();
    } catch (e) {
      if (kDebugMode) debugPrint('forceRefresh error: $e');
      if (throwOnError) rethrow;
      reconnect();
    }
  }

  // ─── Profils parents ──────────────────────────────────────────────────
  Future<void> saveParentProfile(ParentProfile profile) async {
    if (_familyId == null) return;
    try {
      final data = profile.toMap();
      data['lastModifiedBy'] = deviceId;
      await _db
          .collection('families')
          .doc(_familyId)
          .collection('parent_profiles')
          .doc(profile.id)
          .set(data);
    } catch (e) {
      if (kDebugMode) debugPrint('saveParentProfile error: $e');
    }
  }

  Future<void> deleteParentProfile(String profileId) async {
    if (_familyId == null) return;
    try {
      await _db
          .collection('families')
          .doc(_familyId)
          .collection('parent_profiles')
          .doc(profileId)
          .delete();
    } catch (e) {
      if (kDebugMode) debugPrint('deleteParentProfile error: $e');
    }
  }
}
