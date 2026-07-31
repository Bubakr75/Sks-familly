import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:family_score/services/action_photo_service.dart';

void main() {
  test('reconnaît JPEG, PNG et WebP', () {
    expect(
      ActionPhoto.detectContentType(
        Uint8List.fromList([0xff, 0xd8, 0xff, 0xd9]),
      ),
      'image/jpeg',
    );
    expect(
      ActionPhoto.detectContentType(
        Uint8List.fromList([0x89, 0x50, 0x4e, 0x47, 13, 10, 26, 10]),
      ),
      'image/png',
    );
    expect(
      ActionPhoto.detectContentType(
        Uint8List.fromList([
          0x52,
          0x49,
          0x46,
          0x46,
          0,
          0,
          0,
          0,
          0x57,
          0x45,
          0x42,
          0x50,
        ]),
      ),
      'image/webp',
    );
  });

  test('refuse un mauvais format et une taille supérieure à 5 Mo', () {
    expect(
      () => ActionPhoto.validate(Uint8List.fromList([1, 2, 3])),
      throwsFormatException,
    );
    final oversized = Uint8List(ActionPhoto.maxBytes + 1)
      ..[0] = 0xff
      ..[1] = 0xd8
      ..[2] = 0xff;
    expect(() => ActionPhoto.validate(oversized), throwsFormatException);
  });
}
