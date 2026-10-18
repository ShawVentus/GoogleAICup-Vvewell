import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/digests/sha1.dart';
import 'package:pointycastle/digests/sha256.dart';

String canonicalJson(Object? value) => jsonEncode(_canonical(value));

String sha256Hex(Object? value) => _hex(
  SHA256Digest().process(Uint8List.fromList(utf8.encode(canonicalJson(value)))),
);

String pythonIso(DateTime value) {
  final utc = value.toUtc();
  final base = utc.toIso8601String();
  return '${base.endsWith('.000Z') ? base.substring(0, base.length - 5) : base.substring(0, base.length - 1)}+00:00';
}

String deterministicUuid(String name) {
  final namespace = Uint8List.fromList([
    0x6b,
    0xa7,
    0xb8,
    0x11,
    0x9d,
    0xad,
    0x11,
    0xd1,
    0x80,
    0xb4,
    0x00,
    0xc0,
    0x4f,
    0xd4,
    0x30,
    0xc8,
  ]);
  final digest = SHA1Digest().process(
    Uint8List.fromList([...namespace, ...utf8.encode(name)]),
  );
  final bytes = Uint8List.fromList(digest.take(16).toList());
  bytes[6] = (bytes[6] & 0x0f) | 0x50;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = _hex(bytes);
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

Object? _canonical(Object? value) {
  if (value is DateTime) return pythonIso(value);
  if (value is double && !value.isFinite) return null;
  if (value is Map) {
    final entries =
        value.entries
            .map((entry) => MapEntry(entry.key.toString(), entry.value))
            .toList()
          ..sort((left, right) => left.key.compareTo(right.key));
    return {for (final entry in entries) entry.key: _canonical(entry.value)};
  }
  if (value is Iterable) return value.map(_canonical).toList();
  return value;
}

String _hex(Iterable<int> bytes) =>
    bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
