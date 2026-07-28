import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/fcm_service.dart';
import 'services/auth_service.dart';
import 'services/voice_service.dart';
import 'services/storage_service.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'firebase_options.dart';
import 'providers/family_provider.dart';
import 'providers/pin_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/onboarding_screen.dart';
import 'screens/profile_selection_screen.dart';
import 'screens/intro_video_screen.dart';
import 'services/notification_service.dart';
import 'widgets/mode_indicator.dart';

void main() {
  // âš ï¸ On lance runApp() LE PLUS VITE POSSIBLE, puis on initialise les
  // services en arriÃ¨re-plan. Ainsi, mÃªme si un plugin hang sur web,
  // l'app s'affiche avec un Ã©cran de chargement au lieu d'un Ã©cran blanc.
  runApp(const SKSBootstrap());
}

/// Widget de dÃ©marrage : affiche un splash puis lance l'initialisation
/// asynchrone des services (Hive, Firebase, providers...) sans bloquer.
class SKSBootstrap extends StatefulWidget {
  const SKSBootstrap({super.key});
  @override
  State<SKSBootstrap> createState() => _SKSBootstrapState();
}

class _SKSBootstrapState extends State<SKSBootstrap> {
  bool _ready = false;
  bool _showOnboarding = false;
  bool _showIntro = false; // affiche la vidÃ©o d'intro une fois
  // Instances initialisÃ©es en arriÃ¨re-plan, rÃ©utilisÃ©es par MultiProvider
  final FamilyProvider _familyProvider = FamilyProvider();
  final PinProvider _pinProvider = PinProvider();
  final ThemeProvider _themeProvider = ThemeProvider();

  @override
  void initState() {
    super.initState();
    // L'intro se joue Ã  chaque dÃ©marrage
    _showIntro = false; // intro geree en HTML dans index.html
    _initializeEverything();
  }

  void _onIntroFinished() {
    if (!mounted) return;
    setState(() => _showIntro = false);
    _initializeEverything();
  }

  Future<void> _initializeEverything() async {
    // 1. Binding + Hive + intl (rapide et sÃ»r)
    try {
      await Hive.initFlutter();
    } catch (e) {
      if (kDebugMode) debugPrint('Hive init error: $e');
    }
    try {
      await initializeDateFormatting('fr_FR', null);
    } catch (e) {
      if (kDebugMode) debugPrint('intl init error: $e');
    }

    // 2. Notifications (court-circuitÃ© sur web dans le service)
    try {
      await NotificationService.init().timeout(
        const Duration(seconds: 5),
        onTimeout: () => debugPrint('Notification init timeout'),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('NotificationService init error: $e');
    }

    // 2b. Voix TTS (non bloquant)
    try {
      await VoiceService().init().timeout(
            const Duration(seconds: 3),
            onTimeout: () => debugPrint('Voice init timeout'),
          );
    } catch (e) {
      if (kDebugMode) debugPrint('VoiceService init error: $e');
    }

    // 3. Firebase (avec timeout pour ne jamais bloquer)
    bool firebaseReady = false;
    try {
      await Firebase.initializeApp(
              options: DefaultFirebaseOptions.currentPlatform)
          .timeout(
        const Duration(seconds: 8),
        onTimeout: () => throw Exception('Firebase init timeout'),
      );
      firebaseReady = true;

      // 3b. Crashlytics : capturer tous les plantages en production
      try {
        await FirebaseCrashlytics.instance
            .setCrashlyticsCollectionEnabled(true);
        FlutterError.onError =
            FirebaseCrashlytics.instance.recordFlutterFatalError;
      } catch (e) {
        if (kDebugMode) debugPrint('Crashlytics init error: $e');
      }
    } catch (e) {
      if (e.toString().contains('already been initialized') ||
          e.toString().contains('duplicate-app')) {
        firebaseReady = true;
      }
      if (kDebugMode) debugPrint('Firebase init: $e');
    }

    // 4. FCM (avec timeout)
    if (firebaseReady) {
      // Authentification anonyme â€” OBLIGATOIRE avant Firestore (rÃ¨gles strictes)
      try {
        await AuthService().ensureConnected().timeout(
              const Duration(seconds: 8),
              onTimeout: () => debugPrint('Auth init timeout'),
            );
      } catch (e) {
        if (kDebugMode) debugPrint('AuthService init error: $e');
      }

      try {
        await FcmService().init().timeout(
              const Duration(seconds: 6),
              onTimeout: () => debugPrint('FCM init timeout'),
            );
      } catch (e) {
        if (kDebugMode) debugPrint('FcmService init error: $e');
      }
    }

    // 5. Providers
    try {
      await Future.wait<void>([
        _pinProvider.init(),
        _themeProvider.init(),
      ]).timeout(const Duration(seconds: 5));
    } catch (e) {
      if (kDebugMode) debugPrint('Provider init error / timeout: $e');
    }

    try {
      await _familyProvider.init().timeout(
            const Duration(seconds: 8),
            onTimeout: () => debugPrint('FamilyProvider init timeout'),
          );
    } catch (e) {
      if (kDebugMode) debugPrint('FamilyProvider init error: $e');
    }

    // ðŸ”§ FIX CRITIQUE : RÃ©-enregistrer le token FCM APRÃˆS que device_id soit gÃ©nÃ©rÃ©
    // (FamilyProvider.init() â†’ FirestoreService.init() gÃ©nÃ¨re le device_id)
    // Sans Ã§a, au 1er lancement, le token n'est pas sauvÃ© â†’ pas de notifs parent !
    if (firebaseReady) {
      try {
        await FcmService().registerToken().timeout(
              const Duration(seconds: 5),
              onTimeout: () => debugPrint('FCM re-register timeout'),
            );
      } catch (e) {
        if (kDebugMode) debugPrint('FCM re-register error: $e');
      }
    }

    // Rappels de notifications (non bloquants, et uniquement hors web)
    if (!kIsWeb) {
      try {
        await NotificationService.scheduleDailyReminder(hour: 20, minute: 15)
            .timeout(const Duration(seconds: 3));
      } catch (e) {
        if (kDebugMode) debugPrint('Schedule reminder error: $e');
      }
    }

    // 6. Onboarding ?
    bool onboardingDone = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      onboardingDone = prefs.getBool('onboarding_done') ?? false;
    } catch (e) {
      if (kDebugMode) debugPrint('SharedPreferences error: $e');
    }

    if (!mounted) return;
    setState(() {
      _showOnboarding = !onboardingDone;
      _ready = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Ã‰cran d'intro vidÃ©o (1Ã¨re fois seulement)
    if (_showIntro) {
      return IntroVideoScreen(onFinished: _onIntroFinished);
    }
    // Splash pendant l'initialisation
    return Container(
      color: const Color(0xFF000000),
      child: _ready
          ? MultiProvider(
              providers: [
                ChangeNotifierProvider.value(value: _familyProvider),
                ChangeNotifierProvider.value(value: _pinProvider),
                ChangeNotifierProvider.value(value: _themeProvider),
              ],
              child: SKSFamilyApp(showOnboarding: _showOnboarding),
            )
          : const _SplashScreen(),
    );
  }
}

/// Splash Flutter : fond NOIR PUR (zÃ©ro logo), pour transition invisible
/// vers la vidÃ©o d'intro. Plus aucun Ã©cran gris/blanc/logo au dÃ©marrage.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Material(color: Color(0xFF000000));
  }
}

class SKSFamilyApp extends StatefulWidget {
  final bool showOnboarding;
  const SKSFamilyApp({super.key, required this.showOnboarding});
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
      // ðŸš« DÃ‰SACTIVÃ‰ : le mode parent ne bascule plus en mode enfant au retour
      // final pin = context.read<PinProvider>();
      // if (pin.isPinSet && pin.isParentMode) {
      //   pin.lockParentMode();
      // }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (_, themeProvider, __) => MaterialApp(
        navigatorKey: NotificationService.navigatorKey,
        title: 'SKS-Familly',
        debugShowCheckedModeBanner: false,
        builder: (context, child) {
          return Shortcuts(
            shortcuts: <ShortcutActivator, Intent>{
              const SingleActivator(LogicalKeyboardKey.select):
                  const ActivateIntent(),
              const SingleActivator(LogicalKeyboardKey.enter):
                  const ActivateIntent(),
              const SingleActivator(LogicalKeyboardKey.numpadEnter):
                  const ActivateIntent(),
              const SingleActivator(LogicalKeyboardKey.gameButtonA):
                  const ActivateIntent(),
              const SingleActivator(LogicalKeyboardKey.goBack):
                  const DismissIntent(),
              const SingleActivator(LogicalKeyboardKey.browserBack):
                  const DismissIntent(),
              const SingleActivator(LogicalKeyboardKey.escape):
                  const DismissIntent(),
            },
            child: FocusTraversalGroup(
              policy: ReadingOrderTraversalPolicy(),
              child: child ?? const SizedBox(),
            ),
          );
        },
        theme: themeProvider.theme,
        home: widget.showOnboarding
            ? const OnboardingScreen()
            : const _StartupRouter(),
      ),
    );
  }
}

class _StartupRouter extends StatefulWidget {
  const _StartupRouter();
  @override
  State<_StartupRouter> createState() => _StartupRouterState();
}

class _StartupRouterState extends State<_StartupRouter> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        context.read<FamilyProvider>().reconnectFirestore();
      } catch (e) {
        if (kDebugMode) debugPrint('Reconnect Firestore error: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const ProfileSelectionScreen();
  }
}
