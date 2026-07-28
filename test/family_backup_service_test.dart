import 'dart:convert';
import 'dart:typed_data';

import 'package:family_score/services/family_backup_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> payload() {
    final collections = <String, List<Map<String, dynamic>>>{
      for (final name in FamilyBackupService.collectionNames)
        name: [
          name == 'screenTimeAccounts'
              ? {'childId': 'child-1', 'balanceMinutes': 20}
              : {'id': '$name-1', 'childId': 'child-1'}
        ],
    };
    collections['children'] = [
      {
        'id': 'child-1',
        'name': 'Enfant secret',
        'photoBase64':
            'https://firebasestorage.googleapis.com/photo?token=secret',
      }
    ];
    return FamilyBackupService.createPayload(
      appVersion: '4.8.0+499',
      collections: collections,
      screenTime: {'child-1_2026_7_27_bonus': 10},
      preferences: {'saleDiscountPercent': 20},
      createdAt: DateTime.utc(2026, 7, 28),
    );
  }

  const password = 'phrase-secrète-très-solide';
  final salt = Uint8List.fromList(List<int>.generate(16, (index) => index));
  final nonce =
      Uint8List.fromList(List<int>.generate(12, (index) => index + 16));

  test('chiffre puis déchiffre une sauvegarde complète', () {
    final archive = FamilyBackupService.encryptPayload(
      payload(),
      password,
      iterations: FamilyBackupService.minIterations,
      salt: salt,
      nonce: nonce,
    );

    expect(archive, isNot(contains('Enfant secret')));
    expect(archive, isNot(contains('token=secret')));

    final preview = FamilyBackupService.decryptAndInspect(archive, password);
    expect(preview.appVersion, '4.8.0+499');
    expect(preview.createdAt, DateTime.utc(2026, 7, 28));
    expect(preview.counts['children'], 1);
    final collections = preview.payload['collections'] as Map<String, dynamic>;
    final child = (collections['children'] as List).single as Map;
    expect(child['photoBase64'], isEmpty);
  });

  test('deux exports identiques utilisent un sel et un nonce différents', () {
    final first = FamilyBackupService.encryptPayload(
      payload(),
      password,
      iterations: FamilyBackupService.minIterations,
    );
    final second = FamilyBackupService.encryptPayload(
      payload(),
      password,
      iterations: FamilyBackupService.minIterations,
    );
    expect(first, isNot(second));
  });

  test('refuse un mauvais mot de passe et un contenu altéré', () {
    final archive = FamilyBackupService.encryptPayload(
      payload(),
      password,
      iterations: FamilyBackupService.minIterations,
      salt: salt,
      nonce: nonce,
    );
    expect(
      () => FamilyBackupService.decryptAndInspect(
        archive,
        'autre-mot-de-passe-solide',
      ),
      throwsA(isA<FamilyBackupException>()),
    );

    final envelope = jsonDecode(archive) as Map<String, dynamic>;
    final cipher = envelope['cipher'] as Map<String, dynamic>;
    final data = base64Decode(cipher['data'] as String);
    data[data.length ~/ 2] ^= 1;
    cipher['data'] = base64Encode(data);
    expect(
      () => FamilyBackupService.decryptAndInspect(
        jsonEncode(envelope),
        password,
      ),
      throwsA(isA<FamilyBackupException>()),
    );
  });

  test('authentifie les paramètres visibles de l’enveloppe', () {
    final archive = FamilyBackupService.encryptPayload(
      payload(),
      password,
      iterations: FamilyBackupService.minIterations,
      salt: salt,
      nonce: nonce,
    );
    final envelope = jsonDecode(archive) as Map<String, dynamic>;
    final cipher = envelope['cipher'] as Map<String, dynamic>;
    cipher['nonce'] = base64Encode(Uint8List(12));

    expect(
      () => FamilyBackupService.decryptAndInspect(
        jsonEncode(envelope),
        password,
      ),
      throwsA(isA<FamilyBackupException>()),
    );
  });

  test('refuse mot de passe court, version future et identifiants dupliqués',
      () {
    expect(
      () => FamilyBackupService.encryptPayload(payload(), 'court'),
      throwsA(isA<FamilyBackupException>()),
    );

    final futurePayload = payload()..['schemaVersion'] = 2;
    final futureArchive = FamilyBackupService.encryptPayload(
      futurePayload,
      password,
      iterations: FamilyBackupService.minIterations,
      salt: salt,
      nonce: nonce,
    );
    expect(
      () => FamilyBackupService.decryptAndInspect(futureArchive, password),
      throwsA(isA<FamilyBackupException>()),
    );

    final duplicatePayload = payload();
    final collections = duplicatePayload['collections'] as Map<String, dynamic>;
    final children = List<Map<String, dynamic>>.from(
      (collections['children'] as List)
          .map((item) => Map<String, dynamic>.from(item as Map)),
    );
    children.add(Map<String, dynamic>.from(children.first));
    collections['children'] = children;
    final duplicateArchive = FamilyBackupService.encryptPayload(
      duplicatePayload,
      password,
      iterations: FamilyBackupService.minIterations,
      salt: salt,
      nonce: nonce,
    );
    expect(
      () => FamilyBackupService.decryptAndInspect(duplicateArchive, password),
      throwsA(isA<FamilyBackupException>()),
    );
  });
}
