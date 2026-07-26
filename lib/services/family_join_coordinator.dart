import 'package:flutter/foundation.dart';

import '../models/family_join_request.dart';
import 'family_join_service.dart';
import 'firestore_service.dart';

typedef ApprovedFamilyActivator = Future<void> Function({
  required String familyId,
  required String familyCode,
  required String role,
  String? childId,
});

typedef PendingFamilyJoinClearer = Future<void> Function();

class FamilyJoinCoordinator {
  FamilyJoinCoordinator({
    FamilyJoinService? joinService,
    FirestoreService? firestoreService,
  })  : _joinService = joinService ?? FamilyJoinService(),
        _firestoreService = firestoreService ?? FirestoreService();

  final FamilyJoinService _joinService;
  final FirestoreService _firestoreService;

  /// Vérifie la demande locale actuellement en attente.
  ///
  /// - Retourne null lorsqu'aucune demande locale n'existe.
  /// - Ne modifie rien pour un statut pending ou rejected.
  /// - Active la famille pour un statut approved.
  /// - Supprime la demande locale uniquement après l'activation complète.
  Future<FamilyJoinStatusResult?> checkAndActivatePendingRequest() async {
    final pending = await _joinService.loadPendingRequest();

    if (pending == null) {
      return null;
    }

    final status = await _joinService.getFamilyJoinStatus(
      familyId: pending.familyId,
    );

    await applyStatus(
      pending: pending,
      status: status,
      activateApprovedFamily: _firestoreService.activateApprovedFamily,
      clearPendingRequest: _joinService.clearPendingRequest,
    );

    return status;
  }

  @visibleForTesting
  static Future<void> applyStatus({
    required PendingFamilyJoin pending,
    required FamilyJoinStatusResult status,
    required ApprovedFamilyActivator activateApprovedFamily,
    required PendingFamilyJoinClearer clearPendingRequest,
  }) async {
    if (status.familyId != pending.familyId) {
      throw const FamilyJoinException(
        code: 'invalid-response',
        message: 'La réponse concerne une autre famille.',
      );
    }

    if (!status.isApproved) {
      // La demande reste disponible localement pour que l'interface puisse
      // afficher pending ou rejected et laisser l'utilisateur décider.
      return;
    }

    final approvedRole = status.role;

    if (approvedRole == null) {
      throw const FamilyJoinException(
        code: 'invalid-response',
        message: 'L’approbation ne contient aucun rôle actif.',
      );
    }

    if (approvedRole != pending.requestedRole) {
      throw const FamilyJoinException(
        code: 'invalid-response',
        message: 'Le rôle approuvé ne correspond pas au rôle demandé.',
      );
    }

    await activateApprovedFamily(
      familyId: pending.familyId,
      familyCode: pending.familyCode,
      role: approvedRole.wireValue,
      childId: status.childId,
    );

    // Cette suppression doit impérativement rester après l'activation.
    await clearPendingRequest();
  }
}
