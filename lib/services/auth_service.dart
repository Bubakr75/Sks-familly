// lib/services/auth_service.dart
//
// Service d'authentification Firebase (anonyme) pour SKS Family.
//
// Comme l'app repose sur un "code famille" (pas de comptes email/mot de passe
// individuels), on utilise l'authentification ANONYME :
//   - Chaque appareil se connecte automatiquement à Firebase au démarrage
//   - Ça crée un utilisateur anonyme unique par appareil
//   - Ça protège Firestore : seuls les utilisateurs authentifiés peuvent lire/écrire
//   - Le code famille reste le système de "salle" (qui voit quelle famille)
//
// Avant : Firestore était ouvert (allow if true) → n'importe qui sur internet
//         pouvait lire/modifier les données.
// Maintenant : Firestore exige une authentification → protégé des attaques externes.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// L'utilisateur actuellement connecté (null si pas encore connecté).
  User? get currentUser => _auth.currentUser;

  /// True si un utilisateur est connecté.
  bool get isConnected => _auth.currentUser != null;

  /// L'UID Firebase de l'utilisateur (utilisable comme identifiant stable).
  String? get uid => _auth.currentUser?.uid;

  /// Initialise la connexion : connecte anonymement si pas déjà connecté.
  ///
  /// Doit être appelée APRES Firebase.initializeApp() et AVANT d'utiliser
  /// Firestore (car les règles exigeront request.auth != null).
  Future<void> ensureConnected() async {
    try {
      if (_auth.currentUser != null) {
        if (kDebugMode) {
          debugPrint('AuthService: déjà connecté (uid=${_auth.currentUser?.uid})');
        }
        return;
      }
      final cred = await _auth.signInAnonymously();
      if (kDebugMode) {
        debugPrint('AuthService: connecté anonymement (uid=${cred.user?.uid})');
      }
    } on FirebaseAuthException catch (e) {
      // L'auth anonyme doit être activée dans la console Firebase :
      // Console → Authentication → Sign-in method → Anonymous → Activer
      if (kDebugMode) {
        debugPrint('AuthService erreur (${e.code}): ${e.message}');
        debugPrint('→ Active l\'authentification anonyme dans la console Firebase:');
        debugPrint('  Console → Authentication → Sign-in method → Anonymous → Enable');
      }
      rethrow;
    } catch (e) {
      if (kDebugMode) debugPrint('AuthService erreur inattendue: $e');
      rethrow;
    }
  }

  /// Stream de l'état d'authentification (pour réagir aux changements).
  Stream<User?> get authState => _auth.authStateChanges();
}
