import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

class ActionPhoto {
  static const maxBytes = 5 * 1024 * 1024;

  final Uint8List bytes;
  final String contentType;
  final String extension;

  const ActionPhoto({
    required this.bytes,
    required this.contentType,
    required this.extension,
  });

  static String? detectContentType(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff) {
      return 'image/jpeg';
    }
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0d &&
        bytes[5] == 0x0a &&
        bytes[6] == 0x1a &&
        bytes[7] == 0x0a) {
      return 'image/png';
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'image/webp';
    }
    return null;
  }

  static void validate(Uint8List bytes) {
    if (detectContentType(bytes) == null) {
      throw const FormatException(
        'Seules les images JPEG, PNG et WebP sont acceptées.',
      );
    }
    if (bytes.length > maxBytes) {
      throw const FormatException(
        'La photo dépasse 5 Mo après compression.',
      );
    }
  }
}

class ActionPhotoService {
  final ImagePicker _picker;

  ActionPhotoService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  /// Sélectionne puis réencode en JPEG. Le réencodage retire les métadonnées
  /// EXIF et produit le même résultat sur Android et Web/PWA.
  Future<ActionPhoto?> pickAndPrepare(ImageSource source) async {
    final file = await _picker.pickImage(
      source: source,
      maxWidth: 2400,
      maxHeight: 2400,
      imageQuality: 95,
    );
    if (file == null) return null;
    return prepare(await file.readAsBytes());
  }

  Future<ActionPhoto> prepare(Uint8List originalBytes) async {
    if (ActionPhoto.detectContentType(originalBytes) == null) {
      throw const FormatException(
        'Seules les images JPEG, PNG et WebP sont acceptées.',
      );
    }
    final compressed = await FlutterImageCompress.compressWithList(
      originalBytes,
      minWidth: 1920,
      minHeight: 1920,
      quality: 82,
      format: CompressFormat.jpeg,
      keepExif: false,
    );
    final bytes = Uint8List.fromList(compressed);
    ActionPhoto.validate(bytes);
    return ActionPhoto(
      bytes: bytes,
      contentType: 'image/jpeg',
      extension: 'jpg',
    );
  }
}
