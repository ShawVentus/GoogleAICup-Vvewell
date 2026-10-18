import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:pointycastle/export.dart';

/// DIRTY_DEMO_DIRECT_OCR_CREDENTIALS_REMOVE_BEFORE_RELEASE
///
/// Hackathon-only provider credentials embedded in the APK. The AES key ships
/// with the ciphertext, so this only prevents casual plaintext extraction. It
/// does not protect the provider key from APK reverse engineering.
class EmbeddedDemoOcrCredentials {
  const EmbeddedDemoOcrCredentials({
    required this.baseUrl,
    required this.apiKey,
    required this.model,
  });

  static const assetPath = 'assets/demo_ocr_credentials.enc';

  final String baseUrl;
  final String apiKey;
  final String model;

  static Future<EmbeddedDemoOcrCredentials> load() async {
    final envelope = jsonDecode(await rootBundle.loadString(assetPath));
    if (envelope is! Map<String, dynamic> || envelope['version'] != 1) {
      throw const FormatException('Unsupported OCR demo bundle.');
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

    return EmbeddedDemoOcrCredentials(
      baseUrl: _requiredValue(values, 'OCR_API_BASE_URL'),
      apiKey: _requiredValue(values, 'OCR_API_KEY'),
      model: _requiredValue(values, 'OCR_MODEL'),
    );
  }

  static Map<String, String> _parseDotenv(String input) {
    final result = <String, String>{};
    for (final rawLine in const LineSplitter().convert(input)) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final separator = line.indexOf('=');
      if (separator <= 0) {
        throw const FormatException('Invalid OCR demo bundle.');
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
      throw const FormatException('Incomplete OCR demo bundle.');
    }
    return value;
  }

  static String _requiredValue(Map<String, String> values, String name) {
    final value = values[name];
    if (value == null || value.isEmpty) {
      throw const FormatException('Incomplete OCR demo configuration.');
    }
    return value;
  }

  static Uint8List _decryptionKey() {
    throw StateError('Embedded credentials are excluded from this source package.');
  }
}
