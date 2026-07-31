import 'package:flutter_test/flutter_test.dart';
import 'package:family_score/utils/home_tab_history.dart';

void main() {
  group('Historique central des onglets', () {
    test('revient dans l’ordre réel des pages visitées', () {
      final history = HomeTabHistory()
        ..visit(1)
        ..visit(3);

      expect(history.back(), 1);
      expect(history.back(), 0);
      expect(history.canExit, isTrue);
    });

    test('ne duplique pas la page courante', () {
      final history = HomeTabHistory()
        ..visit(1)
        ..visit(1);

      expect(history.back(), 0);
      expect(history.back(), isNull);
    });
  });
}
