// lib/utils/image_cache.dart
//
// Cache global des images décodées depuis base64.
// Évite le clignotement des photos de profil : les bytes sont décodés
// UNE SEULE FOIS puis gardés en mémoire pour les rebuilds suivants.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Cache statique partagé entre tous les widgets.
/// Clé = base64 string, Valeur = MemoryImage en cache Flutter.
class ImageCacheUtil {
  static const maxEntries = 64;
  static const maxBytes = 16 * 1024 * 1024;
  static int _cachedBytes = 0;
  static final _bytesCache = <String, Uint8List>{};
  static final Map<String, MemoryImage> _imageCache = {};

  @visibleForTesting
  static int get cachedEntryCount => _bytesCache.length;
  @visibleForTesting
  static int get cachedByteCount => _cachedBytes;

  /// Retourne les bytes décodés d'une string base64 (mis en cache).
  static Uint8List? getBytes(String? base64Str) {
    if (base64Str == null || base64Str.isEmpty) return null;

    // Si c'est une URL, on ne cache pas (géré par Image.network)
    if (base64Str.startsWith('http')) return null;

    final cached = _bytesCache.remove(base64Str);
    if (cached != null) {
      _bytesCache[base64Str] = cached;
      return cached;
    }
    try {
      final bytes = base64Decode(base64Str);
      if (bytes.isEmpty) return null;
      // Les très grandes images restent utilisables sans être retenues ici.
      if (bytes.length > maxBytes) return bytes;
      while (_bytesCache.isNotEmpty &&
          (_bytesCache.length >= maxEntries || _cachedBytes + bytes.length > maxBytes)) {
        invalidate(_bytesCache.keys.first);
      }
      _bytesCache[base64Str] = bytes;
      _cachedBytes += bytes.length;
      return bytes;
    } catch (_) {
      return null;
    }
  }

  /// Retourne un MemoryImage mis en cache pour une string base64.
  /// Retourne null si le décodage échoue ou si c'est une URL.
  static MemoryImage? getImage(String? base64Str) {
    if (base64Str == null || base64Str.isEmpty) return null;
    if (base64Str.startsWith('http')) return null;

    final bytes = getBytes(base64Str);
    if (bytes == null || bytes.isEmpty) return MemoryImage(_transparentPixel);
    if (!_bytesCache.containsKey(base64Str)) return MemoryImage(bytes);
    return _imageCache.putIfAbsent(base64Str, () => MemoryImage(bytes));
  }

  /// Précharge une image base64 dans le cache Flutter (asynchrone).
  static Future<void> warmUp(
      BuildContext? context, String? base64Str) async {
    final img = getImage(base64Str);
    if (img == null || context == null) return;
    try {
      await precacheImage(img, context);
    } catch (_) {}
  }

  /// Vide le cache quand une photo change (nouvelle photo uploadée).
  static void invalidate(String? base64Str) {
    if (base64Str == null) return;
    final removed = _bytesCache.remove(base64Str);
    if (removed != null) _cachedBytes -= removed.length;
    _imageCache.remove(base64Str);
  }

  /// Vide tout le cache (utile au changement de famille).
  static void clearAll() {
    _bytesCache.clear();
    _imageCache.clear();
    _cachedBytes = 0;
  }

  // 1x1 pixel PNG transparent pour les fallbacks
  static final Uint8List _transparentPixel = Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
    0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
    0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41,
    0x54, 0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
    0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
    0x42, 0x60, 0x82,
  ]);
}

/// Widget d'avatar stable qui ne se reconstruit QUE quand la photo
/// ou ses données visuelles changent — PAS à chaque notifyListeners() du provider.
/// C'est ce widget qui élimine définitivement le clignotement.
class StableAvatar extends StatelessWidget {
  final String photoBase64;
  final String emoji;
  final String name;
  final double radius;
  final Color color;

  const StableAvatar({
    super.key,
    required this.photoBase64,
    required this.emoji,
    required this.name,
    required this.radius,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return _StableAvatarImpl(
      photoBase64: photoBase64,
      emoji: emoji,
      name: name,
      radius: radius,
      color: color,
    );
  }
}

class _StableAvatarImpl extends StatefulWidget {
  final String photoBase64;
  final String emoji;
  final String name;
  final double radius;
  final Color color;

  const _StableAvatarImpl({
    required this.photoBase64,
    required this.emoji,
    required this.name,
    required this.radius,
    required this.color,
  });

  @override
  State<_StableAvatarImpl> createState() => _StableAvatarImplState();
}

class _StableAvatarImplState extends State<_StableAvatarImpl> {
  MemoryImage? _cachedImage;
  String? _lastBase64;

  @override
  Widget build(BuildContext context) {
    // Recharger l'image UNIQUEMENT si le base64 a changé
    if (widget.photoBase64.isNotEmpty &&
        widget.photoBase64 != _lastBase64) {
      _lastBase64 = widget.photoBase64;
      if (!widget.photoBase64.startsWith('http')) {
        _cachedImage = ImageCacheUtil.getImage(widget.photoBase64);
      }
    }

    Widget core;
    if (widget.photoBase64.isNotEmpty) {
      if (widget.photoBase64.startsWith('http')) {
        core = CircleAvatar(
          radius: widget.radius,
          backgroundColor: widget.color,
          child: ClipOval(
            child: Image.network(
              widget.photoBase64,
              fit: BoxFit.cover,
              width: widget.radius * 2,
              height: widget.radius * 2,
              errorBuilder: (_, __, ___) => _letter(),
            ),
          ),
        );
      } else if (_cachedImage != null) {
        core = CircleAvatar(
          radius: widget.radius,
          backgroundImage: _cachedImage,
        );
      } else {
        core = CircleAvatar(
          radius: widget.radius,
          backgroundColor: widget.color,
          child: _letter(),
        );
      }
    } else {
      core = CircleAvatar(
        radius: widget.radius,
        backgroundColor: widget.color,
        child: _letter(),
      );
    }

    return core;
  }

  Widget _letter() {
    return Text(
      widget.emoji.isNotEmpty
          ? widget.emoji
          : (widget.name.isNotEmpty
              ? widget.name[0].toUpperCase()
              : '?'),
      style: TextStyle(
        color: Colors.white,
        fontSize: widget.radius * 0.8,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}
