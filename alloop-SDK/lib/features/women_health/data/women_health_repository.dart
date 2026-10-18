import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class WomenHealthRepository {
  static const _channel = MethodChannel('alloop/local_health_database');
  static final _webRecords = <Map<String, dynamic>>[];

  Future<List<Map<String, dynamic>>> loadRecords() async {
    if (kIsWeb) return List.unmodifiable(_webRecords);
    final rows =
        await _channel.invokeMethod<List<dynamic>>('loadWomenHealthRecords') ??
        const [];
    return rows
        .whereType<Map>()
        .map((row) => row.map((k, v) => MapEntry('$k', v)))
        .toList();
  }

  Future<bool> hasDeviceTrend() async {
    if (kIsWeb) return false;
    final rows =
        await _channel.invokeMethod<List<dynamic>>('loadVitalReadings', {
          'limit': 1,
        }) ??
        const [];
    return rows.isNotEmpty;
  }

  Future<void> _save(Map<String, dynamic> record) async {
    if (kIsWeb) {
      _webRecords.add({
        'record_type': record['recordType'],
        'recorded_at': record['recordedAt'],
        'payload': record['payload'],
      });
      return;
    }
    await _channel.invokeMethod<void>('saveWomenHealthRecord', record);
  }

  Future<void> savePeriod({
    required DateTime start,
    DateTime? end,
    required String flow,
    required String symptoms,
    required String note,
  }) => _save({
    'recordType': 'period',
    'recordedAt': start.millisecondsSinceEpoch,
    'payload': jsonEncode({
      'end': end?.millisecondsSinceEpoch,
      'flow': flow,
      'symptoms': symptoms,
      'note': note,
    }),
  });

  Future<void> saveProfile({
    required String mode,
    required DateTime anchorDate,
  }) => _save({
    'recordType': 'profile',
    'recordedAt': anchorDate.millisecondsSinceEpoch,
    'payload': jsonEncode({
      'mode': mode,
      'anchorDate': anchorDate.millisecondsSinceEpoch,
    }),
  });
}
