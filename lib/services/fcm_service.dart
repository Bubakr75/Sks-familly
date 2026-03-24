import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FcmService {
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> init() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      await _saveToken();
      _messaging.onTokenRefresh.listen((newToken) {
        _saveTokenToFirestore(newToken);
      });
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Notification recue: ${message.notification?.title}');
    });
  }

  Future<void> _saveToken() async {
    final token = await _messaging.getToken();
    if (token != null) {
      await _saveTokenToFirestore(token);
    }
  }

  Future<void> _saveTokenToFirestore(String token) async {
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
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
