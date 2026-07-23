import 'package:flutter_test/flutter_test.dart';
import 'package:family_score/widgets/point_action_panel.dart';

void main() {
  group('Motif Autre', () {
    test('un motif classique n’est pas marqué comme Autre', () {
      const motif = ActionMotif('test_id', '📚', 'Devoirs', 10);

      expect(motif.isOther, isFalse);
    });

    test('Autre bonne action est correctement configuré', () {
      const motif = ActionMotif(
        'bonus_autre',
        '✨',
        'Autre bonne action',
        5,
        isOther: true,
      );

      expect(motif.isOther, isTrue);
      expect(motif.label, 'Autre bonne action');
      expect(motif.defaultPoints, 5);
    });

    test('Autre comportement est correctement configuré', () {
      const motif = ActionMotif(
        'penalty_autre',
        '🔎',
        'Autre comportement',
        5,
        isOther: true,
      );

      expect(motif.isOther, isTrue);
      expect(motif.label, 'Autre comportement');
      expect(motif.defaultPoints, 5);
    });

    test('ActionMotif a un id stable', () {
      const motif = ActionMotif('bonus_menage', '🧹', 'Ménage', 5);
      expect(motif.id, 'bonus_menage');
    });
  });
}
