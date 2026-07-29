import 'package:flutter_test/flutter_test.dart';
import 'package:family_score/screens/punishment_lines_screen.dart';

void main() {
  group('Accès aux lignes depuis le tableau de bord', () {
    test('ouvre les punitions par défaut', () {
      const screen = PunishmentLinesScreen();

      expect(screen.initialTabIndex, 0);
    });

    test('peut ouvrir directement les immunités dans le même écran', () {
      const screen = PunishmentLinesScreen(initialTabIndex: 1);

      expect(screen.initialTabIndex, 1);
    });
  });
}
