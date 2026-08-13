import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

enum FirebaseSessionState {
  noUser,
  authenticated,
  refreshing,
  expiredOrRevoked,
  networkUnavailable,
  reconnectionRequired,
}

class FirebaseSessionSnapshot {
  const FirebaseSessionSnapshot(this.state, {this.uid});

  final FirebaseSessionState state;
  final String? uid;

  bool get canCallServer => state == FirebaseSessionState.authenticated;
}

class FirebaseSessionException implements Exception {
  const FirebaseSessionException(this.state, {this.technicalCode});

  final FirebaseSessionState state;
  final String? technicalCode;

  String get userMessage => switch (state) {
        FirebaseSessionState.noUser ||
        FirebaseSessionState.expiredOrRevoked ||
        FirebaseSessionState.reconnectionRequired =>
          'Votre session doit être actualisée. Vos données locales sont conservées.',
        FirebaseSessionState.networkUnavailable =>
          'Connexion indisponible. Vos données locales sont conservées.',
        FirebaseSessionState.refreshing => 'Connexion en cours…',
        FirebaseSessionState.authenticated => '',
      };

  @override
  String toString() => userMessage;
}

/// Renouvelle une session existante sans déconnexion et sans création de compte.
class FirebaseSessionService extends ChangeNotifier {
  FirebaseSessionService._();

  static final FirebaseSessionService instance = FirebaseSessionService._();

  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseSessionSnapshot _snapshot =
      const FirebaseSessionSnapshot(FirebaseSessionState.noUser);
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<User?>? _tokenSubscription;
  Timer? _subscriptionTimer;
  Future<FirebaseSessionSnapshot>? _refreshInFlight;
  int _observationGeneration = 0;

  FirebaseSessionSnapshot get snapshot => _snapshot;

  Future<FirebaseSessionSnapshot> inspect({bool forceRefresh = false}) async {
    final user = _auth.currentUser;
    if (user == null) {
      return _set(const FirebaseSessionSnapshot(FirebaseSessionState.noUser));
    }
    if (!forceRefresh) {
      try {
        final token = await user.getIdTokenResult(false);
        final expiration = token.expirationTime;
        if (expiration == null || expiration.isAfter(DateTime.now())) {
          return _set(FirebaseSessionSnapshot(
            FirebaseSessionState.authenticated,
            uid: user.uid,
          ));
        }
      } on FirebaseAuthException catch (error) {
        return _set(_fromAuthError(error, user.uid));
      }
    }
    return refreshExistingSession();
  }

  Future<FirebaseSessionSnapshot> refreshExistingSession() {
    return _refreshInFlight ??= _refresh().whenComplete(() {
      _refreshInFlight = null;
    });
  }

  Future<FirebaseSessionSnapshot> _refresh() async {
    final user = _auth.currentUser;
    if (user == null) {
      return _set(const FirebaseSessionSnapshot(FirebaseSessionState.noUser));
    }
    final originalUid = user.uid;
    _set(FirebaseSessionSnapshot(
      FirebaseSessionState.refreshing,
      uid: originalUid,
    ));
    try {
      await user.getIdToken(true);
      final current = _auth.currentUser;
      if (current == null || current.uid != originalUid) {
        return _set(FirebaseSessionSnapshot(
          FirebaseSessionState.reconnectionRequired,
          uid: originalUid,
        ));
      }
      return _set(FirebaseSessionSnapshot(
        FirebaseSessionState.authenticated,
        uid: originalUid,
      ));
    } on FirebaseAuthException catch (error) {
      return _set(_fromAuthError(error, originalUid));
    } catch (_) {
      return _set(FirebaseSessionSnapshot(
        FirebaseSessionState.reconnectionRequired,
        uid: originalUid,
      ));
    }
  }

  /// Écoute les changements pendant une durée bornée, puis annule les flux.
  Future<void> observeTemporarily({
    Duration duration = const Duration(minutes: 2),
  }) async {
    final generation = ++_observationGeneration;
    await _cancelSubscriptions();
    if (generation != _observationGeneration) return;
    _authSubscription = _auth.authStateChanges().listen(_handleUserChange);
    _tokenSubscription = _auth.idTokenChanges().listen(_handleUserChange);
    _subscriptionTimer = Timer(duration, () => unawaited(stopObserving()));
  }

  void _handleUserChange(User? user) {
    if (user == null) {
      _set(const FirebaseSessionSnapshot(FirebaseSessionState.noUser));
    } else {
      unawaited(inspect());
    }
  }

  Future<void> stopObserving() async {
    _observationGeneration++;
    await _cancelSubscriptions();
  }

  Future<void> _cancelSubscriptions() async {
    _subscriptionTimer?.cancel();
    _subscriptionTimer = null;
    final authSubscription = _authSubscription;
    final tokenSubscription = _tokenSubscription;
    _authSubscription = null;
    _tokenSubscription = null;
    await authSubscription?.cancel();
    await tokenSubscription?.cancel();
  }

  FirebaseSessionSnapshot _set(FirebaseSessionSnapshot next) {
    if (_snapshot.state != next.state || _snapshot.uid != next.uid) {
      _snapshot = next;
      notifyListeners();
    }
    return next;
  }

  static FirebaseSessionSnapshot _fromAuthError(
    FirebaseAuthException error,
    String uid,
  ) {
    if (error.code == 'network-request-failed') {
      return FirebaseSessionSnapshot(
        FirebaseSessionState.networkUnavailable,
        uid: uid,
      );
    }
    if ({'user-disabled', 'user-token-expired', 'invalid-user-token'}
        .contains(error.code)) {
      return FirebaseSessionSnapshot(
        FirebaseSessionState.expiredOrRevoked,
        uid: uid,
      );
    }
    return FirebaseSessionSnapshot(
      FirebaseSessionState.reconnectionRequired,
      uid: uid,
    );
  }
}

/// Exécute au plus un renouvellement et un seul nouvel appel avec la même charge.
Future<T> callWithSingleAuthRetry<T>({
  required Future<T> Function() call,
  required Future<FirebaseSessionSnapshot> Function() refreshSession,
  required bool Function(Object error) isUnauthenticated,
}) async {
  try {
    return await call();
  } catch (error) {
    if (!isUnauthenticated(error)) rethrow;
    final refreshed = await refreshSession();
    if (!refreshed.canCallServer) {
      throw FirebaseSessionException(
        refreshed.state,
        technicalCode: 'unauthenticated',
      );
    }
    return call();
  }
}
