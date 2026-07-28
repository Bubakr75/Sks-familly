import 'dart:io';

import 'package:family_score/models/child_model.dart';
import 'package:family_score/providers/family_provider.dart';
import 'package:family_score/services/family_backup_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('restaure localement et annule toutes les écritures après une panne',
      () async {
    final tempDirectory =
        await Directory.systemTemp.createTemp('sks_backup_restore_');
    addTearDown(() async {
      await Hive.close();
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });
    Hive.init(tempDirectory.path);
    SharedPreferences.setMockInitialValues({});

    final provider = FamilyProvider();
    addTearDown(provider.dispose);
    await provider.init();
    await provider.addChild('Avant', '👦');
    final originalId = provider.children.single.id;

    final payload = provider.createFamilyBackupPayload(appVersion: '4.8.0+499');
    final collections =
        Map<String, dynamic>.from(payload['collections'] as Map);
    collections['children'] = [
      ChildModel(
        id: 'child-restored',
        name: 'Après',
        avatar: '👧',
      ).toMap(),
    ];
    payload['collections'] = collections;

    final archive = FamilyBackupService.encryptPayload(
      payload,
      'mot-de-passe-de-restauration',
      iterations: FamilyBackupService.minIterations,
    );
    final preview = FamilyBackupService.decryptAndInspect(
      archive,
      'mot-de-passe-de-restauration',
    );

    await expectLater(
      provider.restoreFamilyBackup(
        preview,
        simulateFailureAfterFirstWrite: true,
      ),
      throwsStateError,
    );
    expect(provider.children.single.id, originalId);
    expect(provider.children.single.name, 'Avant');
    expect(Hive.box('restore_journal').isEmpty, isTrue);

    await provider.restoreFamilyBackup(preview);
    expect(provider.children.single.id, 'child-restored');
    expect(provider.children.single.name, 'Après');
    expect(Hive.box('restore_journal').isEmpty, isTrue);
  });
}
