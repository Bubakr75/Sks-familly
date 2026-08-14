import 'package:family_score/screens/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Passer quitte le tutoriel sans attendre le stockage local',
      (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingScreen(
          destinationBuilder: (_) => const Scaffold(body: Text('Accueil')),
        ),
      ),
    );

    expect(find.text('Passer'), findsOneWidget);
    await tester.tap(find.text('Passer'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Accueil'), findsOneWidget);
  });
}
