import 'dart:async';

import 'package:flutter/services.dart';

import '../../aizoring/domain/models/smart_ring_device.dart';
import '../../aizoring/domain/models/smart_ring_type.dart';

/// Dedicated platform bridge for the JDY-23 radar.  It intentionally does not
/// share a transport with the two ring SDKs or the XiaoZhi bridge.
class RadarBleRepository {
  static const MethodChannel _channel = MethodChannel('alloop/radar_ble');
  static const EventChannel _eventsChannel =
      EventChannel('alloop/radar_ble/events');

  Stream<Map<String, dynamic>> get events => _eventsChannel
      .receiveBroadcastStream()
      .map((event) => Map<String, dynamic>.from(event as Map));

  Future<List<SmartRingDevice>> scan() async {
    final raw = await _channel.invokeListMethod<dynamic>('scan') ?? const [];
    return raw
        .map((item) => Map<String, dynamic>.from(item as Map))
        .map(
          (item) => SmartRingDevice(
            id: item['address'] as String,
            name: item['name'] as String? ?? '',
            rssi: (item['rssi'] as num?)?.toInt() ?? -127,
            type: SmartRingType.radar,
          ),
        )
        .where((device) => device.name.toUpperCase() == 'JDY-23')
        .toList();
  }

  Future<void> stopScan() => _invoke('stopScan');
  Future<void> connect(SmartRingDevice device) => _invoke('connect', {
        'address': device.id,
        'name': device.name,
      });
  Future<void> disconnect() => _invoke('disconnect');
  Future<void> wakeup() => _invoke('wakeup');
  Future<void> start() => _invoke('start');
  Future<void> stop() => _invoke('stop');

  /// Returns the CSV generated natively from every raw point-cloud frame in
  /// the current measurement session.
  Future<RadarPointCloudExport> exportPointCloudCsv() async {
    final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'exportPointCloudCsv',
    );
    if (raw == null) {
      throw StateError('Point-cloud export did not return a file');
    }
    return RadarPointCloudExport.fromMap(raw);
  }

  /// Returns the CSV generated from VitalMetrics callbacks in the current
  /// measurement session, including confidence, distance and paired I/Q data.
  Future<RadarVitalMetricsExport> exportVitalMetricsCsv() async {
    final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'exportVitalMetricsCsv',
    );
    if (raw == null) {
      throw StateError('Vital-metrics export did not return a file');
    }
    return RadarVitalMetricsExport.fromMap(raw);
  }

  Future<void> queryVitalConfig() => _invoke('queryVitalConfig');
  Future<void> selectVitalBinAutomatically() => _invoke('selectVitalBinAutomatically');

  Future<void> configureVital({
    required bool phaseEnabled,
    required bool pointCloudEnabled,
    required bool manualBin,
    required int selectedBin,
    required int minBin,
    required int maxBin,
  }) =>
      _invoke('configureVital', {
        'phaseEnabled': phaseEnabled,
        'pointCloudEnabled': pointCloudEnabled,
        'manualBin': manualBin,
        'selectedBin': selectedBin,
        'minBin': minBin,
        'maxBin': maxBin,
      });

  Future<void> sendHif(int messageId, String payloadHex) => _invoke(
        'sendHif',
        {'messageId': messageId, 'payloadHex': payloadHex},
      );

  Future<void> _invoke(String method, [Map<String, dynamic>? arguments]) =>
      _channel.invokeMethod<void>(method, arguments);
}

/// Metadata for the native CSV generated from one radar measurement session.
class RadarPointCloudExport {
  const RadarPointCloudExport({
    required this.path,
    required this.frameCount,
    required this.pointCount,
    required this.state,
  });

  final String path;
  final int frameCount;
  final int pointCount;
  final String state;

  factory RadarPointCloudExport.fromMap(Map<dynamic, dynamic> map) {
    return RadarPointCloudExport(
      path: map['path'] as String? ?? '',
      frameCount: (map['frameCount'] as num?)?.toInt() ?? 0,
      pointCount: (map['pointCount'] as num?)?.toInt() ?? 0,
      state: map['state'] as String? ?? 'unknown',
    );
  }
}

/// Metadata for the vital-metrics CSV generated for one radar measurement.
class RadarVitalMetricsExport {
  const RadarVitalMetricsExport({
    required this.path,
    required this.recordCount,
    required this.state,
  });

  final String path;
  final int recordCount;
  final String state;

  factory RadarVitalMetricsExport.fromMap(Map<dynamic, dynamic> map) {
    return RadarVitalMetricsExport(
      path: map['path'] as String? ?? '',
      recordCount: (map['recordCount'] as num?)?.toInt() ?? 0,
      state: map['state'] as String? ?? 'unknown',
    );
  }
}
