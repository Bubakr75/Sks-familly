import 'dart:convert';
import 'dart:typed_data';

import 'package:family_score/utils/image_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(ImageCacheUtil.clearAll);
  tearDown(ImageCacheUtil.clearAll);

  test('le cache réutilise les octets et reste limité en nombre', () {
    final first = base64Encode([0]);
    final bytes = ImageCacheUtil.getBytes(first);
    expect(identical(bytes, ImageCacheUtil.getBytes(first)), isTrue);
    for (var i = 1; i <= ImageCacheUtil.maxEntries; i++) {
      ImageCacheUtil.getBytes(base64Encode([i]));
    }
    expect(ImageCacheUtil.cachedEntryCount, ImageCacheUtil.maxEntries);
    expect(identical(bytes, ImageCacheUtil.getBytes(first)), isFalse);
  });

  test('une photo récemment utilisée est conservée lors de l’éviction', () {
    final first = base64Encode([0]);
    final bytes = ImageCacheUtil.getBytes(first);
    for (var i = 1; i < ImageCacheUtil.maxEntries; i++) {
      ImageCacheUtil.getBytes(base64Encode([i]));
    }
    ImageCacheUtil.getBytes(first);
    ImageCacheUtil.getBytes(base64Encode([100]));
    expect(identical(bytes, ImageCacheUtil.getBytes(first)), isTrue);
  });

  test('le budget d’octets est respecté même pour de grandes photos', () {
    final data = Uint8List(9 * 1024 * 1024);
    ImageCacheUtil.getBytes(base64Encode(data));
    data[0] = 1;
    ImageCacheUtil.getBytes(base64Encode(data));
    expect(ImageCacheUtil.cachedEntryCount, 1);
    expect(ImageCacheUtil.cachedByteCount,
        lessThanOrEqualTo(ImageCacheUtil.maxBytes));
  });

  test('donnée invalide et URL ne remplissent pas le cache', () {
    expect(ImageCacheUtil.getBytes('%%%'), isNull);
    expect(ImageCacheUtil.getBytes('https://example.test/photo'), isNull);
    expect(ImageCacheUtil.cachedEntryCount, 0);
    final photo = base64Encode([1, 2, 3]);
    ImageCacheUtil.getBytes(photo);
    ImageCacheUtil.invalidate(photo);
    expect(ImageCacheUtil.cachedByteCount, 0);
  });
}
