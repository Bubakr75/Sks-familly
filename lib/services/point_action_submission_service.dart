import 'package:cloud_functions/cloud_functions.dart';

class PointActionDraft {
  const PointActionDraft({
    required this.actionId,
    required this.childId,
    required this.amount,
    required this.reason,
    required this.category,
    required this.isBonus,
    required this.hasPhoto,
    this.penaltyLinesCount,
    this.penaltyLinesInstruction,
    this.onVerifying,
  });

  final String actionId;
  final String childId;
  final int amount;
  final String reason;
  final String category;
  final bool isBonus;
  final bool hasPhoto;
  final int? penaltyLinesCount;
  final String? penaltyLinesInstruction;
  final void Function()? onVerifying;

  bool get hasPenaltyLines =>
      !isBonus && penaltyLinesCount != null && penaltyLinesCount! > 0;
}

class PointActionRemoteException implements Exception {
  const PointActionRemoteException({
    required this.code,
    this.message,
  });

  final String code;
  final String? message;
}

class PointActionSubmissionResult {
  const PointActionSubmissionResult._({
    required this.success,
    required this.duplicateIgnored,
    required this.retryStateUncertain,
    required this.functionUnavailable,
    required this.photoStoragePath,
    this.appliedAmount,
    this.errorMessage,
  });

  factory PointActionSubmissionResult.completed({
    required int appliedAmount,
    required String? photoStoragePath,
  }) {
    return PointActionSubmissionResult._(
      success: true,
      duplicateIgnored: false,
      retryStateUncertain: false,
      functionUnavailable: false,
      photoStoragePath: photoStoragePath,
      appliedAmount: appliedAmount,
    );
  }

  factory PointActionSubmissionResult.failed({
    required String message,
    required bool retryStateUncertain,
    required bool functionUnavailable,
    required String? photoStoragePath,
  }) {
    return PointActionSubmissionResult._(
      success: false,
      duplicateIgnored: false,
      retryStateUncertain: retryStateUncertain,
      functionUnavailable: functionUnavailable,
      photoStoragePath: photoStoragePath,
      errorMessage: message,
    );
  }

  factory PointActionSubmissionResult.duplicate() {
    return const PointActionSubmissionResult._(
      success: false,
      duplicateIgnored: true,
      retryStateUncertain: false,
      functionUnavailable: false,
      photoStoragePath: null,
    );
  }

  final bool success;
  final bool duplicateIgnored;
  final bool retryStateUncertain;
  final bool functionUnavailable;
  final String? photoStoragePath;
  final int? appliedAmount;
  final String? errorMessage;
}

class PointActionFailure {
  const PointActionFailure({
    required this.message,
    required this.stateUncertain,
    required this.functionUnavailable,
  });

  final String message;
  final bool stateUncertain;
  final bool functionUnavailable;
}

PointActionFailure describePointActionFailure(Object error) {
  String? code;
  String? serverMessage;
  if (error is FirebaseFunctionsException) {
    code = error.code;
    serverMessage = error.message;
  } else if (error is PointActionRemoteException) {
    code = error.code;
    serverMessage = error.message;
  }
  final normalizedCode = (code ?? '').toLowerCase();
  final normalizedMessage = (serverMessage ?? '').trim();
  final lowerMessage = normalizedMessage.toLowerCase();
  final compactMessage = lowerMessage.replaceAll('_', ' ');

  if (['unimplemented', 'functions/not-found'].contains(normalizedCode) ||
      (normalizedCode == 'not-found' &&
          (normalizedMessage.isEmpty ||
              compactMessage == 'not found' ||
              lowerMessage.contains('function')))) {
    return const PointActionFailure(
      message: 'La fonction sécurisée recordPointAction n’est pas encore '
          'disponible sur le serveur. Aucune action n’a été enregistrée.',
      stateUncertain: false,
      functionUnavailable: true,
    );
  }
  if (normalizedCode == 'unauthenticated') {
    return const PointActionFailure(
      message: 'Votre session Firebase a expiré. Reconnectez-vous puis '
          'réessayez.',
      stateUncertain: false,
      functionUnavailable: false,
    );
  }
  if (normalizedCode == 'permission-denied') {
    return const PointActionFailure(
      message: 'Votre compte n’est pas autorisé à modifier les points de '
          'cette famille.',
      stateUncertain: false,
      functionUnavailable: false,
    );
  }
  if (normalizedCode == 'failed-precondition') {
    return PointActionFailure(
      message: normalizedMessage.isNotEmpty
          ? normalizedMessage
          : 'Cette action ne peut pas être appliquée dans l’état actuel.',
      stateUncertain: false,
      functionUnavailable: false,
    );
  }
  if (normalizedCode == 'invalid-argument' ||
      normalizedCode == 'already-exists') {
    return const PointActionFailure(
      message: 'Les informations de l’action ne sont plus valides. '
          'Vérifiez l’enfant, le motif et le montant.',
      stateUncertain: false,
      functionUnavailable: false,
    );
  }
  if (normalizedCode == 'not-found' && normalizedMessage.isNotEmpty) {
    return PointActionFailure(
      message: normalizedMessage,
      stateUncertain: false,
      functionUnavailable: false,
    );
  }
  if ([
    'unavailable',
    'deadline-exceeded',
    'internal',
    'unknown',
    'cancelled',
  ].contains(normalizedCode)) {
    return const PointActionFailure(
      message: 'Vérification de l’enregistrement en attente. Votre saisie est '
          'conservée et la vérification reprendra automatiquement.',
      stateUncertain: true,
      functionUnavailable: false,
    );
  }
  if (error is StateError && error.message.toString().contains('Connexion')) {
    return const PointActionFailure(
      message: 'La famille n’est pas connectée. Reprenez la synchronisation '
          'puis réessayez.',
      stateUncertain: false,
      functionUnavailable: false,
    );
  }
  return const PointActionFailure(
    message: 'Impossible d’enregistrer cette action. La saisie est conservée '
        'et vous pouvez réessayer.',
    stateUncertain: false,
    functionUnavailable: false,
  );
}

class PointActionSubmissionCoordinator {
  bool _busy = false;

  bool get isBusy => _busy;

  Future<PointActionSubmissionResult> submit({
    required PointActionDraft draft,
    required String? existingPhotoStoragePath,
    required Future<String> Function() uploadPhoto,
    required Future<void> Function(String path) deletePhoto,
    required Future<int> Function(String? photoStoragePath) recordAction,
  }) async {
    if (_busy) return PointActionSubmissionResult.duplicate();
    _busy = true;
    var photoPath = existingPhotoStoragePath;
    var recordStarted = false;
    try {
      if (draft.hasPhoto && photoPath == null) {
        photoPath = await uploadPhoto();
      }
      recordStarted = true;
      final appliedAmount = await recordAction(photoPath);
      if (appliedAmount < 1) {
        throw const PointActionRemoteException(
          code: 'failed-precondition',
          message: 'Aucun point n’a été appliqué.',
        );
      }
      return PointActionSubmissionResult.completed(
        appliedAmount: appliedAmount,
        photoStoragePath: photoPath,
      );
    } catch (error) {
      final failure = describePointActionFailure(error);
      final keepForIdempotentRetry = recordStarted && failure.stateUncertain;
      if (photoPath != null && !keepForIdempotentRetry) {
        try {
          await deletePhoto(photoPath);
        } catch (_) {
          // Le même chemin sera réutilisé ou remplacé au prochain essai.
        }
        photoPath = null;
      }
      return PointActionSubmissionResult.failed(
        message: failure.message,
        retryStateUncertain: keepForIdempotentRetry,
        functionUnavailable: failure.functionUnavailable,
        photoStoragePath: photoPath,
      );
    } finally {
      _busy = false;
    }
  }
}
