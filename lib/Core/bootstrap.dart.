import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_options.dart';
import '../services/fcm_service.dart';
import '../services/notification_service.dart';
import '../providers/family_provider.dart';
import '../providers/pin_provider.dart';
import '../providers/theme_provider.dart';
import '../main.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  await _initializeHive();
  await initializeDateFormatting('fr_FR', null);

  await _initializeNotifications();
  await _initializeFirebase();
  await _initializeProviders();

  final onboardingDone = await _isOnboardingDone();

  runApp(
    SKSFamilyApp(showOnboarding: !onboardingDone),
  );
}

// ====================== INITIALISATIONS ======================

Future<void> _initializeHive() async {
  await Hive.initFlutter();
  if (kDebugMode) debugPrint('✅ Hive initialized');
}

Future<void> _initializeNotifications() async {
  try {
    await NotificationService.init();
    await NotificationService.scheduleDailyReminder(hour: 19, minute: 0);
    if (kDebugMode) debugPrint('✅ Notifications initialized');
  } catch (e) {
    if (kDebugMode) debugPrint('❌ Notification error: $e');
  }
}

Future<void> _initializeFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await FcmService().init();
    if (kDebugMode) debugPrint('✅ Firebase & FCM initialized');
  } catch (e) {
    if (kDebugMode) debugPrint('❌ Firebase error: $e');
  }
}

Future<void> _initializeProviders() async {
  try {
    final familyProvider = FamilyProvider();
    final pinProvider = PinProvider();
    final themeProvider = ThemeProvider();

    await Future.wait([
      familyProvider.init(),
      pinProvider.init(),
      themeProvider.init(),
    ]);
    if (kDebugMode) debugPrint('✅ Providers initialized');
  } catch (e) {
    if (kDebugMode) debugPrint('❌ Providers init error: $e');
  }
}

Future<bool> _isOnboardingDone() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('onboarding_done') ?? false;
  } catch (e) {
    if (kDebugMode) debugPrint('❌ SharedPreferences error: $e');
    return false;
  }
}
