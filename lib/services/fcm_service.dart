import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/vapid_key.dart';
import 'notification_service.dart';

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

  String get _platformName {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android: return 'android';
      case TargetPlatform.iOS: return 'ios';
      case TargetPlatform.macOS: return 'macos';
      case TargetPlatform.windows: return 'windows';
      case TargetPlatform.linux: return 'linux';
      case TargetPlatform.fuchsia: return 'fuchsia';
    }
  }

  Future<void> init() async {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    final settings = await _messaging.requestPermission(
      alert: true, badge: true, sound: true,
      criticalAlert: false, announcement: false,
      carPlay: false, provisional: false,
    );

    if (kDebugMode) {
      debugPrint('FCM permission: ${settings.authorizationStatus}');
      debugPrint('FCM platform: $_platformName');
      debugPrint('FCM VAPID configured: ${VapidKeyConfig.isConfigured}');
    }

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      await _saveToken();
      _messaging.onTokenRefresh.listen((newToken) {
        _saveTokenToFirestore(newToken);
      });
    } else {
      if (kDebugMode) {
        debugPrint('FCM: Permission refusee sur $_platformName.');
      }
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) debugPrint('FG message: ${message.notification?.title}');
      final notification = message.notification;
      if (notification == null) return;
      final type = _getNotificationType(message.data['type'] ?? '');
      NotificationService.show(
        title: notification.title ?? 'SKS Family',
        message: notification.body ?? '',
        type: type,
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (kDebugMode) debugPrint('Notification tapped: ${message.notification?.title}');
    });

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null && kDebugMode) {
      debugPrint('App opened from notification: ${initialMessage.notification?.title}');
    }
  }

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

  Future<void> registerToken() async {
    await _saveToken();
  }

  Future<void> _saveToken() async {
    try {
      String? token;
      if (kIsWeb) {
        if (!VapidKeyConfig.isConfigured) {
          if (kDebugMode) {
            debugPrint('FCM WEB: VAPID key non configuree !');
          }
          return;
        }
        token = await _messaging.getToken(vapidKey: VapidKeyConfig.vapidKey);
      } else {
        token = await _messaging.getToken();
      }

      if (kDebugMode) debugPrint('FCM Token ($_platformName): $token');
      if (token != null) {
        await _saveTokenToFirestore(token);
      } else {
        if (kDebugMode) {
          debugPrint('FCM: getToken() null sur $_platformName.');
        }
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
        'platform': _platformName,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) debugPrint('FCM token saved for $deviceId ($_platformName)');
    } catch (e) {
      if (kDebugMode) debugPrint('Save FCM token error: $e');
    }
  }
}
