import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pointycastle/export.dart' as pc;
import 'package:asn1lib/asn1lib.dart';

class NotificationSender {
  static final NotificationSender _instance = NotificationSender._internal();
  factory NotificationSender() => _instance;
  NotificationSender._internal();

  String? _accessToken;
  DateTime? _tokenExpiry;
  String? _projectId;
  String? _clientEmail;
  String? _privateKey;

  Future<void> _loadServiceAccount() async {
    if (_projectId != null) return;
    final jsonStr = await rootBundle.loadString('assets/service_account.json');
    final sa = jsonDecode(jsonStr);
    _projectId = sa['project_id'];
    _clientEmail = sa['client_email'];
    _privateKey = (sa['private_key'] as String).replaceAll('\\n', '\n');
  }

  String _base64UrlEncode(List<int> bytes) {
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  Uint8List _sign(String input, String pemKey) {
    final keyStr = pemKey
        .replaceAll('-----BEGIN PRIVATE KEY-----', '')
        .replaceAll('-----END PRIVATE KEY-----', '')
        .replaceAll('\n', '')
        .trim();
    final keyBytes = base64.decode(keyStr);

    final asn1Parser = ASN1Parser(Uint8List.fromList(keyBytes));
    final topSeq = asn1Parser.nextObject() as ASN1Sequence;
    final privateKeyOctet = topSeq.elements![2] as ASN1OctetString;

    final pkParser = ASN1Parser(Uint8List.fromList(privateKeyOctet.valueBytes()));
    final pkSeq = pkParser.nextObject() as ASN1Sequence;

    final modulus = (pkSeq.elements![1] as ASN1Integer).valueAsBigInteger;
    final privateExponent = (pkSeq.elements![3] as ASN1Integer).valueAsBigInteger;

    final rsaPrivKey = pc.RSAPrivateKey(modulus, privateExponent, null, null);
    final signer = pc.Signer('SHA-256/RSA');
    signer.init(true, pc.PrivateKeyParameter<pc.RSAPrivateKey>(rsaPrivKey));

    final inputBytes = Uint8List.fromList(utf8.encode(input));
    final sig = signer.generateSignature(inputBytes) as pc.RSASignature;
    return sig.bytes;
  }

  Future<String?> _getAccessToken() async {
    if (_accessToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!)) {
      return _accessToken;
    }

    try {
      await _loadServiceAccount();

      final now = DateTime.now();
      final header = _base64UrlEncode(utf8.encode(jsonEncode({
        'alg': 'RS256',
        'typ': 'JWT',
      })));
      final payload = _base64UrlEncode(utf8.encode(jsonEncode({
        'iss': _clientEmail,
        'scope': 'https://www.googleapis.com/auth/firebase.messaging',
        'aud': 'https://oauth2.googleapis.com/token',
        'iat': now.millisecondsSinceEpoch ~/ 1000,
        'exp': now.add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
      })));

      final signingInput = '$header.$payload';
      final signature = _base64UrlEncode(_sign(signingInput, _privateKey!));
      final jwt = '$signingInput.$signature';

      final response = await http.post(
        Uri.parse('https://oauth2.googleapis.com/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'urn:ietf:params:oauth:grant-type:jwt-bearer',
          'assertion': jwt,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _accessToken = data['access_token'];
        _tokenExpiry = DateTime.now().add(const Duration(minutes: 55));
        if (kDebugMode) debugPrint('FCM access token OK');
        return _accessToken;
      } else {
        if (kDebugMode) debugPrint('Token error: ${response.body}');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('GetAccessToken error: $e');
    }
    return null;
  }

  Future<void> sendToFamily({
    required String title,
    required String body,
    required String type,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final familyId = prefs.getString('family_id');
      final deviceId = prefs.getString('device_id');
      if (familyId == null) return;

      final tokensSnap = await FirebaseFirestore.instance
          .collection('families')
          .doc(familyId)
          .collection('fcm_tokens')
          .get();

      if (tokensSnap.docs.isEmpty) return;

      final token = await _getAccessToken();
      if (token == null || _projectId == null) return;

      for (final doc in tokensSnap.docs) {
        if (doc.id == deviceId) continue;
        final fcmToken = doc.data()['token'] as String?;
        if (fcmToken == null) continue;
        await _sendNotification(
          fcmToken: fcmToken,
          title: title,
          body: body,
          type: type,
          accessToken: token,
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('SendToFamily error: $e');
    }
  }

  Future<void> _sendNotification({
    required String fcmToken,
    required String title,
    required String body,
    required String type,
    required String accessToken,
  }) async {
    try {
      await _loadServiceAccount();
      final url =
          'https://fcm.googleapis.com/v1/projects/$_projectId/messages:send';
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'message': {
            'token': fcmToken,
            'notification': {'title': title, 'body': body},
            'data': {'type': type},
            'android': {
              'notification': {
                'channel_id': 'sks_family_channel',
                'priority': 'high',
              },
            },
          },
        }),
      );
      if (kDebugMode) debugPrint('FCM send: ${response.statusCode}');
    } catch (e) {
      if (kDebugMode) debugPrint('SendNotification error: $e');
    }
  }
}
