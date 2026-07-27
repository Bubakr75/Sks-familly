import 'package:flutter_test/flutter_test.dart';

import 'package:family_score/widgets/quick_shortcut_panel.dart';

void main() {
  group('Validation de la pénalité rapide', () {
    test('utilise la pénalité proposée avec son montant par défaut', () {
      final form = QuickPenaltyFormState(selectedChildId: 'child-1')
        ..selectedPreset = ('Insolence', 5);

      expect(form.reason, 'Insolence');
      expect(form.points, 5);
    });

    test('utilise le montant personnalisé', () {
      final form = QuickPenaltyFormState(selectedChildId: 'child-1')
        ..customPoints = 8;

      expect(form.reason, 'Pénalité rapide');
      expect(form.points, 8);
    });

    test('conserve le nouvel enfant sélectionné', () {
      final form = QuickPenaltyFormState(selectedChildId: 'child-1')
        ..selectedChildId = 'child-2';

      expect(form.selectedChildId, 'child-2');
    });

    test('prend en compte le changement du nombre de pénalités', () {
      final form = QuickPenaltyFormState(selectedChildId: 'child-1')
        ..customPoints = 12;

      expect(form.points, 12);
    });

    test('empêche une double validation', () {
      final form = QuickPenaltyFormState(selectedChildId: 'child-1');

      expect(form.tryStartSubmission(), isTrue);
      expect(form.tryStartSubmission(), isFalse);
      form.finishSubmission();
      expect(form.tryStartSubmission(), isTrue);
    });
  });
}
