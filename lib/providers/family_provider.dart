// lib/providers/family_provider.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/child_model.dart';
import '../models/goal_model.dart';
import '../models/note_model.dart';
import '../models/punishment_model.dart';
import '../models/immunity_model.dart';
import '../models/badge_model.dart';
import '../models/trade_model.dart';
import '../models/tribunal_model.dart';
import '../models/bonus_penalty_model.dart';
import '../models/school_grade_model.dart';
import '../services/firestore_service.dart';

class FamilyProvider extends ChangeNotifier {
  late Box<Map> _childrenBox;
  late Box<Map> _goalsBox;
  late Box<Map> _notesBox;
  late Box<Map> _punishmentsBox;
  late Box<Map> _immunitiesBox;
  late Box<Map> _badgesBox;
  late Box<Map> _tradesBox;
  late Box<Map> _tribunalBox;
  late Box<Map> _bonusPenaltyBox;
  late Box<Map> _schoolGradesBox;

  List<ChildModel> _children = [];
  List<GoalModel> _goals = [];
  List<NoteModel> _notes = [];
  List<PunishmentLines> _punishments = [];
  List<ImmunityModel> _immunities = [];
  List<BadgeModel> _badges = [];
  List<TradeModel> _trades = [];
  List<TribunalCase> _tribunalCases = [];
  List<BonusPenaltyModel> _bonusPenalties = [];
  List<SchoolGradeModel> _schoolGrades = [];

  String _currentParent = 'Parent';
  bool _isInitialized = false;

  final FirestoreService _firestoreService = FirestoreService();
  StreamSubscription? _firestoreSubscription;

  List<ChildModel> get children => List.unmodifiable(_children);
  List<ChildModel> get childrenSorted =>
      List<ChildModel>.from(_children)
        ..sort((a, b) => b.points.compareTo(a.points));
  List<GoalModel> get goals => List.unmodifiable(_goals);
  List<NoteModel> get notes => List.unmodifiable(_notes);
  List<PunishmentLines> get punishments => List.unmodifiable(_punishments);
  List<ImmunityModel> get immunities => List.unmodifiable(_immunities);
  List<BadgeModel> get badges => List.unmodifiable(_badges);
  List<TradeModel> get trades => List.unmodifiable(_trades);
  List<TribunalCase> get tribunalCases => List.unmodifiable(_tribunalCases);
  List<BonusPenaltyModel> get bonusPenalties => List.unmodifiable(_bonusPenalties);
  List<SchoolGradeModel> get schoolGrades => List.unmodifiable(_schoolGrades);
  String get currentParent => _currentParent;
  bool get isInitialized => _isInitialized;

  Future<void> init() async {
    _childrenBox     = await Hive.openBox<Map>('enfants');
    _goalsBox        = await Hive.openBox<Map>('objectifs');
    _notesBox        = await Hive.openBox<Map>('notes');
    _punishmentsBox  = await Hive.openBox<Map>('punitions');
    _immunitiesBox   = await Hive.openBox<Map>('immunites');
    _badgesBox       = await Hive.openBox<Map>('badges');
    _tradesBox       = await Hive.openBox<Map>('echanges');
    _tribunalBox     = await Hive.openBox<Map>('tribunal');
    _bonusPenaltyBox = await Hive.openBox<Map>('bonus_penalites');
    _schoolGradesBox = await Hive.openBox<Map>('notes_scolaires');

    _chargerDepuisLocal();
    _isInitialized = true;
    notifyListeners();

    _firestoreSubscription = _firestoreService.ecouterFamille().listen(
      _traiterMiseAJourFirestore,
      onError: (e) => debugPrint('Erreur Firestore : $e'),
    );
  }

  void _chargerDepuisLocal() {
    _children = _childrenBox.values
        .map((m) => ChildModel.fromMap(Map<String, dynamic>.from(m)))
        .toList();
    _goals = _goalsBox.values
        .map((m) => GoalModel.fromMap(Map<String, dynamic>.from(m)))
        .toList();
    _notes = _notesBox.values
        .map((m) => NoteModel.fromMap(Map<String, dynamic>.from(m)))
        .toList();
    _punishments = _punishmentsBox.values
        .map((m) => PunishmentLines.fromMap(Map<String, dynamic>.from(m)))
        .toList();
    _immunities = _immunitiesBox.values
        .map((m) => ImmunityModel.fromMap(Map<String, dynamic>.from(m)))
        .toList();
    _badges = _badgesBox.values
        .map((m) => BadgeModel.fromMap(Map<String, dynamic>.from(m)))
        .toList();
    _trades = _tradesBox.values
        .map((m) => TradeModel.fromMap(Map<String, dynamic>.from(m)))
        .toList();
    _tribunalCases = _tribunalBox.values
        .map((m) => TribunalCase.fromMap(Map<String, dynamic>.from(m)))
        .toList();
    _bonusPenalties = _bonusPenaltyBox.values
        .map((m) => BonusPenaltyModel.fromMap(Map<String, dynamic>.from(m)))
        .toList();
    _schoolGrades = _schoolGradesBox.values
        .map((m) => SchoolGradeModel.fromMap(Map<String, dynamic>.from(m)))
        .toList();
  }

  void _traiterMiseAJourFirestore(Map<String, dynamic> donnees) {
    if (donnees.containsKey('enfants')) {
      _children = (donnees['enfants'] as List)
          .map((m) => ChildModel.fromMap(Map<String, dynamic>.from(m)))
          .toList();
      for (final enfant in _children) {
        _childrenBox.put(enfant.id, enfant.toMap());
      }
    }
    if (donnees.containsKey('objectifs')) {
      _goals = (donnees['objectifs'] as List)
          .map((m) => GoalModel.fromMap(Map<String, dynamic>.from(m)))
          .toList();
      for (final obj in _goals) {
        _goalsBox.put(obj.id, obj.toMap());
      }
    }
    if (donnees.containsKey('notes_scolaires')) {
      _schoolGrades = (donnees['notes_scolaires'] as List)
          .map((m) => SchoolGradeModel.fromMap(Map<String, dynamic>.from(m)))
          .toList();
      for (final note in _schoolGrades) {
        _schoolGradesBox.put(note.id, note.toMap());
      }
    }
    if (donnees.containsKey('punitions')) {
      _punishments = (donnees['punitions'] as List)
          .map((m) => PunishmentLines.fromMap(Map<String, dynamic>.from(m)))
          .toList();
      for (final p in _punishments) {
        _punishmentsBox.put(p.id, p.toMap());
      }
    }
    if (donnees.containsKey('bonus_penalites')) {
      _bonusPenalties = (donnees['bonus_penalites'] as List)
          .map((m) => BonusPenaltyModel.fromMap(Map<String, dynamic>.from(m)))
          .toList();
      for (final bp in _bonusPenalties) {
        _bonusPenaltyBox.put(bp.id, bp.toMap());
      }
    }
    notifyListeners();
  }

  void setCurrentParent(String nom) {
    _currentParent = nom;
    notifyListeners();
  }

  ChildModel? getEnfant(String id) {
    try {
      return _children.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> ajouterEnfant(ChildModel enfant) async {
    _children.add(enfant);
    await _childrenBox.put(enfant.id, enfant.toMap());
    await _firestoreService.sauvegarderEnfant(enfant);
    notifyListeners();
  }

  Future<void> mettreAJourEnfant(ChildModel enfant) async {
    final index = _children.indexWhere((e) => e.id == enfant.id);
    if (index != -1) {
      _children[index] = enfant;
      await _childrenBox.put(enfant.id, enfant.toMap());
      await _firestoreService.sauvegarderEnfant(enfant);
      notifyListeners();
    }
  }

  Future<void> supprimerEnfant(String id) async {
    _children.removeWhere((e) => e.id == id);
    await _childrenBox.delete(id);
    await _firestoreService.supprimerEnfant(id);
    notifyListeners();
  }

  Future<void> ajouterPoints(
    String enfantId,
    int quantite, {
    required String categorie,
    required bool estBonus,
    String description = '',
    DateTime? date,
  }) async {
    final enfant = getEnfant(enfantId);
    if (enfant == null) return;

    final entree = BonusPenaltyModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      childId: enfantId,
      points: quantite,
      isBonus: estBonus,
      category: categorie,
      description: description,
      date: date ?? DateTime.now(),
    );

    _bonusPenalties.add(entree);
    await _bonusPenaltyBox.put(entree.id, entree.toMap());
    await _firestoreService.sauvegarderBonusPenalite(entree);

    final nouveauTotal = estBonus
        ? enfant.points + quantite
        : (enfant.points - quantite).clamp(0, 999999);
    final enfantMaj = enfant.copyWith(points: nouveauTotal);
    await mettreAJourEnfant(enfantMaj);
  }

  // ── NOUVEAU BARÈME PUNITIONS ──────────────────────────────────────────────
  // 1–10   lignes → −0,80 pt
  // 11–20  lignes → −1,20 pt
  // 21–50  lignes → −1,80 pt
  // 51–100 lignes → −2,50 pts
  // 101–200 lignes → −3,50 pts
  // 200+   lignes → −5,00 pts
  double _calculerDeductionPunition(int totalLignes) {
    if (totalLignes <= 10)  return 0.80;
    if (totalLignes <= 20)  return 1.20;
    if (totalLignes <= 50)  return 1.80;
    if (totalLignes <= 100) return 2.50;
    if (totalLignes <= 200) return 3.50;
    return 5.00;
  }

  Future<void> ajouterPunition(PunishmentLines punition) async {
    _punishments.add(punition);
    await _punishmentsBox.put(punition.id, punition.toMap());
    await _firestoreService.sauvegarderPunition(punition);

    final deduction = _calculerDeductionPunition(punition.totalLines);
    final entree = BonusPenaltyModel(
      id: '${punition.id}_deduction',
      childId: punition.childId,
      points: (deduction * 100).round(),
      isBonus: false,
      category: 'punition',
      description:
          'Déduction automatique : ${punition.totalLines} lignes (−$deduction pt comportement)',
      date: punition.createdAt,
    );
    _bonusPenalties.add(entree);
    await _bonusPenaltyBox.put(entree.id, entree.toMap());
    await _firestoreService.sauvegarderBonusPenalite(entree);

    notifyListeners();
  }

  Future<void> supprimerPunition(String id) async {
    _punishments.removeWhere((p) => p.id == id);
    await _punishmentsBox.delete(id);
    await _firestoreService.supprimerPunition(id);
    notifyListeners();
  }

  Future<void> mettreAJourPunition(PunishmentLines punition) async {
    final index = _punishments.indexWhere((p) => p.id == punition.id);
    if (index != -1) {
      _punishments[index] = punition;
      await _punishmentsBox.put(punition.id, punition.toMap());
      await _firestoreService.sauvegarderPunition(punition);
      notifyListeners();
    }
  }

  Future<void> ajouterObjectif(GoalModel objectif) async {
    _goals.add(objectif);
    await _goalsBox.put(objectif.id, objectif.toMap());
    await _firestoreService.sauvegarderObjectif(objectif);
    notifyListeners();
  }

  Future<void> mettreAJourObjectif(GoalModel objectif) async {
    final index = _goals.indexWhere((o) => o.id == objectif.id);
    if (index != -1) {
      _goals[index] = objectif;
      await _goalsBox.put(objectif.id, objectif.toMap());
      await _firestoreService.sauvegarderObjectif(objectif);
      notifyListeners();
    }
  }

  Future<void> supprimerObjectif(String id) async {
    _goals.removeWhere((o) => o.id == id);
    await _goalsBox.delete(id);
    await _firestoreService.supprimerObjectif(id);
    notifyListeners();
  }

  Future<void> ajouterNote(NoteModel note) async {
    _notes.add(note);
    await _notesBox.put(note.id, note.toMap());
    await _firestoreService.sauvegarderNote(note);
    notifyListeners();
  }

  Future<void> supprimerNote(String id) async {
    _notes.removeWhere((n) => n.id == id);
    await _notesBox.delete(id);
    await _firestoreService.supprimerNote(id);
    notifyListeners();
  }

  Future<void> ajouterImmunite(ImmunityModel immunite) async {
    _immunities.add(immunite);
    await _immunitiesBox.put(immunite.id, immunite.toMap());
    await _firestoreService.sauvegarderImmunite(immunite);
    notifyListeners();
  }

  Future<void> supprimerImmunite(String id) async {
    _immunities.removeWhere((i) => i.id == id);
    await _immunitiesBox.delete(id);
    await _firestoreService.supprimerImmunite(id);
    notifyListeners();
  }

  List<ImmunityModel> getImmunitesEnfant(String enfantId) =>
      _immunities.where((i) => i.childId == enfantId).toList();

  Future<void> debloquerBadge(String enfantId, String badgeId) async {
    final enfant = getEnfant(enfantId);
    if (enfant == null) return;
    if (enfant.badgeIds.contains(badgeId)) return;

    final enfantMaj = enfant.copyWith(
      badgeIds: [...enfant.badgeIds, badgeId],
    );
    await mettreAJourEnfant(enfantMaj);

    final badge = BadgeModel(
      id: '${enfantId}_$badgeId',
      childId: enfantId,
      badgeId: badgeId,
      unlockedAt: DateTime.now(),
    );
    _badges.add(badge);
    await _badgesBox.put(badge.id, badge.toMap());
    await _firestoreService.sauvegarderBadge(badge);
    notifyListeners();
  }

  Future<void> ajouterEchange(TradeModel echange) async {
    _trades.add(echange);
    await _tradesBox.put(echange.id, echange.toMap());
    await _firestoreService.sauvegarderEchange(echange);
    notifyListeners();
  }

  Future<void> mettreAJourEchange(TradeModel echange) async {
    final index = _trades.indexWhere((e) => e.id == echange.id);
    if (index != -1) {
      _trades[index] = echange;
      await _tradesBox.put(echange.id, echange.toMap());
      await _firestoreService.sauvegarderEchange(echange);
      notifyListeners();
    }
  }

  Future<void> supprimerEchange(String id) async {
    _trades.removeWhere((e) => e.id == id);
    await _tradesBox.delete(id);
    await _firestoreService.supprimerEchange(id);
    notifyListeners();
  }

  List<TradeModel> getEchangesEnfant(String enfantId) =>
      _trades.where((e) =>
          e.fromChildId == enfantId || e.toChildId == enfantId).toList();

  Future<void> ajouterCasTribunal(TribunalCase cas) async {
    _tribunalCases.add(cas);
    await _tribunalBox.put(cas.id, cas.toMap());
    await _firestoreService.sauvegarderCasTribunal(cas);
    notifyListeners();
  }

  Future<void> mettreAJourCasTribunal(TribunalCase cas) async {
    final index = _tribunalCases.indexWhere((c) => c.id == cas.id);
    if (index != -1) {
      _tribunalCases[index] = cas;
      await _tribunalBox.put(cas.id, cas.toMap());
      await _firestoreService.sauvegarderCasTribunal(cas);
      notifyListeners();
    }
  }

  Future<void> supprimerCasTribunal(String id) async {
    _tribunalCases.removeWhere((c) => c.id == id);
    await _tribunalBox.delete(id);
    await _firestoreService.supprimerCasTribunal(id);
    notifyListeners();
  }

  Future<void> ajouterNoteScolaire(SchoolGradeModel note) async {
    _schoolGrades.add(note);
    await _schoolGradesBox.put(note.id, note.toMap());
    await _firestoreService.sauvegarderNoteScolaire(note);
    notifyListeners();
  }

  Future<void> supprimerNoteScolaire(String id) async {
    _schoolGrades.removeWhere((n) => n.id == id);
    await _schoolGradesBox.delete(id);
    await _firestoreService.supprimerNoteScolaire(id);
    notifyListeners();
  }

  List<SchoolGradeModel> getNotesScolairesEnfant(String enfantId) =>
      _schoolGrades.where((n) => n.childId == enfantId).toList();

  double getMoyenneScolaireSemaine(String enfantId) {
    final maintenantLundi = _debutSemaine(DateTime.now());
    final notes = _schoolGrades
        .where((n) =>
            n.childId == enfantId &&
            !n.date.isBefore(maintenantLundi))
        .toList();
    if (notes.isEmpty) return 0;
    final somme = notes.fold<double>(
        0, (s, n) => s + (n.grade / n.maxGrade) * 20);
    return somme / notes.length;
  }

  double getMoyenneScolaireJours(
      String enfantId, List<DateTime> jours) {
    if (jours.isEmpty) return getMoyenneScolaireSemaine(enfantId);
    final joursNorm = jours.map(_normaliserDate).toSet();
    final notes = _schoolGrades
        .where((n) =>
            n.childId == enfantId &&
            joursNorm.contains(_normaliserDate(n.date)))
        .toList();
    if (notes.isEmpty) return 0;
    final somme = notes.fold<double>(
        0, (s, n) => s + (n.grade / n.maxGrade) * 20);
    return somme / notes.length;
  }

  List<BonusPenaltyModel> getBonusPenalitesEnfant(String enfantId) =>
      _bonusPenalties.where((b) => b.childId == enfantId).toList();

  Future<void> supprimerBonusPenalite(String id) async {
    _bonusPenalties.removeWhere((b) => b.id == id);
    await _bonusPenaltyBox.delete(id);
    await _firestoreService.supprimerBonusPenalite(id);
    notifyListeners();
  }

  double getScoreComportementJours(
      String enfantId, List<DateTime> joursSources) {
    final joursNorm = joursSources.map(_normaliserDate).toSet();

    final entrees = _bonusPenalties.where((b) =>
        b.childId == enfantId &&
        (joursSources.isEmpty ||
            joursNorm.contains(_normaliserDate(b.date))));

    double score = 10.0;

    for (final entree in entrees) {
      final valeur = entree.category == 'punition'
          ? entree.points / 100.0
          : entree.points.toDouble();
      if (entree.isBonus) {
        score += valeur;
      } else {
        score -= valeur;
      }
    }

    return score.clamp(0.0, 20.0);
  }

  double getScoreGlobalJours(
      String enfantId, List<DateTime> joursSources) {
    final scolaire = getMoyenneScolaireJours(enfantId, joursSources);
    final comportement =
        getScoreComportementJours(enfantId, joursSources);
    return (scolaire * 0.5 + comportement * 0.5).clamp(0.0, 20.0);
  }

  Future<void> ajouterTempsEcran(
      String enfantId, int minutes, String raison) async {
    final enfant = getEnfant(enfantId);
    if (enfant == null) return;
    final enfantMaj = enfant.copyWith(
      screenTimeMinutes: enfant.screenTimeMinutes + minutes,
    );
    await mettreAJourEnfant(enfantMaj);

    final entree = BonusPenaltyModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      childId: enfantId,
      points: minutes,
      isBonus: true,
      category: 'temps_ecran',
      description: raison,
      date: DateTime.now(),
    );
    _bonusPenalties.add(entree);
    await _bonusPenaltyBox.put(entree.id, entree.toMap());
    await _firestoreService.sauvegarderBonusPenalite(entree);
    notifyListeners();
  }

  Future<void> reinitialiserTempsEcran(String enfantId) async {
    final enfant = getEnfant(enfantId);
    if (enfant == null) return;
    final enfantMaj = enfant.copyWith(screenTimeMinutes: 0);
    await mettreAJourEnfant(enfantMaj);
  }

  Future<void> definirNoteSamedi(
      String enfantId, double note, String commentaire) async {
    final enfant = getEnfant(enfantId);
    if (enfant == null) return;
    final enfantMaj = enfant.copyWith(
      saturdayRating: note,
      saturdayComment: commentaire,
      lastSaturdayRatingDate: DateTime.now(),
    );
    await mettreAJourEnfant(enfantMaj);
  }

  List<BonusPenaltyModel> getHistoriqueEnfant(String enfantId) =>
      _bonusPenalties
          .where((b) => b.childId == enfantId)
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  Future<void> reinitialiserHistorique(String enfantId) async {
    final aSupprimer = _bonusPenalties
        .where((b) => b.childId == enfantId)
        .map((b) => b.id)
        .toList();
    for (final id in aSupprimer) {
      await _bonusPenaltyBox.delete(id);
      await _firestoreService.supprimerBonusPenalite(id);
    }
    _bonusPenalties.removeWhere((b) => b.childId == enfantId);
    notifyListeners();
  }

  DateTime _debutSemaine(DateTime date) {
    return DateTime(date.year, date.month,
        date.day - (date.weekday - 1));
  }

  DateTime _normaliserDate(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  Future<void> reconnecterFirestore() async {
    await _firestoreSubscription?.cancel();
    _firestoreSubscription =
        _firestoreService.ecouterFamille().listen(
      _traiterMiseAJourFirestore,
      onError: (e) => debugPrint('Erreur Firestore (reconnexion) : $e'),
    );
  }

  @override
  void dispose() {
    _firestoreSubscription?.cancel();
    super.dispose();
  }
}
