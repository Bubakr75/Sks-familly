enum FamilyJoinRole {
  parent,
  child;

  String get wireValue => name;

  static FamilyJoinRole fromWire(Object? value) {
    return switch (value) {
      'parent' => FamilyJoinRole.parent,
      'child' => FamilyJoinRole.child,
      _ => throw const FormatException('Rôle de connexion invalide.'),
    };
  }
}

enum FamilyJoinStatus {
  pending,
  approved,
  rejected;

  String get wireValue => name;

  static FamilyJoinStatus fromWire(Object? value) {
    return switch (value) {
      'pending' => FamilyJoinStatus.pending,
      'approved' => FamilyJoinStatus.approved,
      'rejected' => FamilyJoinStatus.rejected,
      _ => throw const FormatException('Statut de connexion invalide.'),
    };
  }
}

class FamilyJoinRequestResult {
  const FamilyJoinRequestResult({
    required this.familyId,
    required this.requestId,
    required this.status,
    required this.alreadyPending,
  });

  final String familyId;
  final String requestId;
  final FamilyJoinStatus status;
  final bool alreadyPending;

  factory FamilyJoinRequestResult.fromMap(Map<String, dynamic> map) {
    final familyId = _requiredString(map, 'familyId');
    final requestId = _requiredString(map, 'requestId');
    final status = FamilyJoinStatus.fromWire(map['status']);
    final alreadyPending = map['alreadyPending'];

    if (status != FamilyJoinStatus.pending) {
      throw const FormatException(
        'Une nouvelle demande doit avoir le statut pending.',
      );
    }

    if (alreadyPending is! bool) {
      throw const FormatException('alreadyPending doit être un booléen.');
    }

    return FamilyJoinRequestResult(
      familyId: familyId,
      requestId: requestId,
      status: status,
      alreadyPending: alreadyPending,
    );
  }
}

class FamilyJoinStatusResult {
  const FamilyJoinStatusResult({
    required this.familyId,
    required this.status,
    this.role,
    this.childId,
  });

  final String familyId;
  final FamilyJoinStatus status;
  final FamilyJoinRole? role;
  final String? childId;

  bool get isApproved => status == FamilyJoinStatus.approved;
  bool get isRejected => status == FamilyJoinStatus.rejected;
  bool get isPending => status == FamilyJoinStatus.pending;

  factory FamilyJoinStatusResult.fromMap(Map<String, dynamic> map) {
    final familyId = _requiredString(map, 'familyId');
    final status = FamilyJoinStatus.fromWire(map['status']);

    final rawRole = map['role'];
    final role = rawRole == null ? null : FamilyJoinRole.fromWire(rawRole);

    final rawChildId = map['childId'];
    final childId = rawChildId == null ? null : _requiredString(map, 'childId');

    if (status == FamilyJoinStatus.approved && role == null) {
      throw const FormatException(
        'Une approbation sans membre actif est invalide.',
      );
    }

    if (status != FamilyJoinStatus.approved &&
        (role != null || childId != null)) {
      throw const FormatException(
        'Une demande non approuvée ne doit pas activer de membre.',
      );
    }

    if (role == FamilyJoinRole.child && childId == null) {
      throw const FormatException(
        'Un membre enfant approuvé doit avoir un childId.',
      );
    }

    if (role == FamilyJoinRole.parent && childId != null) {
      throw const FormatException(
        'Un membre parent ne doit pas avoir de childId.',
      );
    }

    return FamilyJoinStatusResult(
      familyId: familyId,
      status: status,
      role: role,
      childId: childId,
    );
  }
}

class PendingFamilyJoin {
  const PendingFamilyJoin({
    required this.familyId,
    required this.familyCode,
    required this.requestId,
    required this.requestedRole,
  });

  final String familyId;
  final String familyCode;
  final String requestId;
  final FamilyJoinRole requestedRole;

  Map<String, dynamic> toJson() {
    return {
      'familyId': familyId,
      'familyCode': familyCode,
      'requestId': requestId,
      'requestedRole': requestedRole.wireValue,
    };
  }

  factory PendingFamilyJoin.fromJson(Map<String, dynamic> map) {
    return PendingFamilyJoin(
      familyId: _requiredString(map, 'familyId'),
      familyCode: _requiredString(map, 'familyCode'),
      requestId: _requiredString(map, 'requestId'),
      requestedRole: FamilyJoinRole.fromWire(map['requestedRole']),
    );
  }
}

String _requiredString(Map<String, dynamic> map, String key) {
  final value = map[key];

  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key est absent ou invalide.');
  }

  return value.trim();
}
