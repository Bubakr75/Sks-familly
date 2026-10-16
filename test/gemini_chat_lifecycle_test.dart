import 'dart:async';

import 'package:family_score/providers/family_provider.dart';
import 'package:family_score/providers/pin_provider.dart';
import 'package:family_score/screens/gemini_chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('l’assistant tient sur un petit écran', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FamilyProvider()),
        ChangeNotifierProvider(create: (_) => PinProvider()),
      ],
      child: const MaterialApp(home: GeminiChatScreen()),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  Future<void> open(WidgetTester tester, Future<String> response) async {
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FamilyProvider()),
        ChangeNotifierProvider(create: (_) => PinProvider()),
      ],
      child: MaterialApp(
          home:
              GeminiChatScreen(reply: (message, family, history) => response)),
    ));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Bonjour');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
  }

  testWidgets('quitter pendant la réponse ne provoque pas de plantage',
      (tester) async {
    final response = Completer<String>();
    await open(tester, response.future);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    response.complete('Réponse tardive');
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('un mode parent verrouillé masque le contexte familial',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final pin = PinProvider();
    await pin.setPin('1234');
    pin.lockParentMode();
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: pin,
      child: const MaterialApp(home: GeminiChatScreen()),
    ));
    expect(find.byType(TextField), findsNothing);
    expect(
        find.text(
            'Déverrouille le mode parent pour accéder à l’assistant familial.'),
        findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    pin.dispose();
  });

  testWidgets('une erreur de réponse libère le champ de conversation',
      (tester) async {
    final response = Completer<String>();
    await open(tester, response.future);
    response.completeError(StateError('Échec simulé'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
        find.text(
            'La réponse n’a pas pu être reçue. Réessaie dans un instant.'),
        findsOneWidget);
    expect(
        tester
            .widget<IconButton>(
                find.widgetWithIcon(IconButton, Icons.delete_outline))
            .onPressed,
        isNotNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 300));
  });
}
