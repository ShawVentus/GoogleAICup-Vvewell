import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:pointycastle/export.dart';

/// DIRTY_DEMO_EMBEDDED_CREDENTIALS_REMOVE_BEFORE_RELEASE
///
/// Temporary hackathon-only credential bundle. The AES key must ship beside the
/// ciphertext, so this prevents casual plaintext extraction but provides no
/// meaningful protection against APK reverse engineering.
class EmbeddedDemoCloudCredentials {
  const EmbeddedDemoCloudCredentials({
    required this.url,
    required this.publishableKey,
    required this.memberId,
    required this.email,
    required this.password,
  });

  static const assetPath = 'assets/demo_cloud_credentials.enc';

  final String url;
  final String publishableKey;
  final String memberId;
  final String email;
  final String password;

  static Future<EmbeddedDemoCloudCredentials> load() async {
    final envelope = jsonDecode(await rootBundle.loadString(assetPath));
    if (envelope is! Map<String, dynamic> || envelope['version'] != 1) {
      throw const FormatException('Unsupported cloud demo bundle.');
    }

    final nonce = base64Decode(_requiredEnvelopeValue(envelope, 'nonce'));
    final ciphertext = base64Decode(
      _requiredEnvelopeValue(envelope, 'ciphertext'),
    );
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        false,
        AEADParameters(
          KeyParameter(_decryptionKey()),
          128,
          nonce,
          Uint8List(0),
        ),
      );
    final cleartext = utf8.decode(cipher.process(ciphertext));
    final values = _parseDotenv(cleartext);

    return EmbeddedDemoCloudCredentials(
      url: _requiredValue(values, 'SUPABASE_URL'),
      publishableKey: _requiredValue(values, 'SUPABASE_PUBLISHABLE_KEY'),
      memberId: _requiredValue(values, 'SUPABASE_MEMBER_ID'),
      email: _requiredValue(values, 'SUPABASE_DEMO_EMAIL'),
      password: _requiredValue(values, 'SUPABASE_DEMO_PASSWORD'),
    );
  }

  static Map<String, String> _parseDotenv(String input) {
    final result = <String, String>{};
    for (final rawLine in const LineSplitter().convert(input)) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final separator = line.indexOf('=');
      if (separator <= 0) {
        throw const FormatException('Invalid cloud demo bundle.');
      }
      result[line.substring(0, separator).trim()] = line
          .substring(separator + 1)
          .trim();
    }
    return result;
  }

  static String _requiredEnvelopeValue(
    Map<String, dynamic> envelope,
    String name,
  ) {
    final value = envelope[name];
    if (value is! String || value.isEmpty) {
      throw const FormatException('Incomplete cloud demo bundle.');
    }
    return value;
  }

  static String _requiredValue(Map<String, String> values, String name) {
    final value = values[name];
    if (value == null || value.isEmpty) {
      throw const FormatException('Incomplete cloud demo configuration.');
    }
    return value;
  }

  static Uint8List _decryptionKey() {
    throw StateError('Embedded credentials are excluded from this source package.');
  }
}
