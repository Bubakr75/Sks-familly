// lib/utils/image_compressor.dart
//
// Utilitaire de compression d'images pour SKS Family.
// Redimensionne les photos (max 800px de large) + compresse (qualité 75%)
// AVANT l'upload vers Firebase Storage.
//
// Bénéfices :
//   - Photos 3-5 Mo → ~150-300 Ko (10x plus léger !)
//   - Upload beaucoup plus rapide
//   - Moins de data consommée pour l'utilisateur
//   - Marge de sécurité (même si jamais une photo base64 reste dans Firestore)

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class ImageCompressor {
  ImageCompressor._();

  /// Compresse une image base64.
  /// - [base64Data] : l'image en base64 (avec ou sans préfixe data:image...)
  /// - Retourne l'image compressée en base64 (sans préfixe), prête pour Storage.
  static Future<String?> compressBase64(String base64Data) async {
    try {
      // Nettoyer le préfixe si présent
      String clean = base64Data;
      if (clean.contains(',')) {
        clean = clean.split(',').last;
      }

      // Décoder en bytes
      final Uint8List originalBytes = base64Decode(clean);

      // Compresse : max 800px de large, qualité 75%
      // (une photo de 5 Mo devient ~200 Ko)
      final Uint8List? compressedBytes =
          await FlutterImageCompress.compressWithList(
        originalBytes,
        minWidth: 800,
        minHeight: 800,
        quality: 75,
        format: CompressFormat.jpeg,
      );

      if (compressedBytes == null || compressedBytes.isEmpty) {
        // Échec compression → retourner l'original
        return clean;
      }

      // Re-encoder en base64
      final compressed = base64Encode(compressedBytes);

      if (kDebugMode) {
        final originalKb = (originalBytes.length / 1024).round();
        final compressedKb = (compressedBytes.length / 1024).round();
        debugPrint(
            'ImageCompressor: ${originalKb}KB → ${compressedKb}KB (${(100 * compressedBytes.length / originalBytes.length).round()}%)');
      }

      return compressed;
    } catch (e) {
      if (kDebugMode) debugPrint('ImageCompressor error: $e');
      // En cas d'erreur, retourner l'original non compressé
      return base64Data.contains(',') ? base64Data.split(',').last : base64Data;
    }
  }
}
