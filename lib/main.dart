import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/bootstrap.dart';
import 'providers/family_provider.dart';
import 'providers/pin_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/onboarding_screen.dart';
import 'screens/welcome_screen.dart';
import 'services/notification_service.dart';

void main() async {
  await bootstrap();
}

class SKSFamilyApp extends StatelessWidget {
  final bool showOnboarding;
  const SKSFamilyApp({super.key, required this.showOnboarding});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FamilyProvider()),
        ChangeNotifierProvider(create: (_) => PinProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) => MaterialApp(
          navigatorKey: NotificationService.navigatorKey,
          title: 'SKS-Familly',
          debugShowCheckedModeBanner: false,
          theme: themeProvider.theme,
          home: showOnboarding 
              ? const OnboardingScreen() 
              : const WelcomeScreen(),
        ),
      ),
    );
  }
}
