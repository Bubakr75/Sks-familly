import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/family_join_request.dart';

class FamilyJoinException implements Exception {
  const FamilyJoinException({
    required this.code,
    required this.message,
    this.details,
  });

  final String code;
  final String message;
  final Object? details;

  @override
  String toString() => message;
}

class FamilyJoinService {
  FamilyJoinService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  static const pendingPreferenceKey = 'pending_family_join_v1';

  final FirebaseFunctions _functions;

  Future<FamilyJoinRequestResult> requestFamilyJoin({
    required String code,
    required FamilyJoinRole requestedRole,
    required String deviceId,
    required String deviceName,
    String? requestedChildName,
  }) async {
    final normalizedCode = _normalizeCode(code);
    final normalizedDeviceId = _requiredText(
      deviceId,
      field: 'Identifiant de l’appareil',
      maximumLength: 200,
    );
    final normalizedDeviceName = _requiredText(
      deviceName,
      field: 'Nom de l’appareil',
      maximumLength: 80,
    );

    String? normalizedChildName;

    if (requestedRole == FamilyJoinRole.child) {
      normalizedChildName = _requiredText(
        requestedChildName,
        field: 'Prénom de l’enfant',
        maximumLength: 80,
      );
    }

    try {
      final payload = <String, dynamic>{
        'code': normalizedCode,
        'requestedRole': requestedRole.wireValue,
        'deviceId': normalizedDeviceId,
        'deviceName': normalizedDeviceName,
        if (normalizedChildName != null)
          'requestedChildName': normalizedChildName,
      };

      final callable = _functions.httpsCallable('requestFamilyJoin');
      final callableResult = await callable.call(payload);
      final result = FamilyJoinRequestResult.fromMap(
        _asStringMap(callableResult.data),
        fallbackRequestedRole: requestedRole,
      );

      await savePendingRequest(
        PendingFamilyJoin(
          familyId: result.familyId,
          familyCode: normalizedCode,
          requestId: result.requestId,
          requestedRole: result.requestedRole,
        ),
      );

      return result;
    } on FirebaseFunctionsException catch (error) {
      throw FamilyJoinException(
        code: error.code,
        message: error.message ?? _defaultMessageForCode(error.code),
        details: error.details,
      );
    } on FormatException catch (error) {
      throw FamilyJoinException(
        code: 'invalid-response',
        message: 'Réponse de connexion invalide : ${error.message}',
      );
    }
  }

  Future<FamilyJoinStatusResult> getFamilyJoinStatus({
    required String familyId,
  }) async {
    final normalizedFamilyId = _requiredText(
      familyId,
      field: 'Identifiant de la famille',
      maximumLength: 200,
    );

    try {
      final callable = _functions.httpsCallable('getFamilyJoinStatus');
      final callableResult = await callable.call({
        'familyId': normalizedFamilyId,
      });

      final result = FamilyJoinStatusResult.fromMap(
        _asStringMap(callableResult.data),
      );

      if (result.familyId != normalizedFamilyId) {
        throw const FormatException(
          'La réponse concerne une autre famille.',
        );
      }

      return result;
    } on FirebaseFunctionsException catch (error) {
      throw FamilyJoinException(
        code: error.code,
        message: error.message ?? _defaultMessageForCode(error.code),
        details: error.details,
      );
    } on FormatException catch (error) {
      throw FamilyJoinException(
        code: 'invalid-response',
        message: 'Réponse de statut invalide : ${error.message}',
      );
    }
  }

  Future<FamilyJoinStatusResult?> checkPendingRequest() async {
    final pending = await loadPendingRequest();

    if (pending == null) {
      return null;
    }

    return getFamilyJoinStatus(familyId: pending.familyId);
  }

  Future<void> savePendingRequest(PendingFamilyJoin pending) async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = jsonEncode(pending.toJson());
    final saved = await preferences.setString(
      pendingPreferenceKey,
      encoded,
    );

    if (!saved) {
      throw const FamilyJoinException(
        code: 'local-storage-failed',
        message:
            'La demande a été envoyée, mais elle n’a pas pu être enregistrée '
            'sur cet appareil.',
      );
    }
  }

  Future<PendingFamilyJoin?> loadPendingRequest() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(pendingPreferenceKey);

    if (encoded == null || encoded.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(encoded);

      if (decoded is! Map) {
        throw const FormatException('Format local invalide.');
      }

      return PendingFamilyJoin.fromJson(_asStringMap(decoded));
    } on FormatException {
      await preferences.remove(pendingPreferenceKey);
      return null;
    }
  }

  Future<void> clearPendingRequest() async {
    final preferences = await SharedPreferences.getInstance();
    final removed = await preferences.remove(pendingPreferenceKey);

    if (!removed && preferences.containsKey(pendingPreferenceKey)) {
      throw const FamilyJoinException(
        code: 'local-storage-failed',
        message:
            'La demande a été traitée, mais son état local n’a pas pu être '
            'supprimé.',
      );
    }
  }

  static Map<String, dynamic> _asStringMap(Object? value) {
    if (value is! Map) {
      throw const FormatException('Objet JSON attendu.');
    }

    return value.map<String, dynamic>((key, dynamic item) {
      if (key is! String) {
        throw const FormatException('Clé JSON invalide.');
      }

      return MapEntry(key, item);
    });
  }

  static String _normalizeCode(String value) {
    final code = value.trim().toUpperCase();

    if (code.length < 4 ||
        code.length > 10 ||
        !RegExp(r'^[A-Z0-9]+$').hasMatch(code)) {
      throw const FamilyJoinException(
        code: 'invalid-argument',
        message:
            'Le code famille doit contenir entre 4 et 10 lettres ou chiffres.',
      );
    }

    return code;
  }

  static String _requiredText(
    String? value, {
    required String field,
    required int maximumLength,
  }) {
    final normalized = value?.trim() ?? '';

    if (normalized.isEmpty || normalized.length > maximumLength) {
      throw FamilyJoinException(
        code: 'invalid-argument',
        message: '$field est absent ou invalide.',
      );
    }

    if (normalized.contains('/') ||
        RegExp(r'[\u0000-\u001f]').hasMatch(normalized)) {
      throw FamilyJoinException(
        code: 'invalid-argument',
        message: '$field contient des caractères interdits.',
      );
    }

    return normalized;
  }

  static String _defaultMessageForCode(String code) {
    return switch (code) {
      'unauthenticated' =>
        'L’authentification Firebase de cet appareil est indisponible.',
      'not-found' => 'Code famille ou demande introuvable.',
      'already-exists' => 'Cet appareil appartient déjà à cette famille.',
      'failed-precondition' =>
        'Cette famille doit être mise à jour par son parent.',
      'resource-exhausted' =>
        'Trop de tentatives. Veuillez réessayer plus tard.',
      'permission-denied' => 'Cette opération n’est pas autorisée.',
      'unavailable' =>
        'Le service est temporairement indisponible. Réessayez plus tard.',
      _ => 'Impossible de contacter le service de connexion familiale.',
    };
  }
}
