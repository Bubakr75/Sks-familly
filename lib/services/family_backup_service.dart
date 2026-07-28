import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

class FamilyBackupException implements Exception {
  final String message;
  const FamilyBackupException(this.message);

  @override
  String toString() => message;
}

class FamilyBackupPreview {
  final DateTime createdAt;
  final String appVersion;
  final Map<String, int> counts;
  final Map<String, dynamic> payload;

  const FamilyBackupPreview({
    required this.createdAt,
    required this.appVersion,
    required this.counts,
    required this.payload,
  });
}

/// Codec autonome d'une sauvegarde familiale.
///
/// Le JSON métier est entièrement chiffré. Seuls le format, les algorithmes,
/// le sel et le nonce sont visibles dans l'enveloppe.
class FamilyBackupService {
  static const format = 'sks-family-backup';
  static const envelopeVersion = 1;
  static const payloadVersion = 1;
  static const extension = 'sksfamily';
  static const kdfName = 'PBKDF2-HMAC-SHA256';
  static const cipherName = 'AES-256-GCM';
  static const defaultIterations = 210000;
  static const minIterations = 100000;
  static const maxIterations = 1000000;
  static const maxArchiveBytes = 25 * 1024 * 1024;
  static const maxPasswordBytes = 1024;
  static const minPasswordLength = 10;
  static const _saltLength = 16;
  static const _nonceLength = 12;
  static const _tagLength = 16;

  static const collectionNames = <String>[
    'children',
    'history',
    'goals',
    'notes',
    'punishments',
    'immunities',
    'tribunalCases',
    'customBadges',
    'parentProfiles',
    'trades',
    'pendingRequests',
    'rewards',
    'purchases',
    'chores',
    'wheelSegments',
    'screenTimeAccounts',
  ];

  static Map<String, dynamic> createPayload({
    required String appVersion,
    required Map<String, List<Map<String, dynamic>>> collections,
    required Map<String, dynamic> screenTime,
    required Map<String, dynamic> preferences,
    DateTime? createdAt,
  }) {
    final normalized = <String, dynamic>{};
    for (final name in collectionNames) {
      normalized[name] = (collections[name] ?? const [])
          .map(_removeRemoteMediaTokens)
          .toList(growable: false);
    }

    return {
      'schemaVersion': payloadVersion,
      'createdAt': (createdAt ?? DateTime.now()).toUtc().toIso8601String(),
      'appVersion': appVersion,
      'collections': normalized,
      'screenTime': _removeRemoteMediaTokens(screenTime),
      'preferences': _removeRemoteMediaTokens(preferences),
    };
  }

  static String encryptPayload(
    Map<String, dynamic> payload,
    String password, {
    int iterations = defaultIterations,
    Uint8List? salt,
    Uint8List? nonce,
  }) {
    _validatePassword(password);
    if (iterations < minIterations || iterations > maxIterations) {
      throw const FamilyBackupException(
        'Paramètres de chiffrement non autorisés.',
      );
    }

    final actualSalt = salt ?? _randomBytes(_saltLength);
    final actualNonce = nonce ?? _randomBytes(_nonceLength);
    if (actualSalt.length != _saltLength ||
        actualNonce.length != _nonceLength) {
      throw const FamilyBackupException(
        'Paramètres de chiffrement invalides.',
      );
    }

    final plainBytes = Uint8List.fromList(utf8.encode(jsonEncode(payload)));
    if (plainBytes.length > maxArchiveBytes) {
      throw const FamilyBackupException(
        'La sauvegarde dépasse la taille maximale autorisée.',
      );
    }

    final salt64 = base64Encode(actualSalt);
    final nonce64 = base64Encode(actualNonce);
    final aad = _aad(iterations, salt64, nonce64);
    final key = _deriveKey(password, actualSalt, iterations);
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        true,
        AEADParameters(
          KeyParameter(key),
          _tagLength * 8,
          actualNonce,
          Uint8List.fromList(utf8.encode(aad)),
        ),
      );
    final encrypted = cipher.process(plainBytes);

    return jsonEncode({
      'format': format,
      'version': envelopeVersion,
      'kdf': {
        'name': kdfName,
        'iterations': iterations,
        'salt': salt64,
      },
      'cipher': {
        'name': cipherName,
        'nonce': nonce64,
        'data': base64Encode(encrypted),
      },
    });
  }

  static FamilyBackupPreview decryptAndInspect(
    String archive,
    String password,
  ) {
    _validatePassword(password);
    if (utf8.encode(archive).length > maxArchiveBytes) {
      throw const FamilyBackupException(
        'Le fichier dépasse la taille maximale autorisée.',
      );
    }

    try {
      final envelopeValue = jsonDecode(archive);
      if (envelopeValue is! Map) {
        throw const FamilyBackupException('Format de sauvegarde invalide.');
      }
      final envelope = Map<String, dynamic>.from(envelopeValue);
      if (envelope['format'] != format ||
          envelope['version'] != envelopeVersion) {
        throw const FamilyBackupException(
          'Cette version de sauvegarde n’est pas prise en charge.',
        );
      }

      final kdf = _stringMap(envelope['kdf']);
      final cipherData = _stringMap(envelope['cipher']);
      if (kdf['name'] != kdfName || cipherData['name'] != cipherName) {
        throw const FamilyBackupException(
          'Algorithme de sauvegarde non pris en charge.',
        );
      }

      final iterations = kdf['iterations'];
      if (iterations is! int ||
          iterations < minIterations ||
          iterations > maxIterations) {
        throw const FamilyBackupException(
          'Paramètres de sauvegarde non autorisés.',
        );
      }

      final salt64 = kdf['salt'];
      final nonce64 = cipherData['nonce'];
      final encrypted64 = cipherData['data'];
      if (salt64 is! String || nonce64 is! String || encrypted64 is! String) {
        throw const FamilyBackupException('Format de sauvegarde invalide.');
      }
      if (encrypted64.length > (maxArchiveBytes * 2)) {
        throw const FamilyBackupException(
          'Le contenu chiffré dépasse la limite autorisée.',
        );
      }

      final salt = base64Decode(salt64);
      final nonce = base64Decode(nonce64);
      final encrypted = base64Decode(encrypted64);
      if (salt.length != _saltLength ||
          nonce.length != _nonceLength ||
          encrypted.length < _tagLength ||
          encrypted.length > maxArchiveBytes) {
        throw const FamilyBackupException('Format de sauvegarde invalide.');
      }

      final key = _deriveKey(password, salt, iterations);
      final decipher = GCMBlockCipher(AESEngine())
        ..init(
          false,
          AEADParameters(
            KeyParameter(key),
            _tagLength * 8,
            nonce,
            Uint8List.fromList(
              utf8.encode(_aad(iterations, salt64, nonce64)),
            ),
          ),
        );
      final plain = decipher.process(encrypted);
      final payloadValue = jsonDecode(utf8.decode(plain));
      if (payloadValue is! Map) {
        throw const FamilyBackupException('Contenu de sauvegarde invalide.');
      }
      final payload = Map<String, dynamic>.from(payloadValue);
      return _inspectPayload(payload);
    } on FamilyBackupException {
      rethrow;
    } on FormatException {
      throw const FamilyBackupException(
        'Le fichier est invalide ou endommagé.',
      );
    } on InvalidCipherTextException {
      throw const FamilyBackupException(
        'Mot de passe incorrect ou sauvegarde endommagée.',
      );
    } catch (_) {
      throw const FamilyBackupException(
        'Mot de passe incorrect ou sauvegarde endommagée.',
      );
    }
  }

  static FamilyBackupPreview _inspectPayload(Map<String, dynamic> payload) {
    if (payload['schemaVersion'] != payloadVersion) {
      throw const FamilyBackupException(
        'Cette version de données n’est pas prise en charge.',
      );
    }
    final createdAtRaw = payload['createdAt'];
    final appVersion = payload['appVersion'];
    if (createdAtRaw is! String || appVersion is! String) {
      throw const FamilyBackupException('Métadonnées de sauvegarde invalides.');
    }
    final createdAt = DateTime.tryParse(createdAtRaw);
    if (createdAt == null || appVersion.length > 100) {
      throw const FamilyBackupException('Métadonnées de sauvegarde invalides.');
    }

    final collections = _stringMap(payload['collections']);
    final counts = <String, int>{};
    for (final name in collectionNames) {
      final values = collections[name];
      if (values is! List || values.length > 50000) {
        throw FamilyBackupException('Collection invalide : $name.');
      }
      final ids = <String>{};
      for (final value in values) {
        if (value is! Map) {
          throw FamilyBackupException('Élément invalide dans $name.');
        }
        final item = Map<String, dynamic>.from(value);
        _validateJsonValue(item);
        final id = item['id'] ?? item['childId'];
        if (id is! String || id.isEmpty || id.length > 200 || !ids.add(id)) {
          throw FamilyBackupException(
            'Identifiant manquant ou dupliqué dans $name.',
          );
        }
      }
      counts[name] = values.length;
    }

    final screenTime = _stringMap(payload['screenTime']);
    final preferences = _stringMap(payload['preferences']);
    _validateJsonValue(screenTime);
    _validateJsonValue(preferences);

    return FamilyBackupPreview(
      createdAt: createdAt,
      appVersion: appVersion,
      counts: Map.unmodifiable(counts),
      payload: Map.unmodifiable(payload),
    );
  }

  static Map<String, dynamic> _stringMap(Object? value) {
    if (value is! Map) {
      throw const FamilyBackupException('Format de sauvegarde invalide.');
    }
    try {
      return Map<String, dynamic>.from(value);
    } catch (_) {
      throw const FamilyBackupException('Format de sauvegarde invalide.');
    }
  }

  static void _validatePassword(String password) {
    final length = utf8.encode(password).length;
    if (password.length < minPasswordLength || length > maxPasswordBytes) {
      throw const FamilyBackupException(
        'Le mot de passe doit contenir au moins 10 caractères.',
      );
    }
  }

  static void _validateJsonValue(Object? value, [int depth = 0]) {
    if (depth > 12) {
      throw const FamilyBackupException(
          'Données trop profondément imbriquées.');
    }
    if (value == null || value is bool) return;
    if (value is int) {
      if (value.abs() > 1000000000000) {
        throw const FamilyBackupException('Nombre hors limite.');
      }
      return;
    }
    if (value is double) {
      if (!value.isFinite || value.abs() > 1000000000000) {
        throw const FamilyBackupException('Nombre invalide.');
      }
      return;
    }
    if (value is String) {
      if (value.length > 8 * 1024 * 1024) {
        throw const FamilyBackupException('Texte ou média trop volumineux.');
      }
      return;
    }
    if (value is List) {
      if (value.length > 50000) {
        throw const FamilyBackupException('Liste trop volumineuse.');
      }
      for (final item in value) {
        _validateJsonValue(item, depth + 1);
      }
      return;
    }
    if (value is Map) {
      if (value.length > 1000) {
        throw const FamilyBackupException('Objet trop volumineux.');
      }
      for (final entry in value.entries) {
        if (entry.key is! String || (entry.key as String).length > 100) {
          throw const FamilyBackupException('Clé de données invalide.');
        }
        _validateJsonValue(entry.value, depth + 1);
      }
      return;
    }
    throw const FamilyBackupException('Type de donnée non autorisé.');
  }

  static dynamic _removeRemoteMediaTokens(dynamic value, [String key = '']) {
    if (value is List) {
      return value
          .map((item) => _removeRemoteMediaTokens(item, key))
          .where((item) => item != null)
          .toList(growable: false);
    }
    if (value is Map) {
      return {
        for (final entry in value.entries)
          entry.key.toString():
              _removeRemoteMediaTokens(entry.value, entry.key.toString()),
      };
    }
    if (value is String) {
      final mediaKey = key.toLowerCase().contains('photo') ||
          key.toLowerCase().contains('banner');
      if (mediaKey &&
          (value.startsWith('https://') || value.startsWith('http://'))) {
        return '';
      }
    }
    return value;
  }

  static Uint8List _deriveKey(
    String password,
    Uint8List salt,
    int iterations,
  ) {
    final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, iterations, 32));
    return derivator.process(Uint8List.fromList(utf8.encode(password)));
  }

  static String _aad(int iterations, String salt, String nonce) =>
      '$format|$envelopeVersion|$kdfName|$iterations|$cipherName|$salt|$nonce';

  static Uint8List _randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }
}
