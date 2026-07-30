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
  sending,
  sent,
  received,
  accepted,
  refused,
  expired,
  error,
  pending,
  approved,
  rejected;

  String get wireValue => name;

  static FamilyJoinStatus fromWire(Object? value) {
    return switch (value) {
      'pending' => FamilyJoinStatus.pending,
      'approved' => FamilyJoinStatus.approved,
      'rejected' => FamilyJoinStatus.rejected,
      'sending' => FamilyJoinStatus.sending,
      'sent' => FamilyJoinStatus.sent,
      'received' => FamilyJoinStatus.received,
      'accepted' => FamilyJoinStatus.accepted,
      'refused' => FamilyJoinStatus.refused,
      'expired' => FamilyJoinStatus.expired,
      'error' => FamilyJoinStatus.error,
      _ => throw const FormatException('Statut de connexion invalide.'),
    };
  }
}

enum FamilyJoinActivationState {
  approvalPending,
  memberMissing,
  memberInactive,
  memberUidMismatch,
  memberRoleMismatch,
  memberChildMismatch,
  requestInvalid,
  ready;

  static FamilyJoinActivationState fromWire(Object? value) {
    return switch (value) {
      'approval-pending' => FamilyJoinActivationState.approvalPending,
      'member-missing' => FamilyJoinActivationState.memberMissing,
      'member-inactive' => FamilyJoinActivationState.memberInactive,
      'member-uid-mismatch' => FamilyJoinActivationState.memberUidMismatch,
      'member-role-mismatch' => FamilyJoinActivationState.memberRoleMismatch,
      'member-child-mismatch' => FamilyJoinActivationState.memberChildMismatch,
      'request-invalid' => FamilyJoinActivationState.requestInvalid,
      'ready' => FamilyJoinActivationState.ready,
      _ => throw const FormatException(
          'État de finalisation du rattachement invalide.',
        ),
    };
  }
}

class FamilyJoinRequestResult {
  const FamilyJoinRequestResult({
    required this.familyId,
    required this.requestId,
    required this.status,
    required this.alreadyPending,
    required this.requestedRole,
  });

  final String familyId;
  final String requestId;
  final FamilyJoinStatus status;
  final bool alreadyPending;
  final FamilyJoinRole requestedRole;

  factory FamilyJoinRequestResult.fromMap(
    Map<String, dynamic> map, {
    FamilyJoinRole fallbackRequestedRole = FamilyJoinRole.parent,
  }) {
    final familyId = _requiredString(map, 'familyId');
    final requestId = _requiredString(map, 'requestId');
    final status = FamilyJoinStatus.fromWire(map['status']);
    final alreadyPending = map['alreadyPending'];
    final requestedRole = map['requestedRole'] == null
        ? fallbackRequestedRole
        : FamilyJoinRole.fromWire(map['requestedRole']);

    if (status != FamilyJoinStatus.pending &&
        status != FamilyJoinStatus.sent &&
        status != FamilyJoinStatus.received) {
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
      requestedRole: requestedRole,
    );
  }
}

class FamilyJoinStatusResult {
  const FamilyJoinStatusResult({
    required this.familyId,
    required this.status,
    this.activationState = FamilyJoinActivationState.ready,
    this.memberReady = true,
    this.role,
    this.childId,
  });

  final String familyId;
  final FamilyJoinStatus status;
  final FamilyJoinActivationState activationState;
  final bool memberReady;
  final FamilyJoinRole? role;
  final String? childId;

  bool get isApproved =>
      status == FamilyJoinStatus.approved ||
      status == FamilyJoinStatus.accepted;
  bool get isRejected =>
      status == FamilyJoinStatus.rejected || status == FamilyJoinStatus.refused;
  bool get isPending =>
      status == FamilyJoinStatus.pending ||
      status == FamilyJoinStatus.sending ||
      status == FamilyJoinStatus.sent ||
      status == FamilyJoinStatus.received;
  bool get canActivate =>
      isApproved &&
      memberReady &&
      activationState == FamilyJoinActivationState.ready;
  bool get canRetryFinalization =>
      isApproved &&
      (activationState == FamilyJoinActivationState.memberMissing ||
          activationState == FamilyJoinActivationState.memberRoleMismatch ||
          activationState == FamilyJoinActivationState.memberChildMismatch);

  factory FamilyJoinStatusResult.fromMap(Map<String, dynamic> map) {
    final familyId = _requiredString(map, 'familyId');
    final status = FamilyJoinStatus.fromWire(map['status']);
    final approvedStatus = status == FamilyJoinStatus.approved ||
        status == FamilyJoinStatus.accepted;
    final activationState = FamilyJoinActivationState.fromWire(
      map['activationState'] ?? (approvedStatus ? 'ready' : 'approval-pending'),
    );
    final rawMemberReady = map['memberReady'];
    final memberReady = rawMemberReady is bool
        ? rawMemberReady
        : activationState == FamilyJoinActivationState.ready;

    final rawRole = map['role'];
    final role = rawRole == null ? null : FamilyJoinRole.fromWire(rawRole);

    final rawChildId = map['childId'];
    final childId = rawChildId == null ? null : _requiredString(map, 'childId');

    if (approvedStatus && memberReady && role == null) {
      throw const FormatException(
        'Une approbation finalisée sans membre actif est invalide.',
      );
    }

    if ((!approvedStatus || !memberReady) &&
        (role != null || childId != null)) {
      throw const FormatException(
        'Une demande non finalisée ne doit pas activer de membre.',
      );
    }

    if (memberReady != (activationState == FamilyJoinActivationState.ready)) {
      throw const FormatException(
        'L’état du membre et la finalisation sont incohérents.',
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
      activationState: activationState,
      memberReady: memberReady,
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
