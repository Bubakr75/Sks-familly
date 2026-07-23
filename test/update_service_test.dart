import 'package:flutter_test/flutter_test.dart';
import 'package:family_score/services/update_service.dart';

void main() {
  group('UpdateService.isNewerVersion', () {
    test('détecte un numéro de build supérieur', () {
      expect(
        UpdateService.isNewerVersion('4.8.0+500', '4.8.0+499'),
        isTrue,
      );
    });

    test('refuse un numéro de build identique', () {
      expect(
        UpdateService.isNewerVersion('4.8.0+499', '4.8.0+499'),
        isFalse,
      );
    });

    test('refuse un numéro de build inférieur', () {
      expect(
        UpdateService.isNewerVersion('4.8.0+498', '4.8.0+499'),
        isFalse,
      );
    });

    test('détecte une version métier supérieure', () {
      expect(
        UpdateService.isNewerVersion('4.9.0+1', '4.8.0+999'),
        isTrue,
      );
    });

    test('refuse une version métier inférieure', () {
      expect(
        UpdateService.isNewerVersion('4.7.9+999', '4.8.0+1'),
        isFalse,
      );
    });

    test('accepte un préfixe v', () {
      expect(
        UpdateService.isNewerVersion('v4.8.0+500', '4.8.0+499'),
        isTrue,
      );
    });

    test('gère une version sans numéro de build', () {
      expect(
        UpdateService.isNewerVersion('4.8.1', '4.8.0+999'),
        isTrue,
      );
    });
  });
}
