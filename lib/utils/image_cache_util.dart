// lib/utils/image_cache_util.dart

import 'dart:convert';
import 'dart:typed_data';

class ImageCacheUtil {
  static final Map<int, Uint8List> _cache = {};

  /// Decode base64 une seule fois et met en cache
  static Uint8List fromBase64(String base64Str) {
    final key = base64Str.hashCode;
    if (_cache.containsKey(key)) return _cache[key]!;
    final bytes = base64Decode(base64Str);
    _cache[key] = bytes;
    return bytes;
  }

  /// Vide le cache (a appeler si memoire trop utilisee)
  static void clear() => _cache.clear();

  /// Supprime une entree specifique
  static void remove(String base64Str) => _cache.remove(base64Str.hashCode);
}