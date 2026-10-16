import 'package:family_score/widgets/app_version_label.dart';
import 'package:family_score/widgets/ai_photo_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  testWidgets('le menu affiche la vraie version installée', (tester) async {
    PackageInfo.setMockInitialValues(
      appName: 'SKS Family',
      packageName: 'com.bubakr.sks_family',
      version: '4.8.12',
      buildNumber: '525',
      buildSignature: '',
    );
    await tester
        .pumpWidget(const MaterialApp(home: Scaffold(body: AppVersionLabel())));
    await tester.pump();
    expect(find.text('v4.8.12 (525)'), findsOneWidget);
    expect(find.text('v5.0.0'), findsNothing);
  });

  testWidgets(
      'photo IA non configurée : aucun accès caméra ni pénalité proposée',
      (tester) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
      builder: (context) => TextButton(
        onPressed: () async {
          result = await startAiPhotoFlow(context);
        },
        child: const Text('Photo'),
      ),
    ))));
    await tester.tap(find.text('Photo'));
    await tester.pump();
    expect(result, isFalse);
    expect(
        find.text(
            'L’analyse photo IA n’est pas disponible pour le moment. Tu peux ajouter les points manuellement.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
