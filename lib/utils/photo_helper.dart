// lib/utils/photo_helper.dart
//
// 📸 Helper pour prendre et recadrer des photos.
// Utilise image_picker + image_cropper pour le recadrage manuel.

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'image_compressor.dart';

class PhotoHelper {
  /// Prend une photo (caméra) et propose le recadrage.
  /// Retourne le base64 compressé, ou null si annulé.
  static Future<String?> pickAndCropFromCamera() async {
    final xfile = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
      maxWidth: 1000,
    );
    if (xfile == null) return null;
    return _cropAndCompress(xfile);
  }

  /// Choisit une image (galerie) et propose le recadrage.
  /// Retourne le base64 compressé, ou null si annulé.
  static Future<String?> pickAndCropFromGallery() async {
    final xfile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1000,
    );
    if (xfile == null) return null;
    return _cropAndCompress(xfile);
  }

  /// Affiche un bottom sheet pour choisir caméra ou galerie, puis recadre.
  static Future<String?> pickAndCrop(BuildContext context,
      {CropStyle cropStyle = CropStyle.rectangle,
      List<CropAspectRatioPreset> aspectRatios = const [
        CropAspectRatioPreset.original,
        CropAspectRatioPreset.square,
        CropAspectRatioPreset.ratio3x2,
        CropAspectRatioPreset.ratio4x3,
      ]}) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF0F2620),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: Colors.amber),
              title: const Text('Prendre une photo', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: Colors.tealAccent),
              title: const Text('Choisir dans la galerie', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );

    if (source == null) return null;

    final xfile = await ImagePicker().pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1000,
    );
    if (xfile == null) return null;

    return _cropAndCompress(xfile, cropStyle: cropStyle, aspectRatios: aspectRatios);
  }

  static Future<String?> _cropAndCompress(
    XFile xfile, {
    CropStyle cropStyle = CropStyle.rectangle,
    List<CropAspectRatioPreset> aspectRatios = const [
      CropAspectRatioPreset.original,
      CropAspectRatioPreset.square,
      CropAspectRatioPreset.ratio3x2,
      CropAspectRatioPreset.ratio4x3,
    ],
  }) async {
    try {
      // Étape 1 : Recadrage manuel
      final cropped = await ImageCropper().cropImage(
        sourcePath: xfile.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Recadrer',
            toolbarColor: const Color(0xFF0F2620),
            toolbarWidgetColor: Colors.white,
            activeControlsWidgetColor: const Color(0xFFD4AF37),
            aspectRatioPresets: aspectRatios,
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: 'Recadrer',
            aspectRatioPresets: aspectRatios,
          ),
          WebUiSettings(
            context: _globalContext!,
            presentStyle: WebPresentStyle.dialog,
            size: const CropperSize(width: 500, height: 500),
          ),
        ],
      );

      if (cropped == null) return null;

      // Étape 2 : Lire les bytes recadrés
      final bytes = await cropped.readAsBytes();

      // Étape 3 : Compresser en base64
      final base64 = base64Encode(bytes);
      final compressed = await ImageCompressor.compressBase64(base64) ?? base64;

      return compressed;
    } catch (e) {
      if (kDebugMode) debugPrint('PhotoHelper error: $e');
      // Fallback : retourner l'image non recadrée
      final bytes = await xfile.readAsBytes();
      final base64 = base64Encode(bytes);
      return await ImageCompressor.compressBase64(base64) ?? base64;
    }
  }

  /// Contexte global pour le WebUiSettings (à initialiser au démarrage)
  static BuildContext? _globalContext;
  static void init(BuildContext context) {
    _globalContext = context;
  }
}
