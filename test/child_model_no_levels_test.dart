import 'package:flutter_test/flutter_test.dart';
import '../lib/models/child_model.dart';

void main() {
  group('Niveau dormant', () {
    test('toMap conserve la valeur historique sans la recalculer', () {
      final child = ChildModel(
        id: 'child-1',
        name: 'Test',
        points: 999,
        level: 3,
      );

      final map = child.toMap();

      expect(map['points'], 999);
      expect(map['level'], 3);
    });

    test('fromMap conserve le niveau historique Firestore', () {
      final child = ChildModel.fromMap({
        'id': 'child-1',
        'name': 'Test',
        'points': 999,
        'level': 4,
        'createdAt': '2026-01-01T00:00:00.000',
      });

      expect(child.points, 999);
      expect(child.level, 4);
    });
  });
}
