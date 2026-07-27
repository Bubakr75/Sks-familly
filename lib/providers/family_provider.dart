// lib/providers/family_provider.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
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
import '../models/pending_request.dart';
import '../models/parent_profile.dart';
import '../models/reward_model.dart';
import '../models/chore_model.dart';
import '../models/wheel_segment.dart';
import '../models/screen_time_account.dart';
import '../models/sks_wallet.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import '../utils/image_compressor.dart';
import '../services/voice_service.dart';
import '../services/sound_service.dart';

/// Résultat de createRequest pour exploiter la déduplication.
enum RequestResult { created, duplicate, failed }

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
  late Box _parentProfilesBox;
  late Box _tradesBox;
  late Box _rewardsBox;
  late Box _requestsBox;
  late Box _purchasesBox;
  late Box _choresBox;

  List<ChildModel>      _children      = [];
  List<HistoryEntry>    _history       = [];
  List<GoalModel>       _goals         = [];
  List<NoteModel>       _notes         = [];
  List<PunishmentLines> _punishments   = [];
  List<ImmunityLines>   _immunities    = [];
  List<TribunalCase>    _tribunalCases = [];
  List<BadgeModel>      _customBadges  = [];
  List<ParentProfile>   _parentProfiles = [];
  List<TradeModel>      _trades        = [];
  List<PendingRequest>  _pendingRequests = [];
  List<RewardModel>     _rewards = [];
  List<Map<String, dynamic>> _purchases = [];
  List<ChoreModel>      _chores = [];
  List<WheelSegment>    _wheelSegments = [];
  final Map<String, ScreenTimeAccount> _screenTimeAccounts = {};
  final Map<String, SksWallet> _wallets = {};
  Timer? _overtimeTimer;

  // ─── Verrou anti-double-traitement pour les transferts ──────
  bool _isTransferring = false;

  // ─── Verrou anti-doublon pour createRequest ─────────────────
  final Set<String> _requestKeysInFlight = {};

  // ─── Soldes boutique ──────────────────────────────────────────
  int _saleDiscountPercent = 0;     // ex: 50 = -50%
  DateTime? _saleEndDate;           // null = pas de vente en cours
  String _saleLabel = '';           // ex: "Soldes d'été"
  Timer? _saleTimer;

  // ─── État de synchronisation (feedback UI) ──────────────────
  bool _isReconnecting = false;
  DateTime? _lastSyncAt;
  bool get isReconnecting => _isReconnecting;

  // Demandes supprimées (approuvées/rejetées) : on les exclut du merge
  // Firestore pendant ~1min pour éviter qu'elles réapparaissent avant que la
  // suppression distante ne soit propagée.
  final Set<String> _deletedRequestIds = {};
  void _markRequestDeleted(String id) {
    _deletedRequestIds.add(id);
    Future.delayed(const Duration(seconds: 60), () => _deletedRequestIds.remove(id));
  }

  DateTime? get lastSyncAt => _lastSyncAt;
  String? get lastSyncLabel {
    final s = _lastSyncAt;
    if (s == null) return null;
    final diff = DateTime.now().difference(s);
    if (diff.inSeconds < 5) return "À l'instant";
    if (diff.inMinutes < 1) return 'Il y a ${diff.inSeconds}s';
    if (diff.inHours < 1) return 'Il y a ${diff.inMinutes} min';
    if (diff.inDays < 1) return 'Il y a ${diff.inHours}h';
    return 'Il y a ${diff.inDays}j';
  }

  final Set<String> _deletedEntryIds = {};

  // ══════════════════════════════════════════════════════════
  // CORRECTIF ANTI-DISPARITION "” délai 30s au lieu de 5s
  // ══════════════════════════════════════════════════════════
  final Set<String> _pendingIds = {};

  void _markPending(String id) {
    _pendingIds.add(id);
    Future.delayed(const Duration(seconds: 30), () => _pendingIds.remove(id));
  }

  List<T> _mergeWithPending<T>(
    List<T> fromFirestore,
    List<T> currentLocal,
    String Function(T) getId,
  ) {
    final firestoreIds = fromFirestore.map(getId).toSet();
    final stillPending = currentLocal.where((item) =>
        _pendingIds.contains(getId(item)) &&
        !firestoreIds.contains(getId(item))).toList();
    return [...stillPending, ...fromFirestore];
  }
  // ══════════════════════════════════════════════════════════

  String? _familyCode;
  String  _currentParentName = 'Parent';

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
  List<PendingRequest>  get pendingRequests   => _pendingRequests;
  List<RewardModel>     get rewards            => _rewards;
  List<Map<String, dynamic>> get purchases     => _purchases;
  List<ChoreModel>      get chores             => _chores;
  List<WheelSegment>    get wheelSegments      => _wheelSegments;
  Map<String, SksWallet> get wallets =>
      Map<String, SksWallet>.unmodifiable(_wallets);

  // ─── Getters Soldes boutique ──────────────────────────────────
  int    get saleDiscountPercent => _saleDiscountPercent;
  DateTime? get saleEndDate      => _saleEndDate;
  String get saleLabel           => _saleLabel;
  bool   get isSaleActive        => _saleDiscountPercent > 0 &&
      (_saleEndDate == null || _saleEndDate!.isAfter(DateTime.now()));

  /// Calcule le prix soldé d'une récompense
  int salePrice(int originalCost) {
    if (!isSaleActive) return originalCost;
    final discounted = (originalCost * (100 - _saleDiscountPercent) / 100).round();
    return discounted > 0 ? discounted : 1;
  }

  /// Démarre une vente (parent). percent: 10-90, duration: en heures
  Future<void> startSale({required int percent, required int durationHours, String label = 'Soldes'}) async {
    _saleDiscountPercent = percent.clamp(1, 90);
    _saleEndDate = DateTime.now().add(Duration(hours: durationHours));
    _saleLabel = label;
    await _metaBox.put('sale_percent', _saleDiscountPercent);
    await _metaBox.put('sale_end', _saleEndDate!.toIso8601String());
    await _metaBox.put('sale_label', _saleLabel);
    // Timer pour arrêter automatiquement la vente
    _saleTimer?.cancel();
    _saleTimer = Timer(Duration(hours: durationHours), () {
      stopSale();
    });
    notifyListeners();
  }

  /// Arrête la vente immédiatement
  Future<void> stopSale() async {
    _saleDiscountPercent = 0;
    _saleEndDate = null;
    _saleLabel = '';
    _saleTimer?.cancel();
    _saleTimer = null;
    await _metaBox.delete('sale_percent');
    await _metaBox.delete('sale_end');
    await _metaBox.delete('sale_label');
    notifyListeners();
  }

  /// Charge l'état de la vente depuis Hive (au démarrage)
  void _loadSaleState() {
    final pct = _metaBox.get('sale_percent');
    if (pct != null) {
      _saleDiscountPercent = (pct as num).toInt();
      final endStr = _metaBox.get('sale_end');
      if (endStr != null) {
        _saleEndDate = DateTime.tryParse(endStr as String);
        // Si la vente a expiré pendant que l'app était fermée
        if (_saleEndDate != null && _saleEndDate!.isBefore(DateTime.now())) {
          _saleDiscountPercent = 0;
          _saleEndDate = null;
        } else if (_saleEndDate != null) {
          // Relance le timer pour l'expiration automatique
          final remaining = _saleEndDate!.difference(DateTime.now());
          _saleTimer?.cancel();
          _saleTimer = Timer(remaining, () => stopSale());
        }
      }
      _saleLabel = _metaBox.get('sale_label') as String? ?? '';
    }
  }

  // ─── Segments de la roue de la fortune ────────────────────────
  void _loadWheelSegments() {
    final raw = _metaBox.get('wheel_segments');
    if (raw != null) {
      try {
        final list = jsonDecode(raw as String) as List;
        _wheelSegments = list
            .map((m) => WheelSegment.fromMap(Map<String, dynamic>.from(m)))
            .toList();
      } catch (_) {
        _wheelSegments = WheelSegment.defaults();
      }
    } else {
      _wheelSegments = WheelSegment.defaults();
      _saveWheelSegments();
    }
  }

  void _saveWheelSegments() {
    _metaBox.put('wheel_segments',
        jsonEncode(_wheelSegments.map((s) => s.toMap()).toList()));
  }

  Future<void> addWheelSegment(WheelSegment segment) async {
    _wheelSegments.add(segment);
    _saveWheelSegments();
    notifyListeners();
  }

  Future<void> updateWheelSegment(WheelSegment segment) async {
    final idx = _wheelSegments.indexWhere((s) => s.id == segment.id);
    if (idx >= 0) _wheelSegments[idx] = segment;
    _saveWheelSegments();
    notifyListeners();
  }

  Future<void> deleteWheelSegment(String id) async {
    if (_wheelSegments.length <= 2) return; // minimum 2 segments
    _wheelSegments.removeWhere((s) => s.id == id);
    _saveWheelSegments();
    notifyListeners();
  }

  /// Récupère le compte de temps d'écran d'un enfant
  ScreenTimeAccount getScreenTimeAccount(String childId) {
    return _screenTimeAccounts[childId] ?? ScreenTimeAccount(childId: childId);
  }
  List<ParentProfile>   get parentProfiles    => _parentProfiles;
  String?               get familyCode        => _familyCode;
  String?               get familyId          => _firestore.familyId;
  String?               get memberRole        => _firestore.memberRole;
  String?               get memberChildId     => _firestore.memberChildId;
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

  // ───────────────────────────────────────────────────────────
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
    _parentProfilesBox = await Hive.openBox('parent_profiles');
    _tradesBox      = await Hive.openBox('trades');
    _requestsBox    = await Hive.openBox('requests');
    _rewardsBox     = await Hive.openBox('rewards');
    _purchasesBox   = await Hive.openBox('purchases');
    _choresBox      = await Hive.openBox('chores');
    _loadLocal();
    _loadSaleState();
    _loadWheelSegments();
    try {
      await _firestore.init();
      _familyCode = await _firestore.getFamilyCode();
      if (_firestore.isConnected) _setupFirestoreCallbacks();
    } catch (e) {
      if (kDebugMode) debugPrint('Firestore init error: $e');
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _stopOvertimeChecker();
    _saleTimer?.cancel();
    _firestore.dispose();
    super.dispose();
  }

  // ───────────────────────────────────────────────────────────
  Future<void> _loadLocal() async {
    _children = _childrenBox.values
        .map((v) => ChildModel.fromMap(
            Map<String, dynamic>.from(jsonDecode(v as String))))
        .toList();
    _history = _historyBox.values
        .map((v) => HistoryEntry.fromMap(
            Map<String, dynamic>.from(jsonDecode(v as String))))
        .where((h) => !_deletedEntryIds.contains(h.id))
        .toList();
    _history.sort((a, b) => b.date.compareTo(a.date));
    _goals = _goalsBox.values
        .map((v) => GoalModel.fromMap(
            Map<String, dynamic>.from(jsonDecode(v as String))))
        .toList();
    _notes = _notesBox.values
        .map((v) => NoteModel.fromMap(
            Map<String, dynamic>.from(jsonDecode(v as String))))
        .toList();
    _punishments = _punishmentsBox.values
        .map((v) => PunishmentLines.fromMap(
            Map<String, dynamic>.from(jsonDecode(v as String))))
        .toList();
    _immunities = _immunitiesBox.values
        .map((v) => ImmunityLines.fromMap(
            Map<String, dynamic>.from(jsonDecode(v as String))))
        .toList();
    _tribunalCases = _tribunalBox.values
        .map((v) => TribunalCase.fromMap(
            Map<String, dynamic>.from(jsonDecode(v as String))))
        .toList();
    _customBadges = _badgesBox.values
        .map((v) => BadgeModel.fromMap(
            Map<String, dynamic>.from(jsonDecode(v as String))))
        .toList();
    _pendingRequests = _requestsBox.values
        .map((v) => PendingRequest.fromMap(
            Map<String, dynamic>.from(jsonDecode(v as String))))
        .toList();
    _rewards = _rewardsBox.values
        .map((v) => RewardModel.fromMap(
            Map<String, dynamic>.from(jsonDecode(v as String))))
        .toList();
    // Si aucune récompense, on charge les défauts
    if (_rewards.isEmpty) {
      _rewards = RewardModel.defaultRewards;
      for (final r in _rewards) {
        await _rewardsBox.put(r.id, jsonEncode(r.toMap()));
      }
    }
    _trades = _tradesBox.values
        .map((v) => TradeModel.fromMap(
            Map<String, dynamic>.from(jsonDecode(v as String))))
        .toList();
    // Chargement des achats boutique
    _purchases = _purchasesBox.values
        .map((v) => Map<String, dynamic>.from(jsonDecode(v as String)))
        .toList();
    _purchases.sort((a, b) => (b['date'] ?? '').compareTo(a['date'] ?? ''));
    // Charger les tâches personnalisables
    _chores = _choresBox.values
        .map((v) => ChoreModel.fromMap(
            Map<String, dynamic>.from(jsonDecode(v as String))))
        .toList();
    if (_chores.isEmpty) {
      _chores = ChoreModel.defaultChores;
      for (final c in _chores) {
        await _choresBox.put(c.id, jsonEncode(c.toMap()));
      }
    }
    // 🔧 MIGRATION : les anciennes tâches n'ont pas isIndividual → on les met à jour
    // Les tâches partagées par défaut : vaisselle, poubelles, animaux
    const sharedLabels = ['Débarrasser la table', 'Sortir les poubelles', 'Nourrir les animaux', 'Vaisselle', 'Poubelle'];
    bool choresUpdated = false;
    for (final chore in _chores) {
      if (sharedLabels.any((s) => chore.label.toLowerCase().contains(s.toLowerCase()))) {
        if (chore.isIndividual) { chore.isIndividual = false; choresUpdated = true; }
      }
    }
    if (choresUpdated) {
      for (final c in _chores) {
        await _choresBox.put(c.id, jsonEncode(c.toMap()));
      }
    }
    _chores.sort((a, b) => a.order.compareTo(b.order));
    // 🔧 FIX : charger les profils parents depuis le local (sinon disparus au redémarrage)
    _parentProfiles = _parentProfilesBox.values
        .map((v) => ParentProfile.fromMap(
            Map<String, dynamic>.from(jsonDecode(v as String))))
        .toList();
    _currentParentName =
        _metaBox.get('current_parent', defaultValue: 'Parent') as String;
  }

  // ───────────────────────────────────────────────────────────
  void _setupFirestoreCallbacks() {
    // ✅ CORRIGÉ : merge basé sur _pendingIds (et non plus sur la comparaison
    //    de points, qui annulait les pénalités).
    //    Pendant 30s après une écriture locale (addPoints, punition...), on
    //    garde la valeur locale pour ne pas se faire écraser par l'ancienne
    //    valeur distante qui n'a pas encore été répercutée.
    _firestore.onChildrenChanged = (list, _) {
      // Marquer la synchro réussie (feedback UI)
      _lastSyncAt = DateTime.now();
      if (_isReconnecting) _isReconnecting = false;

      final Map<String, ChildModel> firestoreMap = {
        for (var c in list) c.id: c
      };
      final merged = <ChildModel>[];
      for (final local in _children) {
        final remote = firestoreMap[local.id];
        if (remote == null) {
          // Enfant pas (encore) confirmé sur Firestore → on garde le local
          merged.add(local);
        } else if (_pendingIds.contains(local.id)) {
          // Écriture locale très récente → on garde le local pour éviter
          // que la vieille valeur distante n'annule une pénalité/un bonus
          merged.add(local);
        } else {
          // Sinon, c'est la valeur distante qui fait foi (multi-appareils)
          merged.add(remote);
        }
      }
      // Ajouter les enfants présents sur Firestore mais pas encore en local
      for (final remote in list) {
        if (!_children.any((c) => c.id == remote.id)) {
          merged.add(remote);
        }
      }
      _children = merged;
      _saveBoxFromList(_childrenBox, _children, (e) => e.id, (e) => e.toMap());
      notifyListeners();
    };

    _firestore.onHistoryChanged = (list, _) {
      final filtered = list.where((h) => !_deletedEntryIds.contains(h.id)).toList();
      _history = _mergeWithPending(filtered, _history, (h) => h.id);
      _history.sort((a, b) => b.date.compareTo(a.date));
      _saveBoxFromList(_historyBox, _history, (e) => e.id, (e) => e.toMap());
      notifyListeners();
    };
    _firestore.onWalletsChanged = (list) {
      _wallets
        ..clear()
        ..addEntries(list.map((wallet) => MapEntry(wallet.childId, wallet)));
      notifyListeners();
    };
    _firestore.onGoalsChanged = (list, _) {
      _goals = _mergeWithPending(list, _goals, (g) => g.id);
      _saveBoxFromList(_goalsBox, _goals, (e) => e.id, (e) => e.toMap());
      notifyListeners();
    };
    _firestore.onPunishmentsChanged = (list, _) {
      _punishments = _mergeWithPending(list, _punishments, (p) => p.id);
      _saveBoxFromList(_punishmentsBox, _punishments, (e) => e.id, (e) => e.toMap());
      notifyListeners();
    };
    _firestore.onNotesChanged = (list) {
      _notes = _mergeWithPending(list, _notes, (n) => n.id);
      _saveBoxFromList(_notesBox, _notes, (e) => e.id, (e) => e.toMap());
      notifyListeners();
    };
    _firestore.onImmunitiesChanged = (list) {
      _immunities = _mergeWithPending(list, _immunities, (im) => im.id);
      _saveBoxFromList(_immunitiesBox, _immunities, (e) => e.id, (e) => e.toMap());
      notifyListeners();
    };
    _firestore.onTradesChanged = (list) {
      _trades = _mergeWithPending(list, _trades, (t) => t.id);
      _saveBoxFromList(_tradesBox, _trades, (e) => e.id, (e) => e.toMap());
      notifyListeners();
    };
    _firestore.onRequestsChanged = (list) {
      // Exclure les demandes récemment approuvées/rejetées (pas encore supprimées
      // côté Firestore) pour éviter qu'elles réapparaissent.
      final filtered = list.where((r) => !_deletedRequestIds.contains(r.id)).toList();
      _pendingRequests = _mergeWithPending(filtered, _pendingRequests, (r) => r.id);
      _saveBoxFromList(_requestsBox, _pendingRequests, (e) => e.id, (e) => e.toMap());
      notifyListeners();
    };
    _firestore.onTribunalChanged = (list) {
      _tribunalCases = _mergeWithPending(list, _tribunalCases, (c) => c.id);
      _saveBoxFromList(_tribunalBox, _tribunalCases, (e) => e.id, (e) => e.toMap());
      notifyListeners();
    };
    _firestore.onBadgesChanged = (list) {
      _customBadges = _mergeWithPending(list, _customBadges, (b) => b.id);
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
    _firestore.onParentProfilesChanged = (list) {
      _parentProfiles = list;
      // 🔧 FIX : persister en local pour survivre au redémarrage
      _saveBoxFromList(_parentProfilesBox, _parentProfiles, (e) => e.id, (e) => e.toMap());
      notifyListeners();
    };
    // 🔧 FIX : synchroniser les tâches (chores) depuis Firestore
    _firestore.onChoresChanged = (list) {
      _chores = list.map((d) => ChoreModel.fromMap(d)).toList();
      _chores.sort((a, b) => a.order.compareTo(b.order));
      // Sauvegarder en local
      _saveBoxFromList(_choresBox, _chores, (e) => e.id, (e) => e.toMap());
      notifyListeners();
    };
    // Synchroniser les récompenses boutique depuis Firestore.
    // Les suppressions sont propagées avec un tombstone `isDeleted`.
    // Les récompenses encore uniquement locales sont envoyées vers Firestore.
    _firestore.onRewardsChanged = (list) {
      final deletedIds = list
          .where((data) => data['isDeleted'] == true)
          .map((data) => data['id'] as String? ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();

      if (deletedIds.isNotEmpty) {
        _rewards.removeWhere((reward) => deletedIds.contains(reward.id));
        for (final id in deletedIds) {
          unawaited(_rewardsBox.delete(id));
        }
      }

      final remoteRewards = list
          .where((data) => data['isDeleted'] != true)
          .map((data) => RewardModel.fromMap(data))
          .toList();

      for (final remote in remoteRewards) {
        final index = _rewards.indexWhere((reward) => reward.id == remote.id);
        if (index == -1) {
          _rewards.add(remote);
        } else {
          _rewards[index] = remote;
        }
      }

      final remoteIds = remoteRewards.map((reward) => reward.id).toSet();
      for (final local in _rewards) {
        if (!remoteIds.contains(local.id) &&
            !deletedIds.contains(local.id) &&
            _firestore.isConnected) {
          unawaited(_firestore.saveReward(local.toMap(), local.id));
        }
      }

      _rewards.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      for (final reward in _rewards) {
        unawaited(
          _rewardsBox.put(reward.id, jsonEncode(reward.toMap())),
        );
      }

      notifyListeners();
    };

    // 🔒 Listener pour les achats boutique (avec merge pour ne pas perdre de données)
    _firestore.onPurchasesChanged = (list) {
      final remoteIds = <String>{};
      for (final remote in list) {
        final id = remote['id'] as String? ?? '';
        if (id.isEmpty) continue;
        remoteIds.add(id);
        // Chercher si on a déjà cet achat en local
        final localIdx = _purchases.indexWhere((p) => p['id'] == id);
        if (localIdx == -1) {
          // Nouvel achat distant → ajouter
          _purchases.insert(0, remote);
        } else {
          // Mettre à jour le statut si différent (pending → approved/rejected)
          _purchases[localIdx] = remote;
        }
      }
      // 🔒 Préserver les achats locaux non synchronisés
      // (ne pas supprimer ceux qui ne sont pas sur Firestore)
      _purchases.sort((a, b) => (b['date'] ?? '').compareTo(a['date'] ?? ''));
      // Sauvegarder en local sans clear
      for (final p in _purchases) {
        final id = p['id'] as String? ?? '';
        if (id.isNotEmpty) {
          _purchasesBox.put(id, jsonEncode(p));
        }
      }
      notifyListeners();
    };
  }

  // ───────────────────────────────────────────────────────────
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
    _saveBoxFromList(_childrenBox,    _children,    (e) => e.id, (e) => e.toMap());
    _saveBoxFromList(_historyBox,     _history,     (e) => e.id, (e) => e.toMap());
    _saveBoxFromList(_goalsBox,       _goals,       (e) => e.id, (e) => e.toMap());
    _saveBoxFromList(_notesBox,       _notes,       (e) => e.id, (e) => e.toMap());
    _saveBoxFromList(_punishmentsBox, _punishments, (e) => e.id, (e) => e.toMap());
    _saveBoxFromList(_immunitiesBox,  _immunities,  (e) => e.id, (e) => e.toMap());
    _saveBoxFromList(_tradesBox,      _trades,      (e) => e.id, (e) => e.toMap());
  }

  // ───────────────────────────────────────────────────────────
  Future<void> reconnectFirestore() async {
    if (_firestore.isConnected) {
      _isReconnecting = true;
      notifyListeners();
      try {
        _firestore.reconnect();
        _setupFirestoreCallbacks();
      } finally {
        // On laisse _isReconnecting true jusqu'à la prochaine donnée reçue
        // (le 1er callback le repassera à false), avec un garde-fou de 6s.
        Future.delayed(const Duration(seconds: 6), () {
          if (_isReconnecting) {
            _isReconnecting = false;
            notifyListeners();
          }
        });
      }
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
    if (ok) {
      _familyCode = code;
      _setupFirestoreCallbacks();
      notifyListeners();
    }
    return ok;
  }

  Future<String> migrateLegacyFamily(String migrationSecret) async {
    final code = await _firestore.migrateLegacyFamily(
      migrationSecret: migrationSecret,
    );

    _familyCode = code;
    _setupFirestoreCallbacks();
    notifyListeners();

    return code;
  }

  SksWallet getWalletForChild(String childId) =>
      _wallets[childId] ?? SksWallet.empty(childId);

  Stream<List<SksWalletOperation>> watchWalletOperations(String childId) =>
      _firestore.watchWalletOperations(childId);

  Future<SksWalletAdjustmentResult> adjustWallet({
    required String childId,
    required String type,
    required int amount,
    required String reason,
    String? operationId,
  }) {
    return _firestore.adjustWallet(
      childId: childId,
      operationId: operationId ?? _uuid.v4(),
      type: type,
      amount: amount,
      reason: reason,
    );
  }

  Future<void> disconnectFamily() async {
    await _firestore.disconnectFamily();
    _familyCode = null;
    _wallets.clear();
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
    try { return _children.firstWhere((c) => c.id == id); }
    catch (_) { return null; }
  }

  List<HistoryEntry> getHistoryForChild(String childId) =>
      _history.where((h) => h.childId == childId).toList();

  Future<void> deleteHistoryEntry(String entryId) async {
    final entry = _history.firstWhere(
      (h) => h.id == entryId,
      orElse: () => HistoryEntry(
          id: entryId, childId: '', points: 0, reason: ''),
    );
    // 🔒 Empêcher la suppression d'une seule moitié d'un transfert
    if (entry.isPointsTransfer) return;
    // ↩️ Inverse l'effet des points sur l'enfant
    if (entry.childId.isNotEmpty) {
      final child = getChild(entry.childId);
      if (child != null) {
        if (entry.isBonus) {
          child.points -= entry.points; // on retire le bonus
        } else {
          child.points += entry.points; // on rend les points d'une pénalité
        }
        if (child.points < 0) child.points = 0;
        _markPending(child.id);
        await _childrenBox.put(child.id, jsonEncode(child.toMap()));
        if (_firestore.isConnected) await _firestore.saveChild(child);
      }
    }
    _deletedEntryIds.add(entryId);
    _history.removeWhere((h) => h.id == entryId);
    await _historyBox.delete(entryId);
    if (_firestore.isConnected) await _firestore.deleteHistoryEntry(entryId);
    notifyListeners();
  }

  /// Modifie une entrée d'historique (points / raison / type) et recalcule
  /// le total de l'enfant.
  Future<void> editHistoryEntry({
    required String entryId,
    required int newPoints,
    required String newReason,
    bool? isBonus,
  }) async {
    final idx = _history.indexWhere((h) => h.id == entryId);
    if (idx == -1) return;
    final entry = _history[idx];
    // 🔒 Empêcher la modification d'une seule moitié d'un transfert
    if (entry.isPointsTransfer) return;
    final child = getChild(entry.childId);

    if (child != null) {
      // 1) Annule l'ancien effet
      if (entry.isBonus) {
        child.points -= entry.points;
      } else {
        child.points += entry.points;
      }
      // 2) Applique le nouvel effet
      final bonus = isBonus ?? entry.isBonus;
      if (bonus) {
        child.points += newPoints;
      } else {
        child.points -= newPoints;
      }
      if (child.points < 0) child.points = 0;
      _markPending(child.id);
      await _childrenBox.put(child.id, jsonEncode(child.toMap()));
      if (_firestore.isConnected) await _firestore.saveChild(child);
    }

    // 3) Met à jour l'entrée
    entry
      ..points = newPoints.abs()
      ..reason = newReason
      ..isBonus = isBonus ?? entry.isBonus;
    _markPending(entry.id);
    await _historyBox.put(entry.id, jsonEncode(entry.toMap()));
    if (_firestore.isConnected) await _firestore.saveHistoryEntry(entry);

    if (child != null) await _checkBadgeUnlock(child);
    notifyListeners();
  }

  Future<void> addChild(String name, String avatar) async {
    final child = ChildModel(id: _uuid.v4(), name: name, avatar: avatar);
    _markPending(child.id);
    _children.add(child);
    await _childrenBox.put(child.id, jsonEncode(child.toMap()));
    if (_firestore.isConnected) await _firestore.saveChild(child);
    notifyListeners();
  }

  Future<void> updateChild(String id, String name, String avatar) async {
    final child = getChild(id);
    if (child == null) return;
    child.name   = name;
    child.avatar = avatar;
    await _childrenBox.put(child.id, jsonEncode(child.toMap()));
    if (_firestore.isConnected) await _firestore.saveChild(child);
    notifyListeners();
  }

  Future<void> updateChildPhoto(String childId, String base64Photo) async {
    final child = getChild(childId);
    if (child == null) return;

    // 📸 COMPRESSION : réduire la taille avant stockage (3-5Mo → ~200Ko)
    final compressed = await ImageCompressor.compressBase64(base64Photo) ?? base64Photo;
    child.photoBase64 = compressed;
    await _childrenBox.put(child.id, jsonEncode(child.toMap()));
    if (_firestore.isConnected) await _firestore.saveChild(child);
    notifyListeners();
  }

  Future<void> updateChildBanner(String childId, String base64Banner) async {
    final child = getChild(childId);
    if (child == null) return;

    final compressed = await ImageCompressor.compressBase64(base64Banner) ?? base64Banner;
    child.bannerBase64 = compressed;
    await _childrenBox.put(child.id, jsonEncode(child.toMap()));
    if (_firestore.isConnected) await _firestore.saveChild(child);
    notifyListeners();
  }

  Future<void> updateChildSlogan(String childId, String slogan) async {
    final child = getChild(childId);
    if (child == null) return;
    child.sloganText = slogan;
    await _childrenBox.put(child.id, jsonEncode(child.toMap()));
    if (_firestore.isConnected) await _firestore.saveChild(child);
    notifyListeners();
  }

  Future<void> recalculateStreak(String childId) async {
    final child = getChild(childId);
    if (child == null) return;
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final hist  = _history
        .where((h) => h.childId == childId)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final hasPenaltyToday = hist.any((h) {
      final d = DateTime(h.date.year, h.date.month, h.date.day);
      return d == today && h.isPenalty && h.category != 'screen_time_bonus';
    });

    int streak;
    if (hasPenaltyToday) {
      streak = 0;
    } else {
      final lastPenalty = hist
          .where((h) => h.isPenalty && h.category != 'screen_time_bonus')
          .firstOrNull;
      if (lastPenalty == null) {
        final created = child.createdAt;
        streak = today
            .difference(DateTime(created.year, created.month, created.day))
            .inDays;
      } else {
        final lastDay = DateTime(lastPenalty.date.year,
            lastPenalty.date.month, lastPenalty.date.day);
        streak = today.difference(lastDay).inDays;
      }
    }
    child.streakDays = streak;
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
    for (final key in keysToRemove) await _screenTimeBox.delete(key);
    await _saveAllLocal();
    if (_firestore.isConnected) await _firestore.deleteChild(id);
    notifyListeners();
  }

  // ─── BONUS/PÉNALITÉ CUMULATIF (auto-calcul) ────────────────
  // Le montant augmente automatiquement selon le nombre d'actions du jour.

  /// Calcule le montant d'un bonus selon le nombre de bonus déjà donnés aujourd'hui.
  /// 1er = 10, 2e = 15, 3e = 20, 4e+ = 25.
  int _calculateBonusAmount(String childId) {
    final count = _getTodayActionsCount(childId, isBonus: true);
    if (count == 0) return 10;
    if (count == 1) return 15;
    if (count == 2) return 20;
    return 25; // plafond
  }

  /// Calcule le montant d'une pénalité selon le nombre de pénalités déjà données aujourd'hui.
  /// 1ère = 5, 2e = 10, 3e = 15, 4e+ = 20.
  int _calculatePenaltyAmount(String childId) {
    final count = _getTodayActionsCount(childId, isBonus: false);
    if (count == 0) return 5;
    if (count == 1) return 10;
    if (count == 2) return 15;
    return 20; // plafond
  }

  /// Compte le nombre de bonus ou pénalités donnés aujourd'hui.
  int _getTodayActionsCount(String childId, {required bool isBonus}) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    return _history.where((h) {
      if (h.childId != childId) return false;
      if (isBonus ? !h.isBonus : !h.isPenalty) return false;
      // Exclure les transferts (ne comptent ni comme bonus ni comme pénalité)
      if (h.isPointsTransfer) return false;
      // Exclure les catégories spéciales (temps écran, notes école, boutique)
      if (h.category == 'school_note' ||
          h.category == 'screen_time_bonus' ||
          h.category == 'saturday_rating' ||
          h.category == 'boutique' ||
          h.category == 'punition' ||
          h.category == 'immunité' ||
          h.category == 'tribunal_vote' ||
          h.category == 'tribunal_verdict') return false;
      return h.date.isAfter(todayStart);
    }).length;
  }

  /// Ajoute un bonus cumulatif (auto-calcul du montant).
  /// Retourne le montant accordé pour l'afficher à l'utilisateur.
  Future<int> addQuickBonus(String childId, String reason, {String? proofPhotoBase64}) async {
    final amount = _calculateBonusAmount(childId);
    await addPoints(childId, amount, reason,
        category: 'Bonus', isBonus: true,
        proofPhotoBase64: proofPhotoBase64);
    return amount;
  }

  /// Ajoute une pénalité cumulative (auto-calcul, jamais en dessous de 0).
  /// Retourne le montant retiré pour l'afficher.
  Future<int> addQuickPenalty(String childId, String reason, {String? proofPhotoBase64}) async {
    final child = getChild(childId);
    if (child == null) return 0;
    final amount = _calculatePenaltyAmount(childId);
    // Ne jamais descendre en dessous de 0
    final actualAmount = amount > child.points ? child.points : amount;
    if (actualAmount <= 0) return 0;
    await addPoints(childId, actualAmount, reason,
        category: 'Pénalité', isBonus: false,
        proofPhotoBase64: proofPhotoBase64);
    return actualAmount;
  }

  // ─── Points & Historique ───────────────────────────────────
  Future<void> addPoints(
    String childId,
    int points,
    String reason, {
    String    category         = 'Bonus',
    bool      isBonus          = true,
    String?   proofPhoto,
    String?   proofPhotoBase64,
    DateTime? date,
  }) async {
    final child = getChild(childId);
    if (child == null) return;
    if (isBonus) { child.points += points; }
    else         { child.points -= points; if (child.points < 0) child.points = 0; }
    // ✅ Marque l'enfant comme pending pour protéger ses points
    _markPending(child.id);
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
    _markPending(entry.id);
    _history.insert(0, entry);
    await _historyBox.put(entry.id, jsonEncode(entry.toMap()));
    if (_firestore.isConnected) await _firestore.saveHistoryEntry(entry);

    await _checkBadgeUnlock(child);
    await recalculateStreak(childId);
    // 🔊 Feedback sonore
    if (isBonus) { SoundService.playBonus(); }
    else { SoundService.playPenalty(); }
    notifyListeners();
  }

  /// Transfert express SKS : déplace des points d'un enfant vers un autre.
  /// Aucun point créé ou perdu. Crée deux HistoryEntry liées par transferId.
  /// N'appelle PAS addPoints (pour éviter bonus/pénalité/streak/son).
  Future<bool> transferPointsBetweenChildren({
    required String fromChildId,
    required String toChildId,
    required int amount,
    required String reason,
  }) async {
    // Validations
    if (fromChildId == toChildId) return false;
    if (amount < 1 || amount > 999) return false;
    if (reason.trim().isEmpty) return false;
    // 🔒 Verrou anti-double-traitement
    if (_isTransferring) return false;

    final fromChild = getChild(fromChildId);
    final toChild = getChild(toChildId);
    if (fromChild == null || toChild == null) return false;
    if (fromChild.points < amount) return false;

    _isTransferring = true;
    try {
      // 1. Ajuster les soldes
      fromChild.points -= amount;
      toChild.points += amount;

      _markPending(fromChild.id);
      _markPending(toChild.id);

      // 2. Créer les deux entrées liées
      final transferId = 'transfer_${_uuid.v4()}';
      final now = DateTime.now();

      final outEntry = HistoryEntry(
        id: _uuid.v4(),
        childId: fromChildId,
        points: amount,
        reason: reason,
        category: 'points_transfer_out',
        isBonus: false,
        date: now,
        actionBy: _currentParentName,
        transferId: transferId,
        counterpartyChildId: toChildId,
      );
      final inEntry = HistoryEntry(
        id: _uuid.v4(),
        childId: toChildId,
        points: amount,
        reason: reason,
        category: 'points_transfer_in',
        isBonus: true,
        date: now,
        actionBy: _currentParentName,
        transferId: transferId,
        counterpartyChildId: fromChildId,
      );

      _markPending(outEntry.id);
      _markPending(inEntry.id);

      // 3. Sauvegarder localement
      await _childrenBox.put(fromChild.id, jsonEncode(fromChild.toMap()));
      await _childrenBox.put(toChild.id, jsonEncode(toChild.toMap()));
      _history.insert(0, outEntry);
      _history.insert(0, inEntry);
      await _historyBox.put(outEntry.id, jsonEncode(outEntry.toMap()));
      await _historyBox.put(inEntry.id, jsonEncode(inEntry.toMap()));

      // 4. Écriture groupée distante (atomique)
      if (_firestore.isConnected) {
        try {
          await _firestore.transferPointsBatch(
            fromChild: fromChild,
            toChild: toChild,
            outEntry: outEntry,
            inEntry: inEntry,
          );
        } catch (_) {
          // L'écriture locale a réussi, la sync retry automatiquement
        }
      }

      // Pas de son bonus/pénalité (transfert neutre)
      notifyListeners();
      return true;
    } finally {
      _isTransferring = false;
    }
  }

  Future<void> clearHistory() async {
    _history.clear();
    await _historyBox.clear();
    notifyListeners();
  }

  Future<void> clearAllHistory() async => clearHistory();

  Future<void> _checkBadgeUnlock(ChildModel child) async {
    final allBadges = [...BadgeModel.defaultBadges, ..._customBadges];
    bool changed = false;
    for (final badge in allBadges) {
      if (child.points >= badge.requiredPoints &&
          !child.badgeIds.contains(badge.id)) {
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
      id: _uuid.v4(), childId: childId,
      title: title, targetPoints: targetPoints,
    );
    _markPending(goal.id);
    _goals.add(goal);
    await _goalsBox.put(goal.id, jsonEncode(goal.toMap()));
    if (_firestore.isConnected) await _firestore.saveGoal(goal);
    notifyListeners();
  }

  Future<void> toggleGoal(String goalId) async {
    try {
      final goal     = _goals.firstWhere((g) => g.id == goalId);
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
    bool isEvaluation = false,
    int? aiScore,
    int? parentScore,
    int? overallScore,
    Map<String, int> categoryScores = const {},
  }) async {
    final note = NoteModel(
      id: _uuid.v4(),
      childId: childId,
      text: text,
      authorName: authorName,
      isEvaluation: isEvaluation,
      aiScore: aiScore,
      parentScore: parentScore,
      overallScore: overallScore,
      categoryScores: categoryScores,
    );    _markPending(note.id);
    _notes.add(note);
    await _notesBox.put(note.id, jsonEncode(note.toMap()));
    if (_firestore.isConnected) await _firestore.saveNote(note);
    notifyListeners();
  }

  Future<void> updateNote(String noteId, String newText) async {
    try {
      final note = _notes.firstWhere((n) => n.id == noteId);
      note.text  = newText;
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
      final note    = _notes.firstWhere((n) => n.id == noteId);
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
      id: _uuid.v4(), childId: childId,
      text: text, totalLines: totalLines,
    );
    _markPending(p.id);
    _punishments.add(p);
    await _punishmentsBox.put(p.id, jsonEncode(p.toMap()));
    if (_firestore.isConnected) await _firestore.savePunishment(p);

    final deduction = _calculerDeductionPunition(totalLines);
    final entry = HistoryEntry(
      id:       _uuid.v4(),
      childId:  childId,
      points:   (deduction * 100).round(),
      reason:   'Déduction automatique : $totalLines lignes ($deduction pt)',
      category: 'punition',
      isBonus:  false,
      actionBy: _currentParentName,
      date:     DateTime.now(),
    );
    _markPending(entry.id);
    _history.insert(0, entry);
    await _historyBox.put(entry.id, jsonEncode(entry.toMap()));
    if (_firestore.isConnected) await _firestore.saveHistoryEntry(entry);

    await recalculateStreak(childId);
    // 🔊 Voix personnalisée (fichier audio réel)
    VoiceService().say('penalite');
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
      final p          = _punishments.firstWhere((p) => p.id == id);
      p.completedLines = (p.completedLines + linesToAdd).clamp(0, p.totalLines);
      await _punishmentsBox.put(p.id, jsonEncode(p.toMap()));
      if (_firestore.isConnected) await _firestore.savePunishment(p);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> addPhotoToPunishment(String id, String base64Photo) async {
    try {
      final p = _punishments.firstWhere((p) => p.id == id);
      
      // 📸 COMPRESSION + UPLOAD vers Storage (si connecté)
      if (_firestore.isConnected && _firestore.familyId != null) {
        try {
          final compressed = await ImageCompressor.compressBase64(base64Photo) ?? base64Photo;
          final photoIndex = p.photoUrls.length;
          final url = await StorageService().uploadPhotoBase64(
            familyId: _firestore.familyId!,
            path: 'punishments/${p.id}/photo_$photoIndex.jpg',
            base64Data: compressed,
          );
          if (url != null) {
            p.photoUrls.add(url);
          } else {
            p.photoUrls.add(base64Photo); // Fallback base64
          }
        } catch (e) {
          if (kDebugMode) debugPrint('addPhotoToPunishment Storage error: $e');
          p.photoUrls.add(base64Photo);
        }
      } else {
        p.photoUrls.add(base64Photo); // Offline: base64 local
      }
      
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
  Future<void> addImmunity(String childId, String reason, int lines,
      {DateTime? expiresAt}) async {
    final im = ImmunityLines(
      id: _uuid.v4(), childId: childId,
      reason: reason, lines: lines, expiresAt: expiresAt,
    );
    _markPending(im.id);
    _immunities.add(im);
    await _immunitiesBox.put(im.id, jsonEncode(im.toMap()));
    if (_firestore.isConnected) await _firestore.saveImmunity(im);

    final entry = HistoryEntry(
      id:       _uuid.v4(),
      childId:  childId,
      points:   lines,
      reason:   ' Immunité accordée : $reason ($lines ligne${lines > 1 ? 's' : ''})',
      category: 'immunité',
      isBonus:  true,
      actionBy: _currentParentName,
      date:     DateTime.now(),
    );
    _markPending(entry.id);
    _history.insert(0, entry);
    await _historyBox.put(entry.id, jsonEncode(entry.toMap()));
    if (_firestore.isConnected) await _firestore.saveHistoryEntry(entry);

    // 🔊 Voix personnalisée (fichier audio réel ou fallback TTS)
    VoiceService().say('immunite');
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
      _immunities
          .where((im) => im.childId == childId && im.isUsable)
          .toList();

  List<ImmunityLines> getImmunitiesForChild(String childId) =>
      _immunities.where((im) => im.childId == childId).toList();

  Future<void> useImmunityOnPunishment(
      String immunityId, String punishmentId, int lines) async {
    try {
      final im          = _immunities.firstWhere((i) => i.id == immunityId);
      final p           = _punishments.firstWhere((p) => p.id == punishmentId);
      final actualLines = lines
          .clamp(0, im.availableLines)
          .clamp(0, p.totalLines - p.completedLines);
      im.usedLines     += actualLines;
      p.completedLines  =
          (p.completedLines + actualLines).clamp(0, p.totalLines);
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
    final child = getChild(childId);
    if (child == null) return [];
    final allBadges = [...BadgeModel.defaultBadges, ..._customBadges];
    return allBadges.where((b) => child.badgeIds.contains(b.id)).toList();
  }

  Future<void> addCustomBadge(String name, String icon,
      String description, int requiredPoints,
      {String powerType = 'custom'}) async {
    final badge = BadgeModel(
      id:             'custom_${_uuid.v4()}',
      name:           name,
      icon:           icon,
      description:    description,
      requiredPoints: requiredPoints,
      powerType:      powerType,
      isCustom:       true,
    );
    _markPending(badge.id);
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

  // ─── Profils parents ─────────────────────────────────────────────────
  Future<void> saveParentProfile(ParentProfile profile) async {
    // Ajouter/mettre à jour en local immédiatement (optimistic update)
    final idx = _parentProfiles.indexWhere((p) => p.id == profile.id);
    if (idx >= 0) {
      _parentProfiles[idx] = profile;
    } else {
      _parentProfiles.add(profile);
    }
    // 🔧 FIX : persister en local (Hive) pour survivre au redémarrage
    await _parentProfilesBox.put(profile.id, jsonEncode(profile.toMap()));
    notifyListeners();

    // Puis synchroniser sur Firestore
    if (_firestore.isConnected) {
      try {
        await _firestore.saveParentProfile(profile);
      } catch (e) {
        if (kDebugMode) debugPrint('saveParentProfile Firestore error: $e');
      }
    }
  }

  Future<void> deleteParentProfile(String id) async {
    _parentProfiles.removeWhere((p) => p.id == id);
    // 🔧 FIX : supprimer aussi du local
    await _parentProfilesBox.delete(id);
    notifyListeners();

    if (_firestore.isConnected) {
      try {
        await _firestore.deleteParentProfile(id);
      } catch (e) {
        if (kDebugMode) debugPrint('deleteParentProfile Firestore error: $e');
      }
    }
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
        h.category != 'saturday_rating' &&
        h.category != 'tribunal_vote' &&
        h.category != 'tribunal_verdict').toList();
    if (weekEntries.isEmpty) return 10.0;
    final bonusCount   = weekEntries.where((h) => h.isBonus).length;
    final penaltyCount = weekEntries.where((h) => h.isPenalty).length;
    final total        = bonusCount + penaltyCount;
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
    final now          = DateTime.now();
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
    final penaltyCount = entries.where((h) => h.isPenalty).length;
    final total        = bonusCount + penaltyCount;
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
    return (_minutesFromGlobalScore(sr) +
            getParentBonusMinutes(childId)).clamp(0, 480);
  }

  int getParentBonusMinutes(String childId) =>
      _screenTimeBox.get(_screenTimeKey(childId, 'bonus'),
          defaultValue: 0) as int;

  double getSaturdayBehaviorRating(String childId) =>
      (_screenTimeBox.get(_screenTimeKey(childId, 'sat_rating'),
              defaultValue: -1.0) as num)
          .toDouble();

  Future<void> addScreenTimeBonus(
      String childId, int minutes, String reason) async {
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
    _markPending(entry.id);
    _history.insert(0, entry);
    await _historyBox.put(entry.id, jsonEncode(entry.toMap()));
    if (_firestore.isConnected) await _firestore.saveHistoryEntry(entry);
    notifyListeners();
  }

  Future<void> resetScreenTimeBonus(String childId) async {
    final key = _screenTimeKey(childId, 'bonus');
    await _screenTimeBox.put(key, 0);
    if (_firestore.isConnected) {
      await _firestore.saveScreenTimeValue(key, 0);
    }
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
    _markPending(entry.id);
    _history.insert(0, entry);
    await _historyBox.put(entry.id, jsonEncode(entry.toMap()));
    if (_firestore.isConnected) await _firestore.saveHistoryEntry(entry);
    notifyListeners();
  }

  List<HistoryEntry> _getWeekHistory(String childId) {
    final now       = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final start     = DateTime(weekStart.year, weekStart.month, weekStart.day);
    return _history
        .where((h) => h.childId == childId && h.date.isAfter(start))
        .toList();
  }

  List<HistoryEntry> _getWeekSchoolNotes(String childId) =>
      _getWeekHistory(childId)
          .where((h) => h.category == 'school_note')
          .toList();

  // ─── Tribunal ──────────────────────────────────────────────
  Future<void> addTribunalCase(TribunalCase tc) async {
    _markPending(tc.id);
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
    String?       prosecutionLawyerId,
    String?       defenseLawyerId,
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
        participants.add(TribunalParticipant(
            childId: wId, role: TribunalRole.witness));
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
    _markPending(tc.id);
    _tribunalCases.add(tc);
    await _tribunalBox.put(tc.id, jsonEncode(tc.toMap()));
    if (_firestore.isConnected) await _firestore.saveTribunalCase(tc);
    notifyListeners();
  }

  Future<void> scheduleTribunalHearing(String caseId, DateTime date) async {
    try {
      final tc         = _tribunalCases.firstWhere((c) => c.id == caseId);
      tc.status        = TribunalStatus.scheduled;
      tc.scheduledDate = date;
      await _tribunalBox.put(tc.id, jsonEncode(tc.toMap()));
      if (_firestore.isConnected) await _firestore.saveTribunalCase(tc);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> startTribunalHearing(String caseId) async {
    try {
      final tc  = _tribunalCases.firstWhere((c) => c.id == caseId);
      tc.status = TribunalStatus.inProgress;
      await _tribunalBox.put(tc.id, jsonEncode(tc.toMap()));
      if (_firestore.isConnected) await _firestore.saveTribunalCase(tc);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> startTribunalDeliberation(String caseId) async {
    try {
      final tc  = _tribunalCases.firstWhere((c) => c.id == caseId);
      tc.status = TribunalStatus.deliberation;
      await _tribunalBox.put(tc.id, jsonEncode(tc.toMap()));
      if (_firestore.isConnected) await _firestore.saveTribunalCase(tc);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> dismissTribunalCase(String caseId) async {
    try {
      final tc         = _tribunalCases.firstWhere((c) => c.id == caseId);
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
      final tc         = _tribunalCases.firstWhere((c) => c.id == caseId);
      tc.votingEnabled = true;
      await _tribunalBox.put(tc.id, jsonEncode(tc.toMap()));
      if (_firestore.isConnected) await _firestore.saveTribunalCase(tc);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> disableTribunalVoting(String caseId) async {
    try {
      final tc         = _tribunalCases.firstWhere((c) => c.id == caseId);
      tc.votingEnabled = false;
      await _tribunalBox.put(tc.id, jsonEncode(tc.toMap()));
      if (_firestore.isConnected) await _firestore.saveTribunalCase(tc);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> castTribunalVote(
      String caseId, String childId, TribunalVerdict vote) async {
    try {
      final tc = _tribunalCases.firstWhere((c) => c.id == caseId);
      if (!tc.canVote(childId)) return;
      tc.votes.add(TribunalVote(childId: childId, vote: vote));
      await _tribunalBox.put(tc.id, jsonEncode(tc.toMap()));
      if (_firestore.isConnected) await _firestore.saveTribunalCase(tc);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> changeTribunalVote(
      String caseId, String childId, TribunalVerdict newVote) async {
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

  Future<void> renderTribunalVerdict(
    String caseId,
    TribunalVerdict verdict,
    String reason, {
    int? penaltyPoints,
    int? rewardPoints,
  }) async {
    try {
      final tc         = _tribunalCases.firstWhere((c) => c.id == caseId);
      tc.status        = TribunalStatus.closed;
      tc.verdict       = verdict;
      tc.verdictReason = reason;
      tc.verdictDate   = DateTime.now();
      await _tribunalBox.put(tc.id, jsonEncode(tc.toMap()));
      if (_firestore.isConnected) await _firestore.saveTribunalCase(tc);
      if (verdict == TribunalVerdict.guilty && penaltyPoints != null) {
        await addPoints(tc.accusedId, penaltyPoints,
            '⚖️ Verdict tribunal : $reason',
            category: 'tribunal_verdict', isBonus: false);
      } else if (verdict == TribunalVerdict.innocent && rewardPoints != null) {
        await addPoints(tc.plaintiffId, rewardPoints,
            '⚖️ Verdict tribunal : $reason',
            category: 'tribunal_verdict', isBonus: true);
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> renderVerdict({
    required String          caseId,
    required TribunalVerdict verdict,
    required String          reason,
    int?                     accusedPoints,
  }) async {
    try {
      final tc         = _tribunalCases.firstWhere((c) => c.id == caseId);
      tc.status        = TribunalStatus.closed;
      tc.verdict       = verdict;
      tc.verdictReason = reason;
      tc.verdictDate   = DateTime.now();
      await _tribunalBox.put(tc.id, jsonEncode(tc.toMap()));
      if (_firestore.isConnected) await _firestore.saveTribunalCase(tc);

      if (accusedPoints != null && accusedPoints != 0) {
        final isBonus = accusedPoints > 0;
        await addPoints(
          tc.accusedId,
          accusedPoints.abs(),
          '⚖️ Verdict tribunal : $reason',
          category: 'tribunal_verdict',
          isBonus:  isBonus,
        );
      }
      notifyListeners();
    } catch (_) {}
  }

  // ─── Échanges (Trades) ────────────────────────────────────
  List<TradeModel> getTradesForChild(String childId) =>
      _trades
          .where((t) => t.fromChildId == childId || t.toChildId == childId)
          .toList();

  List<TradeModel> getPendingTradesForChild(String childId) =>
      _trades
          .where((t) => t.isPending && t.toChildId == childId)
          .toList();

  Future<void> createTrade(
    String fromChildId,
    String toChildId,
    int immunityLines,
    String serviceDescription,
  ) async {
    final available = getTotalAvailableImmunity(fromChildId);
    if (available < immunityLines) return;

    final trade = TradeModel(
      id:                 _uuid.v4(),
      fromChildId:        fromChildId,
      toChildId:          toChildId,
      immunityLines:      immunityLines,
      serviceDescription: serviceDescription,
      status:             'pending',
      createdAt:          DateTime.now(),
    );
    _markPending(trade.id);
    _trades.add(trade);
    await _tradesBox.put(trade.id, jsonEncode(trade.toMap()));
    if (_firestore.isConnected) await _firestore.saveTrade(trade);
    notifyListeners();
  }

  Future<void> proposeTrade(TradeModel trade) async {
    _markPending(trade.id);
    _trades.add(trade);
    await _tradesBox.put(trade.id, jsonEncode(trade.toMap()));
    if (_firestore.isConnected) await _firestore.saveTrade(trade);
    notifyListeners();
  }

  Future<void> acceptTrade(String tradeId) async {
    try {
      final trade      = _trades.firstWhere((t) => t.id == tradeId);
      trade.status     = 'accepted';
      trade.acceptedAt = DateTime.now();
      await _tradesBox.put(trade.id, jsonEncode(trade.toMap()));
      if (_firestore.isConnected) await _firestore.saveTrade(trade);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> rejectTrade(String tradeId) async {
    try {
      final trade  = _trades.firstWhere((t) => t.id == tradeId);
      trade.status = 'rejected';
      await _tradesBox.put(trade.id, jsonEncode(trade.toMap()));
      if (_firestore.isConnected) await _firestore.saveTrade(trade);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> cancelTrade(String tradeId) async {
    try {
      final trade  = _trades.firstWhere((t) => t.id == tradeId);
      trade.status = 'cancelled';
      await _tradesBox.put(trade.id, jsonEncode(trade.toMap()));
      if (_firestore.isConnected) await _firestore.saveTrade(trade);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> markServiceDone(String tradeId) async {
    try {
      final trade  = _trades.firstWhere((t) => t.id == tradeId);
      trade.status = 'service_done';
      await _tradesBox.put(trade.id, jsonEncode(trade.toMap()));
      if (_firestore.isConnected) await _firestore.saveTrade(trade);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> completeTrade(String tradeId) async {
    try {
      final trade = _trades.firstWhere((t) => t.id == tradeId);

      final sellerImmunities = _immunities
          .where((im) => im.childId == trade.fromChildId && im.isUsable)
          .toList();
      int linesToTransfer = trade.immunityLines;
      for (final im in sellerImmunities) {
        if (linesToTransfer <= 0) break;
        final take = linesToTransfer.clamp(0, im.availableLines);
        im.usedLines += take;
        linesToTransfer -= take;
        await _immunitiesBox.put(im.id, jsonEncode(im.toMap()));
        if (_firestore.isConnected) await _firestore.saveImmunity(im);
      }

      final newImmunity = ImmunityLines(
        id:      _uuid.v4(),
        childId: trade.toChildId,
        reason:  '🔄 Acheté à ${getChild(trade.fromChildId)?.name ?? "?"} : ${trade.serviceDescription}',
        lines:   trade.immunityLines,
      );
      _markPending(newImmunity.id);
      _immunities.add(newImmunity);
      await _immunitiesBox.put(newImmunity.id, jsonEncode(newImmunity.toMap()));
      if (_firestore.isConnected) await _firestore.saveImmunity(newImmunity);

      trade.status      = 'completed';
      trade.completedAt = DateTime.now();
      await _tradesBox.put(trade.id, jsonEncode(trade.toMap()));
      if (_firestore.isConnected) await _firestore.saveTrade(trade);

      final entrySeller = HistoryEntry(
        id:       _uuid.v4(),
        childId:  trade.fromChildId,
        points:   trade.immunityLines,
        reason:   '🔄 Vente immunité à ${getChild(trade.toChildId)?.name ?? "?"} : ${trade.serviceDescription}',
        category: 'échange',
        isBonus:  false,
        actionBy: _currentParentName,
        date:     DateTime.now(),
      );
      final entryBuyer = HistoryEntry(
        id:       _uuid.v4(),
        childId:  trade.toChildId,
        points:   trade.immunityLines,
        reason:   '🔄 Achat immunité de ${getChild(trade.fromChildId)?.name ?? "?"} : ${trade.serviceDescription}',
        category: 'échange',
        isBonus:  true,
        actionBy: _currentParentName,
        date:     DateTime.now(),
      );
      _markPending(entrySeller.id);
      _markPending(entryBuyer.id);
      _history.insert(0, entrySeller);
      _history.insert(0, entryBuyer);
      await _historyBox.put(entrySeller.id, jsonEncode(entrySeller.toMap()));
      await _historyBox.put(entryBuyer.id,  jsonEncode(entryBuyer.toMap()));
      if (_firestore.isConnected) {
        await _firestore.saveHistoryEntry(entrySeller);
        await _firestore.saveHistoryEntry(entryBuyer);
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> removeTrade(String tradeId) async {
    _trades.removeWhere((t) => t.id == tradeId);
    await _tradesBox.delete(tradeId);
    if (_firestore.isConnected) await _firestore.deleteTrade(tradeId);
    notifyListeners();
  }

  /// Réinitialise uniquement les points (et badges) d'un enfant.
  Future<void> resetChildPoints(String childId) async {
    final child = getChild(childId);
    if (child == null) return;
    child.points = 0;
    child.badgeIds = [];
    _markPending(childId);
    await _childrenBox.put(childId, jsonEncode(child.toMap()));
    if (_firestore.isConnected) await _firestore.saveChild(child);
    notifyListeners();
  }

  Future<void> resetAllScores() async {
    for (final child in _children) {
      child.points   = 0;
      child.badgeIds = [];
      _markPending(child.id); // protéger le reset contre l'écrasement distant
      await _childrenBox.put(child.id, jsonEncode(child.toMap()));
      if (_firestore.isConnected) await _firestore.saveChild(child);
    }
    notifyListeners();
  }

  /// Réinitialise TOUT pour un enfant : points, badges, punitions, immunités,
  /// objectifs, notes, historique. (Action parent, avec confirmation UI.)
  Future<void> resetChildCompletely(String childId) async {
    final child = getChild(childId);
    if (child == null) return;

    // Points + badges
    child.points = 0;
    child.badgeIds = [];
    _markPending(child.id);
    await _childrenBox.put(child.id, jsonEncode(child.toMap()));
    if (_firestore.isConnected) await _firestore.saveChild(child);

    // Historique de l'enfant
    final childHistory = _history.where((h) => h.childId == childId).toList();
    for (final h in childHistory) {
      _deletedEntryIds.add(h.id);
      await _historyBox.delete(h.id);
      if (_firestore.isConnected) await _firestore.deleteHistoryEntry(h.id);
    }
    _history.removeWhere((h) => h.childId == childId);

    // Objectifs
    final childGoals = _goals.where((g) => g.childId == childId).toList();
    for (final g in childGoals) {
      await _goalsBox.delete(g.id);
      if (_firestore.isConnected) await _firestore.deleteGoal(g.id);
    }
    _goals.removeWhere((g) => g.childId == childId);

    // Notes
    final childNotes = _notes.where((n) => n.childId == childId).toList();
    for (final n in childNotes) {
      await _notesBox.delete(n.id);
      if (_firestore.isConnected) await _firestore.deleteNote(n.id);
    }
    _notes.removeWhere((n) => n.childId == childId);

    // Punitions
    final childPunishments = _punishments.where((p) => p.childId == childId).toList();
    for (final p in childPunishments) {
      await _punishmentsBox.delete(p.id);
      if (_firestore.isConnected) await _firestore.deletePunishment(p.id);
    }
    _punishments.removeWhere((p) => p.childId == childId);

    // Immunités
    final childImmunities = _immunities.where((im) => im.childId == childId).toList();
    for (final im in childImmunities) {
      await _immunitiesBox.delete(im.id);
      if (_firestore.isConnected) await _firestore.deleteImmunity(im.id);
    }
    _immunities.removeWhere((im) => im.childId == childId);

    notifyListeners();
  }

  int getBonusCountToday(String childId) {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    return _history.where((h) {
      if (h.childId != childId) return false;
      if (!h.isBonus) return false;
      if (h.category == 'screen_time_bonus') return false;
      final d = DateTime(h.date.year, h.date.month, h.date.day);
      return d == todayDate;
    }).length;
  }

  int getPenaltyCountToday(String childId) {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    return _history.where((h) {
      if (h.childId != childId) return false;
      if (h.isBonus) return false;
      if (h.category == 'screen_time_bonus') return false;
      final d = DateTime(h.date.year, h.date.month, h.date.day);
      return d == todayDate;
    }).length;
  }

  int getActivePunishmentsCount(String childId) {
    return _punishments.where((p) =>
        p.childId == childId && p.completedLines < p.totalLines).length;
  }

  int getUsableImmunitiesCount(String childId) {
    return _immunities.where((im) =>
        im.childId == childId && im.isUsable && im.availableLines > 0).length;
  }

  List<String> getRecentReasons(String childId, {int limit = 5}) {
    return _history
        .where((h) => h.childId == childId)
        .take(limit)
        .map((h) => h.reason)
        .toList();
  }

  // ─── Demandes en attente (validation parentale) ────────────
  int get pendingRequestsCount => _pendingRequests.length;

  Future<RequestResult> createRequest({
    required String type,
    required String childId,
    required String requestedBy,
    required String text,
    int amount = 0,
    Map<String, dynamic>? extra,
  }) async {
    final requestKey = (extra?['requestKey'] as String?)?.trim() ?? '';

    // 🔒 Anti-doublon : vérifier les demandes pending existantes
    if (requestKey.isNotEmpty) {
      final existing = _pendingRequests.any((r) =>
          r.status == 'pending' &&
          (r.extra['requestKey'] as String?)?.trim() == requestKey);
      if (existing) return RequestResult.duplicate;
      // 🔒 Verrou d'exécution : empêche deux appels concurrents
      if (_requestKeysInFlight.contains(requestKey)) {
        return RequestResult.duplicate;
      }
      _requestKeysInFlight.add(requestKey);
    }

    final r = PendingRequest(
      id: _uuid.v4(),
      type: type,
      childId: childId,
      requestedBy: requestedBy,
      text: text,
      amount: amount,
      status: 'pending',
      extra: extra ?? {},
    );

    try {
      _markPending(r.id);
      _pendingRequests.add(r);
      await _requestsBox.put(r.id, jsonEncode(r.toMap()));
      // Sauvegarde distante — si connecté et échec → failed
      if (_firestore.isConnected) {
        await _firestore.saveRequest(r); // relance l'exception si échec
      }
      notifyListeners();
      return RequestResult.created;
    } catch (_) {
      // Échec local OU distant : nettoyer l'état partiel
      _pendingRequests.removeWhere((p) => p.id == r.id);
      _pendingIds.remove(r.id);
      try { await _requestsBox.delete(r.id); } catch (_) {}
      return RequestResult.failed;
    } finally {
      if (requestKey.isNotEmpty) _requestKeysInFlight.remove(requestKey);
    }
  }

  Future<void> approveRequest(String requestId, {int? customAmount, String? comment}) async {
    PendingRequest? r;
    try { r = _pendingRequests.firstWhere((x) => x.id == requestId); }
    catch (_) { return; }

    final amount = customAmount ?? r.amount;
    final reason = comment != null && comment.isNotEmpty ? '${r.text} ($comment)' : r.text;

    switch (r.type) {
      case 'punishment':
        await addPunishment(r.childId, r.text, amount);
        break;
      case 'immunity':
        await addImmunity(r.childId, r.text, amount);
        break;
      case 'bonus':
        await addPoints(r.childId, amount, reason,
            category: 'Bonus', isBonus: true);
        break;
      case 'chore_checklist':
        await addPoints(r.childId, amount, reason,
            category: 'ménage', isBonus: true);
        break;
      case 'penalty':
        await addPoints(r.childId, amount, reason,
            category: 'Pénalité', isBonus: false);
        break;
      case 'tribunal':
        await fileTribunalCase(
          title: r.text,
          description: r.extra['description']?.toString() ?? r.text,
          plaintiffId: r.extra['plaintiffId']?.toString() ?? r.childId,
          accusedId: r.extra['accusedId']?.toString() ?? r.childId,
        );
        break;
      case 'boutique':
        // ✅ Les points ont déjà été déduits à l'achat.
        // La validation du parent confirme simplement l'achat.
        // On ajoute juste un commentaire si fourni.
        break;
    }

    _pendingRequests.removeWhere((x) => x.id == requestId);
    _markRequestDeleted(requestId);
    await _requestsBox.delete(requestId);
    if (_firestore.isConnected) await _firestore.deleteRequest(requestId);
    notifyListeners();
  }

  /// Refuse une demande avec un message optionnel pour l'enfant.
  Future<void> rejectRequest(String requestId, {String? reason}) async {
    final r = _pendingRequests.where((x) => x.id == requestId).firstOrNull;

    // 🛒 Si c'est un achat boutique → rembourser les points
    if (r != null && r.type == 'boutique') {
      final child = getChild(r.childId);
      if (child != null) {
        child.points += r.amount; // remboursement
        _markPending(child.id);
        await _childrenBox.put(child.id, jsonEncode(child.toMap()));
        if (_firestore.isConnected) await _firestore.saveChild(child);

        // Entrée d'historique du remboursement
        final refund = HistoryEntry(
          id: _uuid.v4(),
          childId: r.childId,
          points: r.amount,
          reason: '↩️ Achat annulé : ${r.extra['rewardTitle'] ?? 'récompense'}',
          category: 'boutique',
          isBonus: true,
          actionBy: _currentParentName,
        );
        _markPending(refund.id);
        _history.insert(0, refund);
        await _historyBox.put(refund.id, jsonEncode(refund.toMap()));
        if (_firestore.isConnected) await _firestore.saveHistoryEntry(refund);
      }
    }

    if (r != null && reason != null && reason.isNotEmpty) {
      // Créer une entrée d'historique pour informer l'enfant du refus
      final entry = HistoryEntry(
        id: _uuid.v4(),
        childId: r.childId,
        points: 0,
        reason: '❌ Demande refusée : $reason',
        category: 'refus',
        isBonus: false,
        actionBy: _currentParentName,
      );
      _markPending(entry.id);
      _history.insert(0, entry);
      await _historyBox.put(entry.id, jsonEncode(entry.toMap()));
      if (_firestore.isConnected) await _firestore.saveHistoryEntry(entry);
    }
    _pendingRequests.removeWhere((x) => x.id == requestId);
    _markRequestDeleted(requestId);
    await _requestsBox.delete(requestId);
    if (_firestore.isConnected) await _firestore.deleteRequest(requestId);
    notifyListeners();
  }

  // ─── BOUTIQUE DE RÉCOMPENSES ───────────────────────────────────

  Future<void> addReward({
    required String title,
    required int cost,
    String icon = '🎁',
    String description = '',
    String category = 'custom',
    int? maxPerWeek,
    String? photoBase64,
  }) async {
    final r = RewardModel(
      id: 'reward_${_uuid.v4()}',
      title: title,
      cost: cost,
      icon: icon,
      description: description,
      category: category,
      maxPerWeek: maxPerWeek,
      photoBase64: photoBase64,
    );
    _rewards.add(r);
    await _rewardsBox.put(r.id, jsonEncode(r.toMap()));
    if (_firestore.isConnected) {
      await _firestore.saveReward(r.toMap(), r.id);
    }
    notifyListeners();
  }

  /// 🔒 Met à jour une récompense existante SANS changer l'ID
  /// (préserve les achats en attente qui référencent cet ID)
  Future<void> updateReward(RewardModel reward) async {
    final idx = _rewards.indexWhere((r) => r.id == reward.id);
    if (idx == -1) return;
    _rewards[idx] = reward;
    await _rewardsBox.put(reward.id, jsonEncode(reward.toMap()));
    if (_firestore.isConnected) {
      await _firestore.saveReward(reward.toMap(), reward.id);
    }
    notifyListeners();
  }

  Future<void> deleteReward(String id) async {
    _rewards.removeWhere((r) => r.id == id);
    await _rewardsBox.delete(id);
    if (_firestore.isConnected) {
      await _firestore.deleteReward(id);
    }
    notifyListeners();
  }

  /// L'enfant achète une récompense. Déduit les points et crée une demande.
  /// Retourne true si l'achat a réussi.
  Future<bool> purchaseReward(String childId, String rewardId) async {
    final child = getChild(childId);
    // 🔒 Sécurité : ne pas crasher si la récompense n'existe plus
    final rewardIdx = _rewards.indexWhere((r) => r.id == rewardId);
    if (child == null || rewardIdx == -1) return false;
    final reward = _rewards[rewardIdx];

    // Vérifier que l'enfant a assez de points (prix soldé si vente en cours)
    final actualCost = salePrice(reward.cost);
    if (child.points < actualCost) return false;

    // Déduire les points
    child.points -= actualCost;
    _markPending(child.id);
    await _childrenBox.put(child.id, jsonEncode(child.toMap()));
    if (_firestore.isConnected) await _firestore.saveChild(child);

    // 📺 Si la récompense est du temps d'écran, ajouter les minutes au compte
    if (reward.title.toLowerCase().contains('écran') ||
        reward.title.toLowerCase().contains('ecran') ||
        reward.title.toLowerCase().contains('min') ||
        reward.icon == '🎮') {
      // Extraire le nombre de minutes du titre
      final match = RegExp(r'(\d+)').firstMatch(reward.title);
      final minutes = match != null ? int.tryParse(match.group(1)!) ?? 15 : 15;
      await addScreenTimeMinutes(childId, minutes, '🛒 Achat boutique : ${reward.title}');
    }

    // Enregistrer l'achat avec un ID stable
    final purchaseId = 'purch_${_uuid.v4()}';
    final purchaseData = {
      'id': purchaseId,
      'rewardId': reward.id,
      'childId': childId,
      'childName': child.name,
      'title': reward.title,
      'icon': reward.icon,
      'cost': actualCost,
      'originalCost': reward.cost,
      'status': 'pending', // pending → approved / rejected
      'date': DateTime.now().toIso8601String(),
    };
    _purchases.insert(0, purchaseData);
    await _purchasesBox.put(purchaseId, jsonEncode(purchaseData));
    if (_firestore.isConnected) {
      await _firestore.savePurchase(purchaseData);
    }

    // 🔔 Notification au parent via le système de demande (badge cloche)
    // 🔒 On transmet le PRIX PAYÉ (soldé) et non le prix original
    final onSale = actualCost < reward.cost;
    await createRequest(
      type: 'boutique',
      childId: childId,
      requestedBy: child.name,
      text: onSale
          ? '🛒 ${child.name} achète "${reward.title}" ($actualCost pts 🔥 -${_saleDiscountPercent}%)'
          : '🛒 ${child.name} achète "${reward.title}" ($actualCost pts)',
      amount: actualCost,
      extra: {
        'rewardId': reward.id,
        'rewardTitle': reward.title,
        'icon': reward.icon,
        'originalCost': reward.cost,
        'salePrice': actualCost,
        'onSale': onSale,
      },
    );

    // Ajouter à l'historique (prix réellement payé)
    final entry = HistoryEntry(
      id: _uuid.v4(),
      childId: childId,
      points: actualCost,
      reason: onSale
          ? '🛒 Achat boutique : ${reward.title} (-${_saleDiscountPercent}%)'
          : '🛒 Achat boutique : ${reward.title}',
      category: 'boutique',
      isBonus: false,
      actionBy: child.name,
    );
    _markPending(entry.id);
    _history.insert(0, entry);
    await _historyBox.put(entry.id, jsonEncode(entry.toMap()));
    if (_firestore.isConnected) await _firestore.saveHistoryEntry(entry);

    // 🔊 Feedback sonore d'achat
    SoundService.playPurchase();
    notifyListeners();
    return true;
  }

  /// Achète des lignes d'immunité depuis la boutique (ne convertit pas, crée).
  Future<bool> purchaseImmunityLines(String childId, int linesToBuy, int cost) async {
    final child = getChild(childId);
    if (child == null) return false;
    if (child.points < cost) return false;

    // Déduire les points
    child.points -= cost;
    _markPending(child.id);
    await _childrenBox.put(child.id, jsonEncode(child.toMap()));
    if (_firestore.isConnected) await _firestore.saveChild(child);

    // Créer l'immunité achetée
    final im = ImmunityLines(
      id: _uuid.v4(),
      childId: childId,
      reason: '🛒 Achat boutique ($linesToBuy lignes)',
      lines: linesToBuy,
    );
    _markPending(im.id);
    _immunities.add(im);
    await _immunitiesBox.put(im.id, jsonEncode(im.toMap()));
    if (_firestore.isConnected) await _firestore.saveImmunity(im);

    // Historique
    final entry = HistoryEntry(
      id: _uuid.v4(),
      childId: childId,
      points: cost,
      reason: '🛒 Achat boutique : $linesToBuy lignes d\'immunité',
      category: 'boutique',
      isBonus: false,
      actionBy: child.name,
    );
    _markPending(entry.id);
    _history.insert(0, entry);
    await _historyBox.put(entry.id, jsonEncode(entry.toMap()));
    if (_firestore.isConnected) await _firestore.saveHistoryEntry(entry);

    notifyListeners();
    return true;
  }

  // ─── CHECKLIST DES TÂCHES ────────────────────────────────────

  Future<void> addChore({required String label, required int points, String emoji = '✅', bool isIndividual = true, List<String>? timeSlots}) async {
    final c = ChoreModel(
      id: 'chore_${_uuid.v4()}',
      label: label,
      points: points,
      emoji: emoji,
      order: _chores.length,
      isIndividual: isIndividual,
      timeSlots: timeSlots ?? const ['matin', 'midi', 'soir'],
    );
    _chores.add(c);
    await _choresBox.put(c.id, jsonEncode(c.toMap()));
    // 🔧 FIX : synchroniser sur Firestore pour que les enfants voient la tâche
    if (_firestore.isConnected && _firestore.familyId != null) {
      try {
        await _firestore.saveChore(c.toMap(), c.id);
      } catch (e) {
        if (kDebugMode) debugPrint('addChore Firestore error: $e');
      }
    }
    notifyListeners();
  }

  Future<void> deleteChore(String id) async {
    _chores.removeWhere((c) => c.id == id);
    await _choresBox.delete(id);
    if (_firestore.isConnected && _firestore.familyId != null) {
      try {
        await _firestore.deleteChore(id);
      } catch (e) {
        if (kDebugMode) debugPrint('deleteChore Firestore error: $e');
      }
    }
    notifyListeners();
  }

  /// Valide les tâches cochées pour un enfant et ajoute les points d'un coup.
  Future<int> validateChores(String childId, List<ChoreModel> completed) async {
    if (completed.isEmpty) return 0;
    int totalPoints = completed.fold(0, (sum, c) => sum + c.points);
    final labels = completed.map((c) => '${c.emoji} ${c.label}').join(', ');
    await addPoints(childId, totalPoints, '✅ Tâches du jour : $labels',
        category: 'ménage', isBonus: true);
    return totalPoints;
  }

  // ─── TEMPS D'ÉCRAN (compte de minutes + chrono) ─────────────

  /// Ajoute des minutes au compte d'un enfant (achat boutique ou bonus parent)
  Future<void> addScreenTimeMinutes(String childId, int minutes, String reason) async {
    final account = getScreenTimeAccount(childId);
    account.balanceMinutes += minutes;
    account.totalEarned += minutes;
    account.history.insert(0, ScreenTimeTransaction(
      minutes: minutes, type: 'earned', reason: reason, date: DateTime.now(),
    ));
    _screenTimeAccounts[childId] = account;
    if (_firestore.isConnected) {
      try { await _firestore.saveScreenTimeAccount(childId, account.toMap()); } catch (_) {}
    }
    notifyListeners();
  }

  /// Démarre une session de temps d'écran
  Future<void> startScreenTimeSession(String childId, int minutes) async {
    final account = getScreenTimeAccount(childId);
    if (account.isRunning) return;
    if (account.balanceMinutes < minutes) minutes = account.balanceMinutes;
    if (minutes <= 0) return;

    account.sessionStart = DateTime.now();
    account.sessionMinutes = minutes;
    account.balanceMinutes -= minutes;
    account.appliedOvertimeTranches = 0;
    _screenTimeAccounts[childId] = account;
    _startOvertimeChecker();
    if (_firestore.isConnected) {
      try { await _firestore.saveScreenTimeAccount(childId, account.toMap()); } catch (_) {}
    }
    notifyListeners();
  }

  /// Arrête la session en cours (bouton STOP du parent)
  /// Les pénalités d'overtime sont déjà appliquées en temps réel par le timer,
  /// on ne les re-applique PAS ici (sinon double pénalité).
  Future<void> stopScreenTimeSession(String childId) async {
    final account = getScreenTimeAccount(childId);
    if (!account.isRunning) return;

    final remaining = account.sessionRemaining;
    final used = account.sessionMinutes - remaining;
    account.totalUsed += used;
    if (remaining > 0) {
      account.balanceMinutes += remaining;
    }

    // ⚠️ Les pénalités d'overtime ont déjà été appliquées en temps réel
    // par le timer (_startOvertimeChecker). On ne double-pénalise PAS ici.

    account.history.insert(0, ScreenTimeTransaction(
      minutes: used, type: 'used',
      reason: account.isOvertime
          ? 'Session terminée (${account.overtimeMinutes} min de retard)'
          : 'Session terminée',
      date: DateTime.now(),
    ));
    account.sessionStart = null;
    account.sessionMinutes = 0;
    account.appliedOvertimeTranches = 0;
    _screenTimeAccounts[childId] = account;
    _stopOvertimeChecker();
    if (_firestore.isConnected) {
      try { await _firestore.saveScreenTimeAccount(childId, account.toMap()); } catch (_) {}
    }
    notifyListeners();
  }

  /// Timer qui vérifie l'overtime toutes les minutes.
  /// 🔒 Chaque enfant a son propre compteur de tranches appliquées
  /// (account.appliedOvertimeTranches) pour éviter les conflits multi-enfants.
  void _startOvertimeChecker() {
    _stopOvertimeChecker();
    _overtimeTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      bool anyOvertime = false;
      for (final entry in _screenTimeAccounts.entries) {
        final account = entry.value;
        if (account.isOvertime) {
          anyOvertime = true;
          final currentTranches = account.overtimeMinutes ~/ 5;
          // Appliquer -10 pts pour chaque NOUVELLE tranche de 5 min
          while (account.appliedOvertimeTranches < currentTranches) {
            account.appliedOvertimeTranches++;
            addPoints(entry.key, 10,
              '⚠️ Overtime : +5 min de retard sur le temps d\'écran',
              category: 'overtime', isBonus: false);
          }
        }
      }
      if (anyOvertime) notifyListeners();
    });
  }

  void _stopOvertimeChecker() {
    _overtimeTimer?.cancel();
    _overtimeTimer = null;
  }

  /// Prolongation (parent)
  Future<void> extendScreenTime(String childId, int minutes) async {
    final account = getScreenTimeAccount(childId);
    if (account.isRunning) {
      account.sessionMinutes += minutes;
      account.totalEarned += minutes;
    } else {
      account.balanceMinutes += minutes;
      account.totalEarned += minutes;
    }
    account.history.insert(0, ScreenTimeTransaction(
      minutes: minutes, type: 'earned', reason: 'Prolongation parent', date: DateTime.now(),
    ));
    _screenTimeAccounts[childId] = account;
    if (_firestore.isConnected) {
      try { await _firestore.saveScreenTimeAccount(childId, account.toMap()); } catch (_) {}
    }
    notifyListeners();
  }

  /// Charge les comptes de temps d'écran depuis Firestore
  Future<void> loadScreenTimeAccounts() async {
    if (!_firestore.isConnected) return;
    try {
      final list = await _firestore.loadScreenTimeAccounts();
      for (final data in list) {
        final account = ScreenTimeAccount.fromMap(data);
        _screenTimeAccounts[account.childId] = account;
      }
    } catch (_) {}
  }
}

