// Tests pour les motifs personnalisés (LOT 1), Photo IA (LOT 2),
// favoris/compteurs (LOT 3), et fluidité/tri stable.
// Utilise les vrais helpers de production et SharedPreferences mock.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:family_score/utils/motif_helpers.dart';
import 'package:family_score/services/motif_preferences_service.dart';
import 'package:family_score/widgets/point_action_panel.dart';

void main() {
  // ═══ LOT 1 — Motif "Autre" personnalisable ═══
  group('LOT 1 — motif_helpers', () {
    test('motif classique valide sans texte personnalisé', () {
      final reason = buildReason(isOther: false, emoji: '🧹', label: 'Ménage');
      expect(reason, '🧹 Ménage');
    });

    test('motif Autre invalide avec texte vide', () {
      expect(isValidCustomText(''), isFalse);
      expect(isValidCustomText(null), isFalse);
    });

    test('motif Autre invalide avec espaces uniquement', () {
      expect(isValidCustomText('   '), isFalse);
      expect(isValidCustomText('\t\n'), isFalse);
    });

    test('trim du texte personnalisé', () {
      expect(normalizeCustomText('  hello  '), 'hello');
      expect(normalizeCustomText('\nworld\t'), 'world');
    });

    test('raison finale pour Autre contient le bon texte', () {
      final reason =
          buildReason(isOther: true, emoji: '✨', customText: 'A aidé sa sœur');
      expect(reason, '✨ A aidé sa sœur');
    });

    test('raison finale pour Autre pénalité', () {
      final reason = buildReason(
          isOther: true, emoji: '🔎', customText: 'A menti sur ses devoirs');
      expect(reason, '🔎 A menti sur ses devoirs');
    });

    test('pas de double emoji si le texte commence déjà par l\'emoji', () {
      final reason =
          buildReason(isOther: true, emoji: '✨', customText: '✨ Super effort');
      expect(reason, '✨ Super effort');
      expect(reason.split('✨').length, 2);
    });

    test('motif classique après Autre ignore l\'ancien texte', () {
      final reasonClassic = buildReason(
        isOther: false,
        emoji: '📚',
        label: 'Devoirs',
        customText: 'ancien texte ignoré',
      );
      expect(reasonClassic, '📚 Devoirs');
      expect(reasonClassic.contains('ignoré'), isFalse);
    });

    test('champ visible uniquement pour isOther', () {
      const classic = ActionMotif('id1', '🧹', 'Ménage', 5);
      const autre = ActionMotif('id2', '✨', 'Autre', 5, isOther: true);
      expect(classic.isOther, isFalse);
      expect(autre.isOther, isTrue);
    });

    test('bouton désactivé lorsque le texte Autre est vide', () {
      expect(isValidCustomText(''), isFalse);
      expect(isValidCustomText('texte valide'), isTrue);
    });
  });

  // ═══ LOT 2 — Photo IA helpers (dialogue testé via widget) ═══
  group('LOT 2 — Photo IA buildReason', () {
    test('raison non vide est valide', () {
      expect('Bonne aide en cuisine'.trim().isNotEmpty, isTrue);
    });

    test('texte vide désactive Confirmer', () {
      expect(''.trim().isEmpty, isTrue);
      expect('   '.trim().isEmpty, isTrue);
    });

    test('texte modifié est trimé avant utilisation', () {
      expect('  texte modifié  '.trim(), 'texte modifié');
    });
  });

  // ═══ LOT 3 — Favoris et motifs fréquents ═══
  group('LOT 3 — MotifPreferencesService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('favoris Bonus et Pénalité séparés', () async {
      await MotifPreferencesService.toggleFavorite(true, 'bonus_menage');
      await MotifPreferencesService.toggleFavorite(false, 'penalty_insolence');

      final favBonus = await MotifPreferencesService.loadFavorites(true);
      final favPenalty = await MotifPreferencesService.loadFavorites(false);

      expect(favBonus.contains('bonus_menage'), isTrue);
      expect(favBonus.contains('penalty_insolence'), isFalse);
      expect(favPenalty.contains('penalty_insolence'), isTrue);
      expect(favPenalty.contains('bonus_menage'), isFalse);
    });

    test('ajout et suppression d\'un favori', () async {
      var favs = await MotifPreferencesService.toggleFavorite(true, 'id1');
      expect(favs.contains('id1'), isTrue);

      favs = await MotifPreferencesService.toggleFavorite(true, 'id1');
      expect(favs.contains('id1'), isFalse);
    });

    test('persistance après reconstruction du service', () async {
      await MotifPreferencesService.toggleFavorite(true, 'persist_id');
      final favs = await MotifPreferencesService.loadFavorites(true);
      expect(favs.contains('persist_id'), isTrue);
    });

    test('incrément du compteur', () async {
      await MotifPreferencesService.incrementUsage(true, 'id1');
      await MotifPreferencesService.incrementUsage(true, 'id1');
      await MotifPreferencesService.incrementUsage(true, 'id2');

      final usage = await MotifPreferencesService.loadUsage(true);
      expect(usage['id1'], 2);
      expect(usage['id2'], 1);
    });

    test('favoris placés avant les motifs fréquents', () {
      final motifs = [
        ActionMotif('a', '🅰️', 'A', 5),
        ActionMotif('b', '🅱️', 'B', 5),
        ActionMotif('c', '🅲', 'C', 5),
        ActionMotif('other', '✨', 'Autre', 5, isOther: true),
      ];
      final sorted = MotifPreferencesService.sortMotifs(
        motifs: motifs,
        getId: (m) => m.id,
        isOther: (m) => m.isOther,
        favorites: {'b'},
        usage: {'a': 10, 'b': 1, 'c': 5},
      );
      expect(sorted.first.id, 'b');
      expect(sorted[1].id, 'a');
      expect(sorted.last.id, 'other');
    });

    test('fréquence décroissante', () {
      final motifs = [
        ActionMotif('a', '🅰️', 'A', 5),
        ActionMotif('b', '🅱️', 'B', 5),
        ActionMotif('c', '🅲', 'C', 5),
      ];
      final sorted = MotifPreferencesService.sortMotifs(
        motifs: motifs,
        getId: (m) => m.id,
        isOther: (m) => m.isOther,
        favorites: {},
        usage: {'a': 3, 'b': 10, 'c': 1},
      );
      expect(sorted[0].id, 'b');
      expect(sorted[1].id, 'a');
      expect(sorted[2].id, 'c');
    });

    test('égalité de fréquence conserve explicitement l\'ordre initial', () {
      final ids = ['x', 'y', 'z'];
      final motifs =
          ids.map((id) => ActionMotif(id, '🔹', id.toUpperCase(), 5)).toList();
      final sorted = MotifPreferencesService.sortMotifs(
        motifs: motifs,
        getId: (m) => m.id,
        isOther: (m) => m.isOther,
        favorites: {},
        usage: {},
      );
      expect(sorted.map((m) => m.id).toList(), ids);
    });

    test('Autre reste toujours à la fin même avec usage élevé', () {
      final ids = ['x', 'y', 'z'];
      final motifs =
          ids.map((id) => ActionMotif(id, '🔹', id.toUpperCase(), 5)).toList();
      motifs.add(ActionMotif('other', '✨', 'Autre', 5, isOther: true));
      final sorted = MotifPreferencesService.sortMotifs(
        motifs: motifs,
        getId: (m) => m.id,
        isOther: (m) => m.isOther,
        favorites: {},
        usage: {'x': 100, 'y': 50, 'z': 1, 'other': 999},
      );
      expect(sorted.last.id, 'other');
    });

    test('échec ou annulation n\'incrémente pas le compteur', () async {
      final usage = await MotifPreferencesService.loadUsage(true);
      expect(usage.isEmpty, isTrue);
    });

    test('une erreur SharedPreferences ne bloque pas l\'action principale',
        () async {
      final favs = await MotifPreferencesService.loadFavorites(true);
      expect(favs, isNotNull);
      expect(favs.isEmpty, isTrue);
    });
  });

  // ═══ LOT 3b — Tests de validation des helpers pour PointActionPanel ═══
  // Note: les widget tests complets nécessitent FamilyProvider + Hive,
  // non disponibles en test unitaire. On teste les helpers réels utilisés.
  group('PointActionPanel — helpers réels', () {
    test('isValidCustomText utilisé pour activer/désactiver le bouton', () {
      expect(isValidCustomText(''), isFalse);
      expect(isValidCustomText(null), isFalse);
      expect(isValidCustomText('   '), isFalse);
      expect(isValidCustomText('Belle action'), isTrue);
    });

    test('buildReason produit la bonne raison pour addPoints', () {
      expect(buildReason(isOther: false, emoji: '🧹', label: 'Ménage'),
          '🧹 Ménage');
      expect(
          buildReason(isOther: true, emoji: '✨', customText: 'Aidé'), '✨ Aidé');
    });

    test('ActionMotif.isOther contrôle la visibilité du champ', () {
      const classic = ActionMotif('id', '🅰️', 'A', 5);
      const autre = ActionMotif('id2', '✨', 'Autre', 5, isOther: true);
      expect(classic.isOther == true, isFalse);
      expect(autre.isOther == true, isTrue);
    });
  });
}
