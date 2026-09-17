import 'dart:async';

import 'package:family_score/screens/intro_video_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';

class TestVideoController extends VideoPlayerController {
  TestVideoController() : super.asset('unused');
  int disposals = 0;
  final initialized = Completer<void>();
  @override
  Future<void> initialize() => initialized.future;
  @override
  Future<void> setLooping(bool looping) async {}
  @override
  Future<void> setVolume(double volume) async {}
  @override
  Future<void> play() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> dispose() async {
    disposals++;
    await super.dispose();
  }
}

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
  for (final exit in ['fin', 'passer', 'retour']) {
    testWidgets('vidéo initialisée libérée une seule fois : $exit',
        (tester) async {
      final controller = TestVideoController();
      var finished = 0;
      await tester.pumpWidget(MaterialApp(
          home: IntroVideoScreen(
              onFinished: () => finished++,
              controllerFactory: () => controller)));
      controller.value = const VideoPlayerValue(
          duration: Duration(seconds: 3),
          size: Size(320, 180),
          isInitialized: true);
      controller.initialized.complete();
      await tester.pump();
      if (exit == 'fin') {
        controller.value =
            controller.value.copyWith(position: const Duration(seconds: 3));
      } else if (exit == 'passer') {
        await tester.tap(find.byKey(const ValueKey('intro_skip_button')));
      } else {
        await tester.binding.handlePopRoute();
      }
      await tester.pump();
      expect(finished, 1);
      expect(controller.disposals, 1);
      await tester.pumpWidget(const SizedBox());
      expect(controller.disposals, 1);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('Passer libère le contrôleur même pendant initialisation',
      (tester) async {
    final controller = TestVideoController();
    var finished = 0;
    await tester.pumpWidget(MaterialApp(
        home: IntroVideoScreen(
            onFinished: () => finished++,
            controllerFactory: () => controller)));
    await tester.tap(find.byKey(const ValueKey('intro_skip_button')));
    expect(controller.disposals, 1);
    expect(finished, 1);
    controller.initialized.complete();
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    expect(controller.disposals, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('son sans réponse expire et permet un nouvel essai',
      (tester) async {
    final pending = Completer<void>();
    await pumpIntro(tester,
        onFinished: () {}, activateSound: () => pending.future);
    final sound = find.byKey(const ValueKey('intro_sound_button'));
    await tester.tap(sound);
    await tester.pump(const Duration(seconds: 6));
    expect(tester.widget<FilledButton>(sound).onPressed, isNotNull);
    expect(find.byKey(const ValueKey('intro_skip_button')).hitTestable(),
        findsOneWidget);
    pending.complete();
  });

  testWidgets('boutons accessibles après orientation et SafeArea',
      (tester) async {
    await pumpIntro(tester, onFinished: () {}, activateSound: () async {});
    tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
    addTearDown(tester.view.resetPadding);
    tester.view.physicalSize = const Size(844, 390);
    await tester.pump();
    expect(find.byKey(const ValueKey('intro_skip_button')).hitTestable(),
        findsOneWidget);
    expect(find.byKey(const ValueKey('intro_sound_button')).hitTestable(),
        findsOneWidget);
    final intro = find.byType(IntroVideoScreen);
    expect(find.descendant(of: intro, matching: find.byType(ModalBarrier)),
        findsNothing);
    expect(find.descendant(of: intro, matching: find.byType(AbsorbPointer)),
        findsNothing);
    await tester.tap(find.byKey(const ValueKey('intro_sound_button')));
    await tester.pump();
    expect(find.byKey(const ValueKey('intro_sound_button')), findsNothing);
  });
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
