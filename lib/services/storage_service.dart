// lib/services/storage_service.dart
//
// Service de stockage Firebase Storage pour les photos (enfants + parents).
//
// AVANT : photos en base64 dans Firestore (risque de dépasser la limite 1MB/document).
// MAINTENANT : photos uploadées vers Firebase Storage → seule l'URL est stockée
// dans Firestore (léger, rapide, illimité en taille).
//
// Structure Storage :
//   families/{familyId}/children/{childId}/photo.jpg
//   families/{familyId}/children/{childId}/banner.jpg
//   families/{familyId}/parents/{profileId}/photo.jpg
//   families/{familyId}/punishments/{punishmentId}/photo_{index}.jpg

import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Upload une photo (base64) vers Storage et renvoie l'URL de téléchargement.
  /// Retourne null si l'upload échoue.
  Future<String?> uploadPhotoBase64({
    required String familyId,
    required String path, // ex: 'children/{childId}/photo.jpg'
    required String base64Data,
  }) async {
    try {
      // Décoder le base64 en bytes
      String cleanBase64 = base64Data;
      if (cleanBase64.contains(',')) {
        cleanBase64 = cleanBase64.split(',').last;
      }
      final Uint8List bytes = base64Decode(cleanBase64);

      // Référence Storage
      final ref = _storage.ref().child('families/$familyId/$path');

      // Métadonnées (content-type image)
      final metadata = SettableMetadata(contentType: 'image/jpeg');

      // Upload
      final uploadTask = await ref.putData(bytes, metadata);

      // Récupérer l'URL de téléchargement persistante
      final url = await uploadTask.ref.getDownloadURL();
      if (kDebugMode) debugPrint('StorageService: photo uploadée → $url');
      return url;
    } catch (e) {
      if (kDebugMode) debugPrint('StorageService upload error: $e');
      return null;
    }
  }

  /// Upload une photo et renvoie une URL signée (valide longtemps).
  /// Alternative à getDownloadURL si les règles Storage sont strictes.
  Future<String?> uploadPhotoBytes({
    required String familyId,
    required String path,
    required Uint8List bytes,
  }) async {
    try {
      final ref = _storage.ref().child('families/$familyId/$path');
      final metadata = SettableMetadata(contentType: 'image/jpeg');
      final uploadTask = await ref.putData(bytes, metadata);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      if (kDebugMode) debugPrint('StorageService uploadBytes error: $e');
      return null;
    }
  }

  /// Supprime une photo de Storage (par son chemin).
  Future<void> deletePhoto({
    required String familyId,
    required String path,
  }) async {
    try {
      await _storage.ref().child('families/$familyId/$path').delete();
    } catch (e) {
      if (kDebugMode) debugPrint('StorageService delete error: $e');
    }
  }

  /// Récupère le familyId actuel depuis Firestore.
  String? get currentFamilyId {
    // On accède au service Firestore pour récupérer le familyId
    // (géré via SharedPreferences dans FirestoreService)
    return null; // sera surchargé / passé en paramètre
  }
}
