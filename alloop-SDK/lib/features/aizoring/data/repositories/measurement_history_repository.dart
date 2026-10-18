import '../../../../core/database/local_health_database.dart';
import '../../domain/models/measurement_record.dart';

/// SQLite-backed repository for AIZORING instant-measurement history.
class MeasurementHistoryRepository {
  final LocalHealthDatabase _database = LocalHealthDatabase.instance;

  /// Save one instant result to the shared local health database.
  Future<void> save(
    MeasurementRecord record, {
    String? deviceId,
    String? sessionId,
  }) async {
    final result = record.result;
    final recordedAt = result.timestamp > 0
        ? LocalHealthDatabase.fromUnixSeconds(result.timestamp)
        : DateTime.fromMillisecondsSinceEpoch(record.savedAt, isUtc: true);
    await _database.saveVitalReading(
      source: 'aizo_ring',
      deviceId: deviceId,
      recordedAt: recordedAt,
      heartRate: result.heartRate?.toDouble(),
      spo2: result.bloodOxygen?.toDouble(),
      temperature: result.bodyTemp,
      stress: result.stress?.toDouble(),
      isValid: result.result == 0,
      rawData: {
        'recordKind': 'instant_measurement',
        'savedAt': record.savedAt,
        'type': result.type,
        'resultCode': result.result,
        'timestamp': result.timestamp,
        'heartRate': result.heartRate,
        'bloodOxygen': result.bloodOxygen,
        'bodyTemp': result.bodyTemp,
        'envTemp': result.envTemp,
        'stress': result.stress,
        'uvi': result.uvi,
        'bloodPressure': result.bloodPressure,
      },
      provenance: VitalReadingProvenance(
        sessionId: sessionId,
        source: 'aizo_ring',
        deviceId: deviceId,
        recordedAt: recordedAt,
      ),
    );
  }

  /// Load all measurement records, newest first.
  Future<List<MeasurementRecord>> loadAll({String? deviceId}) async {
    final rows = await _database.loadVitalReadings(
      source: 'aizo_ring',
      deviceId: deviceId,
    );
    final records = <MeasurementRecord>[];
    for (final row in rows) {
      final rawData = _database.decodeRawData(row['raw_data'] as String?);
      if (rawData['recordKind'] != 'instant_measurement') continue;
      rawData['savedAt'] = _asInt(rawData['savedAt']) ??
          _asInt(row['created_at']) ??
          0;
      records.add(MeasurementRecord.fromMap(rawData));
    }
    return records;
  }

  /// Load records for a specific date (day start in milliseconds since epoch).
  Future<List<MeasurementRecord>> loadForDate(
    DateTime date, {
    String? deviceId,
  }) async {
    final all = await loadAll(deviceId: deviceId);
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    return all
        .where((r) =>
            r.savedAt >= dayStart.millisecondsSinceEpoch &&
            r.savedAt < dayEnd.millisecondsSinceEpoch)
        .toList();
  }

  /// Delete all records.
  Future<void> clearAll() async {
    await _database.deleteVitalReadings(
      source: 'aizo_ring',
      rawDataContains: '"recordKind":"instant_measurement"',
    );
  }

  int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
