import 'package:cloud_functions/cloud_functions.dart';
import 'package:uuid/uuid.dart';

class FamilyOwnershipResult {
  const FamilyOwnershipResult({
    required this.familyId,
    required this.idempotent,
  });

  final String familyId;
  final bool idempotent;

  factory FamilyOwnershipResult.fromMap(Map<String, dynamic> map) {
    if (map['status'] != 'completed' || map['idempotent'] is! bool) {
      throw const FormatException('Transfert non confirmé par le serveur.');
    }
    return FamilyOwnershipResult(
      familyId: _requiredId(map['familyId']),
      idempotent: map['idempotent'] as bool,
    );
  }
}

class FamilyRecoveryCodeReceipt {
  const FamilyRecoveryCodeReceipt({
    required this.familyId,
    required this.code,
    required this.expiresInDays,
  });

  final String familyId;
  final String code;
  final int expiresInDays;

  factory FamilyRecoveryCodeReceipt.fromMap(Map<String, dynamic> map) {
    final code = map['recoveryCode'];
    final days = map['expiresInDays'];
    if (code is! String ||
        code.length < 40 ||
        code.length > 128 ||
        days is! int ||
        days < 1 ||
        days > 365) {
      throw const FormatException('Code de récupération invalide.');
    }
    return FamilyRecoveryCodeReceipt(
      familyId: _requiredId(map['familyId']),
      code: code,
      expiresInDays: days,
    );
  }
}

class FamilyOwnershipService {
  FamilyOwnershipService({
    FirebaseFunctions? functions,
    Uuid? uuid,
  })  : _functions = functions ?? FirebaseFunctions.instance,
        _uuid = uuid ?? const Uuid();

  final FirebaseFunctions _functions;
  final Uuid _uuid;

  Future<FamilyOwnershipResult> transfer({
    required String familyId,
    required String targetMemberId,
    required String previousOwnerRole,
  }) async {
    if (!['manager', 'parent'].contains(previousOwnerRole)) {
      throw const FormatException('Futur rôle invalide.');
    }
    final result = await _call('transferFamilyOwnership', {
      'familyId': _requiredId(familyId),
      'targetMemberId': _requiredId(targetMemberId),
      'operationId': _uuid.v4(),
      'previousOwnerRole': previousOwnerRole,
      'confirmation': 'TRANSFERER LA PROPRIETE',
    });
    return FamilyOwnershipResult.fromMap(result);
  }

  Future<FamilyRecoveryCodeReceipt> generateRecoveryCode(
    String familyId,
  ) async {
    final result = await _call('generateFamilyRecoveryCode', {
      'familyId': _requiredId(familyId),
    });
    final receipt = FamilyRecoveryCodeReceipt.fromMap(result);
    if (receipt.familyId != familyId.trim()) {
      throw const FormatException('La réponse concerne une autre famille.');
    }
    return receipt;
  }

  Future<void> revokeRecoveryCode(String familyId) async {
    final result = await _call('revokeFamilyRecoveryCode', {
      'familyId': _requiredId(familyId),
    });
    if (result['status'] != 'revoked') {
      throw const FormatException('Révocation non confirmée.');
    }
  }

  Future<FamilyOwnershipResult> recover({
    required String familyId,
    required String recoveryCode,
  }) async {
    final code = recoveryCode.trim();
    if (code.length < 40 || code.length > 128) {
      throw const FormatException('Code de récupération invalide.');
    }
    final result = await _call('recoverFamilyOwnership', {
      'familyId': _requiredId(familyId),
      'operationId': _uuid.v4(),
      'recoveryCode': code,
      'confirmation': 'RECUPERER LA PROPRIETE',
    });
    return FamilyOwnershipResult.fromMap(result);
  }

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await _functions.httpsCallable(name).call(payload);
      return _map(response.data);
    } on FirebaseFunctionsException catch (error) {
      throw StateError(
        error.message ?? 'Gestion de propriété indisponible (${error.code}).',
      );
    }
  }
}

Map<String, dynamic> _map(Object? value) {
  if (value is! Map) throw const FormatException('Réponse serveur invalide.');
  return value.map<String, dynamic>((key, dynamic item) {
    if (key is! String) throw const FormatException('Clé serveur invalide.');
    return MapEntry(key, item);
  });
}

String _requiredId(Object? value) {
  if (value is! String) throw const FormatException('Identifiant invalide.');
  final id = value.trim();
  if (id.isEmpty ||
      id.length > 128 ||
      id.contains('/') ||
      RegExp(r'[\u0000-\u001f]').hasMatch(id)) {
    throw const FormatException('Identifiant invalide.');
  }
  return id;
}
