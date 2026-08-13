import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum FirebaseAccountKind {
  temporary,
  durable,
}

class FirebaseAccountStatus {
  const FirebaseAccountStatus({
    required this.authenticated,
    required this.kind,
    required this.provider,
    required this.emailVerified,
    this.maskedEmail,
  });

  final bool authenticated;
  final FirebaseAccountKind kind;
  final String provider;
  final bool emailVerified;
  final String? maskedEmail;

  bool get isDurable => kind == FirebaseAccountKind.durable;

  @visibleForTesting
  static FirebaseAccountStatus fromValues({
    required bool authenticated,
    required bool anonymous,
    required Iterable<String> providerIds,
    required bool emailVerified,
    String? email,
  }) {
    final providers = providerIds.where((value) => value.isNotEmpty).toSet();
    final durable = authenticated &&
        !anonymous &&
        providers.any((provider) => provider != 'anonymous');
    final provider = providers.contains('password')
        ? 'email-password'
        : durable
            ? 'durable'
            : 'anonymous';

    return FirebaseAccountStatus(
      authenticated: authenticated,
      kind:
          durable ? FirebaseAccountKind.durable : FirebaseAccountKind.temporary,
      provider: provider,
      emailVerified: durable && emailVerified,
      maskedEmail: maskEmail(email),
    );
  }

  @visibleForTesting
  static String? maskEmail(String? value) {
    final email = value?.trim();
    if (email == null || email.isEmpty || !email.contains('@')) return null;
    final parts = email.split('@');
    if (parts.length != 2 || parts.first.isEmpty || parts.last.isEmpty) {
      return null;
    }
    final local = parts.first;
    final visible = local.length <= 2 ? local.substring(0, 1) : local[0];
    return '$visible***@${parts.last}';
  }
}

class DurableAuthException implements Exception {
  const DurableAuthException({
    required this.code,
    required this.message,
  });

  final String code;
  final String message;

  @override
  String toString() => message;
}

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;
  bool get isConnected => currentUser != null;
  String? get uid => currentUser?.uid;
  Stream<User?> get authState => _auth.authStateChanges();

  FirebaseAccountStatus get accountStatus {
    final user = currentUser;
    return FirebaseAccountStatus.fromValues(
      authenticated: user != null,
      anonymous: user?.isAnonymous ?? true,
      providerIds:
          user?.providerData.map((item) => item.providerId) ?? const <String>[],
      emailVerified: user?.emailVerified ?? false,
      email: user?.email,
    );
  }

  @visibleForTesting
  static bool canCreateAnonymousAccount({
    required bool hasCurrentUser,
    required bool hasLinkedFamily,
  }) {
    return !hasCurrentUser && !hasLinkedFamily;
  }

  Future<void> ensureConnected() async {
    if (currentUser != null) {
      if (kDebugMode) {
        debugPrint('AuthService: session Firebase disponible.');
      }
      return;
    }
    final preferences = await SharedPreferences.getInstance();
    final linkedFamilyId = preferences.getString('family_id');
    if (!canCreateAnonymousAccount(
      hasCurrentUser: false,
      hasLinkedFamily: linkedFamilyId != null && linkedFamilyId.isNotEmpty,
    )) {
      throw const DurableAuthException(
        code: 'controlled-reconnection-required',
        message:
            'Votre session doit être actualisée. Vos données locales sont conservées.',
      );
    }
    try {
      await _auth.signInAnonymously();
      if (kDebugMode) {
        debugPrint('AuthService: compte temporaire Firebase créé.');
      }
    } on FirebaseAuthException catch (error) {
      throw _mapError(error);
    }
  }

  Future<void> secureTemporaryAccount({
    required String email,
    required String password,
  }) async {
    final user = currentUser;
    if (user == null || !user.isAnonymous) {
      throw const DurableAuthException(
        code: 'not-anonymous',
        message: 'Le compte actuel n’est pas un compte temporaire.',
      );
    }

    final credential = EmailAuthProvider.credential(
      email: _normalizeEmail(email),
      password: _validatePassword(password),
    );
    try {
      final result = await user.linkWithCredential(credential);
      await result.user?.sendEmailVerification();
    } on FirebaseAuthException catch (error) {
      // Un compte déjà existant n’est jamais fusionné automatiquement.
      if (error.code == 'credential-already-in-use' ||
          error.code == 'email-already-in-use') {
        throw const DurableAuthException(
          code: 'credential-already-in-use',
          message: 'Cette adresse est déjà liée à un autre compte. '
              'Aucune fusion automatique n’a été effectuée.',
        );
      }
      throw _mapError(error);
    }
  }

  Future<void> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: _normalizeEmail(email),
        password: _validatePassword(password),
      );
    } on FirebaseAuthException catch (error) {
      throw _mapError(error);
    }
  }

  Future<void> reauthenticateWithPassword({
    required String password,
  }) async {
    final user = currentUser;
    final email = user?.email;
    if (user == null || email == null || user.isAnonymous) {
      throw const DurableAuthException(
        code: 'durable-account-required',
        message: 'Un compte durable est requis.',
      );
    }
    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(
          email: email,
          password: _validatePassword(password),
        ),
      );
      // Force un nouveau jeton : le serveur peut alors vérifier auth_time.
      await user.getIdToken(true);
    } on FirebaseAuthException catch (error) {
      throw _mapError(error);
    }
  }

  Future<FirebaseAccountStatus> refreshAccountStatus() async {
    await currentUser?.reload();
    return accountStatus;
  }

  Future<void> sendVerificationEmail() async {
    final user = currentUser;
    if (user == null || user.isAnonymous || user.emailVerified) {
      throw const DurableAuthException(
        code: 'verification-not-required',
        message: 'Aucune vérification d’adresse n’est nécessaire.',
      );
    }
    try {
      await user.sendEmailVerification();
    } on FirebaseAuthException catch (error) {
      throw _mapError(error);
    }
  }

  static String _normalizeEmail(String value) {
    final email = value.trim().toLowerCase();
    if (email.length > 254 ||
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      throw const DurableAuthException(
        code: 'invalid-email',
        message: 'L’adresse email est invalide.',
      );
    }
    return email;
  }

  static String _validatePassword(String value) {
    if (value.length < 10 || value.length > 128) {
      throw const DurableAuthException(
        code: 'weak-password',
        message: 'Le mot de passe doit contenir au moins 10 caractères.',
      );
    }
    return value;
  }

  static DurableAuthException _mapError(FirebaseAuthException error) {
    final message = switch (error.code) {
      'wrong-password' ||
      'invalid-credential' =>
        'Adresse ou mot de passe incorrect.',
      'user-not-found' => 'Aucun compte ne correspond à cette adresse.',
      'too-many-requests' =>
        'Trop de tentatives. Réessayez dans quelques minutes.',
      'network-request-failed' => 'Connexion indisponible. Vérifiez le réseau.',
      'requires-recent-login' =>
        'Reconnectez-vous récemment pour cette opération.',
      'operation-not-allowed' =>
        'La connexion email n’est pas encore activée sur le serveur.',
      _ => 'L’authentification Firebase a échoué (${error.code}).',
    };
    return DurableAuthException(code: error.code, message: message);
  }
}
