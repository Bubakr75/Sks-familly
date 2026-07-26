import 'package:cloud_functions/cloud_functions.dart';

class FamilyManagementException implements Exception {
  const FamilyManagementException({
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

class FamilyCreationResult {
  const FamilyCreationResult({
    required this.familyId,
    required this.code,
    required this.alreadyCreated,
  });

  final String familyId;
  final String code;
  final bool alreadyCreated;

  factory FamilyCreationResult.fromData(Object? data) {
    final map = _asStringMap(data);
    final familyId = _requiredIdentifier(map, 'familyId');
    final code = _requiredFamilyCode(map, 'code');
    final alreadyCreated = map['alreadyCreated'];

    if (alreadyCreated is! bool) {
      throw const FormatException(
        'alreadyCreated doit être un booléen.',
      );
    }

    return FamilyCreationResult(
      familyId: familyId,
      code: code,
      alreadyCreated: alreadyCreated,
    );
  }
}

class FamilyCodeChangeResult {
  const FamilyCodeChangeResult({
    required this.familyId,
    required this.code,
    required this.unchanged,
  });

  final String familyId;
  final String code;
  final bool unchanged;

  factory FamilyCodeChangeResult.fromData(Object? data) {
    final map = _asStringMap(data);
    final familyId = _requiredIdentifier(map, 'familyId');
    final code = _requiredFamilyCode(map, 'code');
    final unchanged = map['unchanged'];

    if (unchanged is! bool) {
      throw const FormatException(
        'unchanged doit être un booléen.',
      );
    }

    return FamilyCodeChangeResult(
      familyId: familyId,
      code: code,
      unchanged: unchanged,
    );
  }
}

class LegacyFamilyMigrationResult {
  const LegacyFamilyMigrationResult({
    required this.familyId,
    required this.code,
    required this.alreadyMigrated,
  });

  final String familyId;
  final String code;
  final bool alreadyMigrated;

  factory LegacyFamilyMigrationResult.fromData(Object? data) {
    final map = _asStringMap(data);
    final familyId = _requiredIdentifier(map, 'familyId');
    final code = _requiredFamilyCode(map, 'code');
    final alreadyMigrated = map['alreadyMigrated'];

    if (alreadyMigrated is! bool) {
      throw const FormatException(
        'alreadyMigrated doit être un booléen.',
      );
    }

    return LegacyFamilyMigrationResult(
      familyId: familyId,
      code: code,
      alreadyMigrated: alreadyMigrated,
    );
  }
}

class FamilyManagementService {
  FamilyManagementService({
    FirebaseFunctions? functions,
  }) : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  Future<FamilyCreationResult> createFamily({
    required String familyId,
    String? customCode,
  }) async {
    final cleanFamilyId = _requiredIdentifier(
      {'familyId': familyId},
      'familyId',
    );

    final cleanCustomCode = customCode == null || customCode.trim().isEmpty
        ? null
        : _normalizeFamilyCode(customCode);

    try {
      final callable = _functions.httpsCallable('createFamily');
      final callableResult = await callable.call({
        'familyId': cleanFamilyId,
        if (cleanCustomCode != null) 'customCode': cleanCustomCode,
      });

      final result = FamilyCreationResult.fromData(
        callableResult.data,
      );

      if (result.familyId != cleanFamilyId) {
        throw const FormatException(
          'La réponse concerne une autre famille.',
        );
      }

      return result;
    } on FirebaseFunctionsException catch (error) {
      throw FamilyManagementException(
        code: error.code,
        message: error.message ?? _defaultMessageForCode(error.code),
        details: error.details,
      );
    } on FormatException catch (error) {
      throw FamilyManagementException(
        code: 'invalid-response',
        message: 'Réponse de création invalide : ${error.message}',
      );
    }
  }

  Future<LegacyFamilyMigrationResult> migrateLegacyFamily({
    required String familyId,
    required String migrationSecret,
  }) async {
    final cleanFamilyId = _requiredIdentifier(
      {'familyId': familyId},
      'familyId',
    );
    final cleanSecret = migrationSecret.trim();

    if (cleanSecret.isEmpty ||
        cleanSecret.length > 512 ||
        RegExp(r'[\u0000-\u001f]').hasMatch(cleanSecret)) {
      throw const FamilyManagementException(
        code: 'invalid-argument',
        message: 'Le code temporaire de migration est invalide.',
      );
    }

    try {
      final callable = _functions.httpsCallable(
        'migrateLegacyFamily',
      );

      final callableResult = await callable.call({
        'familyId': cleanFamilyId,
        'migrationSecret': cleanSecret,
      });

      final result = LegacyFamilyMigrationResult.fromData(
        callableResult.data,
      );

      if (result.familyId != cleanFamilyId) {
        throw const FormatException(
          'La réponse concerne une autre famille.',
        );
      }

      return result;
    } on FirebaseFunctionsException catch (error) {
      throw FamilyManagementException(
        code: error.code,
        message: error.message ?? _defaultMessageForCode(error.code),
        details: error.details,
      );
    } on FormatException catch (error) {
      throw FamilyManagementException(
        code: 'invalid-response',
        message: 'Réponse de migration invalide : ${error.message}',
      );
    }
  }

  Future<FamilyCodeChangeResult> changeFamilyCode({
    required String familyId,
    required String newCode,
  }) async {
    final cleanFamilyId = _requiredIdentifier(
      {'familyId': familyId},
      'familyId',
    );
    final cleanCode = _normalizeFamilyCode(newCode);

    try {
      final callable = _functions.httpsCallable(
        'changeFamilyCode',
      );

      final callableResult = await callable.call({
        'familyId': cleanFamilyId,
        'newCode': cleanCode,
      });

      final result = FamilyCodeChangeResult.fromData(
        callableResult.data,
      );

      if (result.familyId != cleanFamilyId) {
        throw const FormatException(
          'La réponse concerne une autre famille.',
        );
      }

      if (result.code != cleanCode) {
        throw const FormatException(
          'Le code retourné ne correspond pas au code demandé.',
        );
      }

      return result;
    } on FirebaseFunctionsException catch (error) {
      throw FamilyManagementException(
        code: error.code,
        message: error.message ?? _defaultMessageForCode(error.code),
        details: error.details,
      );
    } on FormatException catch (error) {
      throw FamilyManagementException(
        code: 'invalid-response',
        message: 'Réponse de changement de code invalide : '
            '${error.message}',
      );
    }
  }

  static String _normalizeFamilyCode(String value) {
    final code = value.trim().toUpperCase();

    if (code.length < 4 ||
        code.length > 10 ||
        !RegExp(r'^[A-Z0-9]+$').hasMatch(code)) {
      throw const FamilyManagementException(
        code: 'invalid-argument',
        message: 'Le code famille doit contenir entre 4 et 10 '
            'lettres ou chiffres.',
      );
    }

    return code;
  }

  static String _defaultMessageForCode(String code) {
    return switch (code) {
      'invalid-argument' => 'Le code temporaire de migration est invalide.',
      'failed-precondition' =>
        'Cette migration a expiré, a déjà été utilisée ou n’est plus autorisée.',
      'unauthenticated' => 'L’authentification Firebase est indisponible.',
      'already-exists' => 'Ce code famille est déjà utilisé.',
      'not-found' => 'Famille introuvable.',
      'permission-denied' =>
        'Seul le propriétaire peut effectuer cette opération.',
      'resource-exhausted' => 'Impossible de générer un code unique. Réessaie.',
      'unavailable' => 'Le service est temporairement indisponible.',
      _ => 'Impossible de gérer la famille pour le moment.',
    };
  }
}

Map<String, dynamic> _asStringMap(Object? value) {
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

String _requiredIdentifier(
  Map<String, dynamic> map,
  String key,
) {
  final value = map[key];

  if (value is! String) {
    throw FormatException('$key est absent ou invalide.');
  }

  final cleanValue = value.trim();

  if (cleanValue.isEmpty ||
      cleanValue.length > 200 ||
      cleanValue.contains('/') ||
      RegExp(r'[\u0000-\u001f]').hasMatch(cleanValue)) {
    throw FormatException('$key est absent ou invalide.');
  }

  return cleanValue;
}

String _requiredFamilyCode(
  Map<String, dynamic> map,
  String key,
) {
  final value = map[key];

  if (value is! String) {
    throw FormatException('$key est absent ou invalide.');
  }

  final code = value.trim().toUpperCase();

  if (code.length < 4 ||
      code.length > 10 ||
      !RegExp(r'^[A-Z0-9]+$').hasMatch(code)) {
    throw FormatException('$key est absent ou invalide.');
  }

  return code;
}
