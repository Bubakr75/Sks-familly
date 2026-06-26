import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';

// Handler arriÃ¨re-plan â€” DOIT Ãªtre top-level (hors de toute classe)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) debugPrint('BG message: ${message.notification?.title}');
}

class FcmService {
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> init() async {
    // Handler pour les notifications en arriÃ¨re-plan
    // Sur web, le background est gere par le service worker (firebase-messaging-sw.js)
    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    }

    // Demander la permission notifications
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      criticalAlert: false,
      announcement: false,
      carPlay: false,
      provisional: false,
    );

    if (kDebugMode) {
      debugPrint('FCM permission: ${settings.authorizationStatus}');
    }

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      // Sauvegarder le token
      await _saveToken();

      // Ã‰couter les refresh de token
      _messaging.onTokenRefresh.listen((newToken) {
        _saveTokenToFirestore(newToken);
      });
    }

    // ===== Notifications quand l'app est OUVERTE (premier plan) =====
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) {
        debugPrint('FG message: ${message.notification?.title}');
      }

      final notification = message.notification;
      if (notification == null) return;

      // Afficher la notification locale + overlay dans l'app
      final type = _getNotificationType(message.data['type'] ?? '');
      NotificationService.show(
        title: notification.title ?? 'SKS Family',
        message: notification.body ?? '',
        type: type,
      );
    });

    // ===== Quand l'utilisateur tape sur la notification (app en arriÃ¨re-plan) =====
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (kDebugMode) {
        debugPrint('Notification tapped: ${message.notification?.title}');
      }
    });

    // ===== Si l'app a Ã©tÃ© ouverte via une notification =====
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null && kDebugMode) {
      debugPrint('App opened from notification: ${initialMessage.notification?.title}');
    }
  }

  // Convertir le type string en NotificationType
  NotificationType _getNotificationType(String type) {
    switch (type) {
      case 'points':
      case 'history':
        return NotificationType.bonus;
      case 'badge':
        return NotificationType.badge;
      case 'punishment':
      case 'punishment_progress':
      case 'punishment_done':
        return NotificationType.punishment;
      case 'immunity':
        return NotificationType.progress;
      case 'trade_new':
      case 'trade_update':
        return NotificationType.goal;
      case 'tribunal_new':
      case 'tribunal_update':
        return NotificationType.penalty;
      case 'school_note':
        return NotificationType.bonus;
      case 'screen_time':
      case 'saturday_rating':
        return NotificationType.screenTime;
      default:
        return NotificationType.sync;
    }
  }

  // Point d'entree public : a appeler quand family_id devient disponible
  Future<void> registerToken() async {
    try {
      await FirebaseFirestore.instance.collection('debug_logs').add({
        'step': 'registerToken appele',
        'platform': kIsWeb ? 'web' : 'android',
        'at': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
    print('SKS: registerToken appele platform=' + (kIsWeb ? 'web' : 'android'));
    await _saveToken();
  }

  Future<void> _saveToken() async {
    try {
      final token = kIsWeb
          ? await _messaging.getToken(vapidKey: 'BPlYsfIrUVb_LRNt8q1acG2bufeaL4SOvv1KM0Cdkpx16X3cpQm9-16o5Z_QY5lWAoWf_bh04LtrfCO5n4u8Tlo')
          : await _messaging.getToken();
      print('SKS: FCM Token = ' + token.toString());
      if (token != null) {
        print('SKS: ECRITURE DIRECTE en cours');
        try {
          final prefs = await SharedPreferences.getInstance();
          var deviceId = prefs.getString('device_id');
          deviceId ??= DateTime.now().millisecondsSinceEpoch.toString();
          await _db.collection('families').doc('HFnzg4vyT6YFU5RsVXsy').collection('fcm_tokens').doc(deviceId).set({
            'token': token,
            'deviceId': deviceId,
            'platform': kIsWeb ? 'web' : 'android',
            'updatedAt': FieldValue.serverTimestamp(),
          });
          print('SKS: ECRITURE DIRECTE REUSSIE deviceId=' + deviceId);
        } catch (err) {
          print('SKS: ECRITURE DIRECTE ERREUR = ' + err.toString());
        }
        await _saveTokenToFirestore(token);
      }
    } catch (e) {
      print('SKS: getToken ERREUR = ' + e.toString());
      try {
        await FirebaseFirestore.instance.collection('debug_logs').add({
          'error': e.toString(),
          'platform': kIsWeb ? 'web' : 'android',
          'at': FieldValue.serverTimestamp(),
        });
      } catch (_) {}
    }
  }

  Future<void> _saveTokenToFirestore(String token) async {
    print('SKS: _saveTokenToFirestore ATTEINTE');
    try {
      final prefs = await SharedPreferences.getInstance();
      final familyId = prefs.getString('family_id');
      final deviceId = prefs.getString('device_id');

      if (familyId == null || deviceId == null) { print('SKS: STOP familyId=' + familyId.toString() + ' deviceId=' + deviceId.toString()); return; }

      print('SKS: ECRITURE vers familyId=' + familyId + ' deviceId=' + deviceId);
      await _db
          .collection('families')
          .doc(familyId)
          .collection('fcm_tokens')
          .doc(deviceId)
          .set({
        'token': token,
        'deviceId': deviceId,
        'platform': kIsWeb ? 'web' : 'android',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('SKS: TOKEN ENREGISTRE OK pour ' + deviceId);
    } catch (e) {
      print('SKS: ECRITURE ERREUR = ' + e.toString());
    }
  }
}















