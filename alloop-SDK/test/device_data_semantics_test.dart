import 'package:aizoring_blue_lite/aizoring_blue_lite.dart';
import 'package:alloop/core/database/local_health_database.dart';
import 'package:alloop/features/aizoring/presentation/controllers/aizoring_measurement_controller.dart';
import 'package:alloop_blue_lite/alloop_blue_lite.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Alloop history respRate is normalized once from protocol tenths', () {
    const record = MeasurementRecord(
      unixSec: 1,
      hr: 72,
      hrv: 35,
      spo2: 98,
      respRate: 124,
      hrSuccess: true,
      spo2Success: true,
    );

    expect(record.respRate, 124);
    expect(record.respiratoryRateBreathsPerMinute, 12.4);
  });

  test(
    'AIZO measurement type codes keep temperature and blood pressure distinct',
    () {
      expect(AizoInstantMeasurementType.temperature, 0x03);
      expect(AizoInstantMeasurementType.bloodPressure, 0x06);
      expect(
        AizoringMeasurementController.measurementTypes[2]['type'],
        AizoInstantMeasurementType.temperature,
      );
      expect(
        const AizoMeasureResult(
          type: AizoInstantMeasurementType.temperature,
        ).typeLabel,
        'Temperature',
      );
      expect(
        const AizoMeasureResult(
          type: AizoInstantMeasurementType.bloodPressure,
        ).typeLabel,
        'Blood Pressure',
      );
    },
  );

  test('vital provenance preserves source, session and quality metadata', () {
    final recordedAt = DateTime.utc(2026, 8, 2, 12);
    final json = VitalReadingProvenance(
      sessionId: 'radar_123',
      source: 'mmwave_radar',
      deviceId: 'radar-1',
      recordedAt: recordedAt,
      hrConfidence: 0.9,
      rrConfidence: 0.8,
      aggregateQuality: 0.85,
    ).toJson();

    expect(json['sessionId'], 'radar_123');
    expect(json['source'], 'mmwave_radar');
    expect(json['deviceId'], 'radar-1');
    expect(json['recordedAt'], recordedAt.toIso8601String());
    expect(json['schemaVersion'], VitalReadingProvenance.currentSchemaVersion);
    expect(json['origin'], 'realDevice');
    expect(json['isMock'], isFalse);
    expect(json['hrConfidence'], 0.9);
    expect(json['rrConfidence'], 0.8);
    expect(json['aggregateQuality'], 0.85);
  });

  test('ring temperature table row preserves value and UTC record time', () {
    final reading = RingTemperatureReading.fromMap({
      'temperature_c': 36.65,
      'recorded_at': 1785731400000,
    });

    expect(reading.temperatureC, 36.65);
    expect(reading.recordedAt, DateTime.utc(2026, 8, 3, 4, 30));
  });
}
