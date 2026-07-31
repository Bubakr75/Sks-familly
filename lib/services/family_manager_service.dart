import 'package:cloud_functions/cloud_functions.dart';

class FamilyManagerMember {
  const FamilyManagerMember({
    required this.memberId,
    required this.displayName,
    required this.role,
    required this.durable,
  });

  final String memberId;
  final String displayName;
  final String role;
  final bool durable;

  factory FamilyManagerMember.fromMap(Map<String, dynamic> map) {
    return FamilyManagerMember(
      memberId: _requiredId(map['memberId']),
      displayName: _boundedText(map['displayName'], fallback: 'Parent'),
      role: switch (map['role']) {
        'manager' || 'familyAdmin' => 'manager',
        'parent' => 'parent',
        _ => throw const FormatException('Rôle de membre invalide.'),
      },
      durable: map['durable'] == true,
    );
  }
}

class FamilyAccessContext {
  const FamilyAccessContext({
    required this.familyId,
    required this.role,
    required this.canManageCode,
    this.code,
  });

  final String familyId;
  final String role;
  final bool canManageCode;
  final String? code;

  factory FamilyAccessContext.fromMap(Map<String, dynamic> map) {
    final role = switch (map['role']) {
      'owner' => 'owner',
      'manager' || 'familyAdmin' => 'manager',
      'parent' => 'parent',
      'child' => 'child',
      _ => throw const FormatException('Rôle familial invalide.'),
    };
    final canManageCode = map['canManageCode'];
    if (canManageCode is! bool) {
      throw const FormatException('Autorisation du code invalide.');
    }
    final rawCode = map['code'];
    final code = rawCode == null ? null : _familyCode(rawCode);
    if (!canManageCode && code != null) {
      throw const FormatException('Le serveur a exposé un code interdit.');
    }
    return FamilyAccessContext(
      familyId: _requiredId(map['familyId']),
      role: role,
      canManageCode: canManageCode,
      code: code,
    );
  }
}

class FamilyManagerService {
  FamilyManagerService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  Future<List<FamilyManagerMember>> listMembers(String familyId) async {
    final result = await _call('listFamilyManagers', {
      'familyId': _requiredId(familyId),
    });
    final raw = result['members'];
    if (raw is! List) {
      throw const FormatException('Liste de membres invalide.');
    }
    return raw
        .map((item) => FamilyManagerMember.fromMap(_map(item)))
        .toList(growable: false);
  }

  Future<void> setManager({
    required String familyId,
    required String memberId,
  }) async {
    final result = await _call('setFamilyManager', {
      'familyId': _requiredId(familyId),
      'memberId': _requiredId(memberId),
    });
    if (result['role'] != 'manager') {
      throw const FormatException('Rôle gestionnaire non confirmé.');
    }
  }

  Future<void> revokeManager({
    required String familyId,
    required String memberId,
  }) async {
    final result = await _call('revokeFamilyManager', {
      'familyId': _requiredId(familyId),
      'memberId': _requiredId(memberId),
    });
    if (result['role'] != 'parent') {
      throw const FormatException('Révocation non confirmée.');
    }
  }

  Future<FamilyAccessContext> getAccessContext(String familyId) async {
    final result = await _call('getFamilyAccessContext', {
      'familyId': _requiredId(familyId),
    });
    final context = FamilyAccessContext.fromMap(result);
    if (context.familyId != familyId.trim()) {
      throw const FormatException('La réponse concerne une autre famille.');
    }
    return context;
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
        error.message ?? 'Gestion familiale indisponible (${error.code}).',
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

String _boundedText(Object? value, {required String fallback}) {
  if (value is! String || value.trim().isEmpty) return fallback;
  final text = value.trim();
  return text.length <= 80 ? text : text.substring(0, 80);
}

String _familyCode(Object? value) {
  if (value is! String) throw const FormatException('Code famille invalide.');
  final code = value.trim().toUpperCase();
  if (!RegExp(r'^[A-Z0-9]{4,10}$').hasMatch(code)) {
    throw const FormatException('Code famille invalide.');
  }
  return code;
}
