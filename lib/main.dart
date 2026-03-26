import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/fcm_service.dart';

import 'firebase_options.dart';
import 'providers/family_provider.dart';
import 'providers/pin_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/welcome_screen.dart';
import 'services/notification_service.dart';
import 'services/update_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  await initializeDateFormatting('fr_FR', null);

  try {
    await NotificationService.init();
    if (kDebugMode) debugPrint('NotificationService initialized OK');
  } catch (e) {
    if (kDebugMode) debugPrint('NotificationService init error: $e');
  }

  bool firebaseReady = false;
  for (int attempt = 1; attempt <= 3; attempt++) {
    try {
      try {
        Firebase.app();
        if (kDebugMode) {
          debugPrint('Firebase already initialized (attempt $attempt)');
        }
        firebaseReady = true;
        break;
      } catch (_) {}

      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      if (kDebugMode) debugPrint('Firebase initialized OK (attempt $attempt)');
      firebaseReady = true;
      break;
    } catch (e) {
      if (e.toString().contains('already been initialized') ||
          e.toString().contains('duplicate-app')) {
        if (kDebugMode) debugPrint('Firebase was already initialized');
        firebaseReady = true;
        break;
      }

      if (kDebugMode) {
        debugPrint('Firebase init attempt $attempt failed: $e');
      }

      if (attempt < 3) {
        await Future.delayed(Duration(milliseconds: 500 * attempt));
      }
    }
  }

  if (!firebaseReady && kDebugMode) {
    debugPrint('WARNING: Firebase not initialized after 3 attempts');
  }

  // Initialiser FCM pour les notifications push
  if (firebaseReady) {
    try {
      await FcmService().init();
      if (kDebugMode) debugPrint('FcmService initialized OK');
    } catch (e) {
      if (kDebugMode) debugPrint('FcmService init error: $e');
    }
  }

  final familyProvider = FamilyProvider();
  final pinProvider = PinProvider();
  final themeProvider = ThemeProvider();

  try {
    await Future.wait([
      pinProvider.init(),
      themeProvider.init(),
    ]);
  } catch (e) {
    if (kDebugMode) debugPrint('Provider init error: $e');
  }

  try {
    await familyProvider.init();

    try {
      await NotificationService.scheduleDailyReminder(hour: 19, minute: 0);
    } catch (e) {
      if (kDebugMode) debugPrint('Schedule reminder error: $e');
    }
  } catch (e) {
    if (kDebugMode) debugPrint('FamilyProvider init error: $e');
  }

  bool onboardingDone = false;
  bool openDirectlyToHome = false;

  try {
    final prefs = await SharedPreferences.getInstance();
    onboardingDone = prefs.getBool('onboarding_done') ?? false;

    openDirectlyToHome =
        familyProvider.children.isNotEmpty ||
        familyProvider.history.isNotEmpty ||
        familyProvider.isSyncEnabled;
  } catch (e) {
    if (kDebugMode) debugPrint('SharedPreferences error: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: familyProvider),
        ChangeNotifierProvider.value(value: pinProvider),
        ChangeNotifierProvider.value(value: themeProvider),
      ],
      child: SKSFamilyApp(
        showOnboarding: !onboardingDone,
        openDirectlyToHome: openDirectlyToHome,
      ),
    ),
  );
}

class SKSFamilyApp extends StatefulWidget {
  final bool showOnboarding;
  final bool openDirectlyToHome;

  const SKSFamilyApp({
    super.key,
    required this.showOnboarding,
    required this.openDirectlyToHome,
  });

  @override
  State<SKSFamilyApp> createState() => _SKSFamilyAppState();
}

class _SKSFamilyAppState extends State<SKSFamilyApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (kDebugMode) debugPrint('App resumed - reconnecting Firestore...');
      final familyProvider = context.read<FamilyProvider>();
      familyProvider.reconnectFirestore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (_, themeProvider, __) => MaterialApp(
        navigatorKey: NotificationService.navigatorKey,
        title: 'SKS Family',
        debugShowCheckedModeBanner: false,
                builder: (context, child) {
          return FocusTraversalGroup(
            policy: ReadingOrderTraversalPolicy(),
            child: child ?? const SizedBox(),
          );
        },

        theme: themeProvider.theme,
        home: widget.showOnboarding
            ? const OnboardingScreen()
            : _StartupRouter(openDirectlyToHome: widget.openDirectlyToHome),
      ),
    );
  }
}

class _StartupRouter extends StatefulWidget {
  final bool openDirectlyToHome;

  const _StartupRouter({
    required this.openDirectlyToHome,
  });

  @override
  State<_StartupRouter> createState() => _StartupRouterState();
}

class _StartupRouterState extends State<_StartupRouter> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      UpdateService.checkForUpdate(context);

      try {
        context.read<FamilyProvider>().reconnectFirestore();
      } catch (e) {
        if (kDebugMode) debugPrint('Reconnect Firestore error: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.openDirectlyToHome) {
      return const HomeScreen();
    }

    return WelcomeScreen(
      onEnter: () {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const HomeScreen(),
            transitionsBuilder: (_, anim, __, child) {
              return FadeTransition(
                opacity: CurvedAnimation(
                  parent: anim,
                  curve: Curves.easeIn,
                ),
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 600),
          ),
        );
      },
    );
  }
}
