import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';

// Handler arrière-plan — DOIT être top-level (hors de toute classe)
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
    // Handler pour les notifications en arrière-plan
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

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

      // Écouter les refresh de token
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

    // ===== Quand l'utilisateur tape sur la notification (app en arrière-plan) =====
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (kDebugMode) {
        debugPrint('Notification tapped: ${message.notification?.title}');
      }
    });

    // ===== Si l'app a été ouverte via une notification =====
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

  Future<void> _saveToken() async {
    try {
      final token = await _messaging.getToken();
      if (kDebugMode) debugPrint('FCM Token: $token');
      if (token != null) {
        await _saveTokenToFirestore(token);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('FCM getToken error: $e');
    }
  }

  Future<void> _saveTokenToFirestore(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final familyId = prefs.getString('family_id');
      final deviceId = prefs.getString('device_id');

      if (familyId == null || deviceId == null) return;

      await _db
          .collection('families')
          .doc(familyId)
          .collection('fcm_tokens')
          .doc(deviceId)
          .set({
        'token': token,
        'deviceId': deviceId,
        'platform': 'android',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) debugPrint('FCM token saved for device $deviceId');
    } catch (e) {
      if (kDebugMode) debugPrint('Save FCM token error: $e');
    }
  }
}
