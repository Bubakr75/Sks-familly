import 'package:family_score/utils/motif_helpers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('validation centralisée des motifs bonus et pénalité', () {
    for (final action in ['bonus', 'pénalité']) {
      test('$action avec motif prédéfini est valide et conserve son libellé',
          () {
        expect(
          isPointActionReasonValid(
            hasSelectedReason: true,
            isOther: false,
            customText: '',
          ),
          isTrue,
        );
        expect(
          resolvePointActionReason(
            isOther: false,
            selectedLabel: 'Chambre rangée',
            customText: 'ancien texte',
          ),
          'Chambre rangée',
        );
      });

      test('$action avec Autre vide reste invalide', () {
        expect(
          isPointActionReasonValid(
            hasSelectedReason: true,
            isOther: true,
            customText: '',
          ),
          isFalse,
        );
      });
    }

    test('aucun motif sélectionné est invalide', () {
      expect(
        isPointActionReasonValid(
          hasSelectedReason: false,
          isOther: false,
        ),
        isFalse,
      );
    });

    test('Autre composé uniquement d’espaces est invalide', () {
      expect(
        isPointActionReasonValid(
          hasSelectedReason: true,
          isOther: true,
          customText: '   ',
        ),
        isFalse,
      );
      expect(
        resolvePointActionReason(isOther: true, customText: '   '),
        isNull,
      );
    });

    test('Autre valide est nettoyé avant envoi', () {
      expect(
        isPointActionReasonValid(
          hasSelectedReason: true,
          isOther: true,
          customText: '  Aide spontanée  ',
        ),
        isTrue,
      );
      expect(
        resolvePointActionReason(
          isOther: true,
          customText: '  Aide spontanée  ',
        ),
        'Aide spontanée',
      );
    });

    test('la limite raisonnable de longueur est appliquée', () {
      final tooLong = 'a' * (maxCustomReasonLength + 1);
      expect(
        isPointActionReasonValid(
          hasSelectedReason: true,
          isOther: true,
          customText: tooLong,
        ),
        isFalse,
      );
      expect(
        resolvePointActionReason(isOther: true, customText: tooLong),
        isNull,
      );
    });
  });
}
