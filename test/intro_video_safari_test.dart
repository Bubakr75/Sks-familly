import 'dart:async';

import 'package:family_score/screens/intro_video_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void compactView(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> pumpIntro(
  WidgetTester tester, {
  required VoidCallback onFinished,
  Future<void> Function()? initialize,
  Future<void> Function()? activateSound,
  Size size = const Size(375, 667),
}) async {
  compactView(tester, size);
  await tester.pumpWidget(MaterialApp(
    home: IntroVideoScreen(
      onFinished: onFinished,
      initializeForTest: initialize ?? () async {},
      activateSoundForTest: activateSound,
    ),
  ));
  await tester.pump();
}

void main() {
  testWidgets('Passer est immédiatement visible et tappable sur iPhone',
      (tester) async {
    var finished = 0;
    final loading = Completer<void>();
    await pumpIntro(
      tester,
      onFinished: () => finished++,
      initialize: () => loading.future,
    );
    final skip = find.byKey(const ValueKey('intro_skip_button'));
    expect(skip, findsOneWidget);
    expect(skip.hitTestable(), findsOneWidget);
    await tester.tap(skip);
    await tester.pump();
    expect(finished, 1);
    loading.complete();
  });

  testWidgets('activation du son autorisée reste liée au tap', (tester) async {
    var calls = 0;
    await pumpIntro(
      tester,
      size: const Size(390, 844),
      onFinished: () {},
      activateSound: () {
        calls++;
        return Future.value();
      },
    );
    final sound = find.byKey(const ValueKey('intro_sound_button'));
    expect(sound.hitTestable(), findsOneWidget);
    await tester.tap(sound);
    expect(calls, 1);
    await tester.pump();
    expect(find.text('Activer le son'), findsNothing);
  });

  testWidgets('refus du son affiche une erreur sans bloquer Passer',
      (tester) async {
    var finished = 0;
    await pumpIntro(
      tester,
      onFinished: () => finished++,
      activateSound: () => Future.error(StateError('refus Safari')),
    );
    await tester.tap(find.byKey(const ValueKey('intro_sound_button')));
    await tester.pump();
    expect(find.textContaining('Safari a refusé le son'), findsOneWidget);
    final skip = find.byKey(const ValueKey('intro_skip_button'));
    expect(skip.hitTestable(), findsOneWidget);
    await tester.tap(skip);
    expect(finished, 1);
  });

  testWidgets('pression répétée ne lance pas plusieurs activations',
      (tester) async {
    final gate = Completer<void>();
    var calls = 0;
    await pumpIntro(
      tester,
      onFinished: () {},
      activateSound: () {
        calls++;
        return gate.future;
      },
    );
    final sound = find.byKey(const ValueKey('intro_sound_button'));
    await tester.tap(sound);
    await tester.tap(sound, warnIfMissed: false);
    await tester.pump();
    expect(calls, 1);
    gate.complete();
  });

  testWidgets('erreur ou absence vidéo ne bloque pas le démarrage',
      (tester) async {
    var finished = 0;
    await pumpIntro(
      tester,
      onFinished: () => finished++,
      initialize: () => Future.error(StateError('vidéo absente')),
    );
    await tester.pump();
    expect(finished, 1);
  });

  testWidgets('retour système ferme proprement l’introduction', (tester) async {
    var finished = 0;
    await pumpIntro(tester, onFinished: () => finished++);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(finished, 1);
  });
}
