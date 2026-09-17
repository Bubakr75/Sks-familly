import 'dart:async';
import 'package:family_score/utils/pwa_lifecycle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('standalone via display-mode ou navigator.standalone', () {
    for (final display in [false, true]) {
      for (final navigator in [false, true]) {
        expect(isStandaloneMode(displayMode: display, navigatorFlag: navigator),
            display || navigator);
      }
    }
  });
  testWidgets('20 cycles et rattachements gardent exactement 5 listeners',
      (tester) async {
    var active = 0;
    var visible = true;
    var resumes = 0;
    var pauses = 0;
    final streams = List.generate(
        5,
        (_) => StreamController<PwaEvent>.broadcast(
            sync: true, onListen: () => active++, onCancel: () => active--));
    final lifecycle = PwaLifecycle(
        isVisible: () => visible,
        standalone: true,
        onResume: () => resumes++,
        onPause: () => pauses++);
    for (var cycle = 0; cycle < 20; cycle++) {
      lifecycle.attach(streams.map((s) => s.stream).toList());
      expect(active, 5);
      visible = false;
      streams[0].add(PwaEvent.hidden);
      streams[4].add(PwaEvent.pageHide);
      visible = true;
      streams[3].add(PwaEvent.pageShow);
      streams[0].add(PwaEvent.visible);
      streams[1].add(PwaEvent.online);
      streams[2].add(PwaEvent.focus);
      await tester.pump(const Duration(milliseconds: 699));
      expect(resumes, cycle);
      await tester.pump(const Duration(milliseconds: 1));
      expect(resumes, cycle + 1);
      streams[2].add(PwaEvent.focus);
      await tester.pump(const Duration(seconds: 1));
      expect(resumes, cycle + 1);
      expect(active, 5);
    }
    expect(pauses, 20);
    lifecycle.detach();
    expect(active, 0);
    for (final stream in streams) {
      await stream.close();
    }
  });
  testWidgets('arrière-plan et detach annulent la reprise en attente',
      (tester) async {
    var visible = true;
    var resumes = 0;
    final lifecycle = PwaLifecycle(
        isVisible: () => visible, standalone: true, onResume: () => resumes++)
      ..attach([]);
    lifecycle.handle(PwaEvent.online);
    visible = false;
    await tester.pump(const Duration(seconds: 1));
    expect(resumes, 0);
    visible = true;
    lifecycle.handle(PwaEvent.online);
    lifecycle.detach();
    await tester.pump(const Duration(seconds: 1));
    expect(resumes, 0);
  });
  testWidgets('Safari conserve la reprise sur focus et pageshow',
      (tester) async {
    var resumes = 0;
    final lifecycle = PwaLifecycle(
        isVisible: () => true, standalone: false, onResume: () => resumes++)
      ..attach([]);
    lifecycle.handle(PwaEvent.focus);
    lifecycle.handle(PwaEvent.pageShow);
    await tester.pump(const Duration(seconds: 1));
    expect(resumes, 1);
    lifecycle.detach();
  });
  testWidgets(
      'diagnostic inactif par défaut et seulement deux compteurs anonymes',
      (tester) async {
    for (final enabled in [false, true]) {
      final diagnostics =
          enabled ? PwaDiagnostics(enabled: true) : PwaDiagnostics();
      final lifecycle = PwaLifecycle(
          isVisible: () => true,
          standalone: true,
          onResume: () {},
          diagnostics: diagnostics)
        ..attach([]);
      lifecycle.handle(PwaEvent.online);
      await tester.pump(const Duration(seconds: 1));
      expect(diagnostics.snapshot,
          enabled ? {'events': 1, 'resumes': 1} : isEmpty);
      lifecycle.detach();
    }
  });
}
