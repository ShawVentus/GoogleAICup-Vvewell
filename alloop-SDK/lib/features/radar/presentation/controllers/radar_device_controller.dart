import 'dart:async';
import 'dart:math' as math;

import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/database/local_health_database.dart';
import '../../../../foundations/log/al_logger.dart';
import '../../../../foundations/ui/al_toast.dart';
import '../../../aizoring/domain/models/smart_ring_device.dart';
import '../../../scan/data/connected_device_registry.dart';
import '../../data/radar_ble_repository.dart';

class RadarDeviceController extends GetxController {
  RadarDeviceController({
    required this.device,
    required RadarBleRepository repository,
  }) : _repository = repository;

  final SmartRingDevice device;
  final RadarBleRepository _repository;
  final LocalHealthDatabase _database = LocalHealthDatabase.instance;
  final RxString connectionState = 'disconnected'.obs;
  final RxBool isBusy = false.obs;
  final RxBool isRunning = false.obs;
  final RxBool phaseEnabled = true.obs;
  final RxBool pointCloudEnabled = true.obs;
  final RxBool manualBin = false.obs;
  final RxInt selectedBin = 25.obs;
  final RxInt minBin = 10.obs;
  final RxInt maxBin = 100.obs;
  final RxInt pointFrameIndex = 0.obs;
  final RxInt pointCount = 0.obs;
  final RxList<Map<String, dynamic>> points = <Map<String, dynamic>>[].obs;
  final RxMap<String, dynamic> vitalSample = <String, dynamic>{}.obs;
  final RxMap<String, dynamic> vitalMetrics = <String, dynamic>{}.obs;
  final RxString latestResponse = ''.obs;
  final RxInt capturedPointCloudFrames = 0.obs;
  final RxInt capturedPointCloudPoints = 0.obs;
  final RxString pointCloudCsvPath = ''.obs;
  final RxString pointCloudCaptureState = 'idle'.obs;
  final RxBool isExportingPointCloud = false.obs;
  final RxInt capturedVitalMetricRows = 0.obs;
  final RxString vitalMetricsCsvPath = ''.obs;
  final RxString vitalMetricsCaptureState = 'idle'.obs;
  final RxBool isExportingVitalMetrics = false.obs;
  StreamSubscription<Map<String, dynamic>>? _subscription;

  bool get isConnected => connectionState.value == 'ready';
  bool get hasPointCloudExport => pointCloudCsvPath.value.isNotEmpty;
  bool get hasVitalMetricsExport =>
      vitalMetricsCsvPath.value.isNotEmpty && capturedVitalMetricRows.value > 0;
  bool get isConnecting => const {
    'connecting',
    'discovering',
    'enabling_notifications',
  }.contains(connectionState.value);

  @override
  void onInit() {
    super.onInit();
    _subscription = _repository.events.listen(
      _onEvent,
      onError: (Object error) {
        latestResponse.value = error.toString();
      },
    );
    Future.microtask(connect);
  }

  @override
  void onClose() {
    _subscription?.cancel();
    super.onClose();
  }

  void _onEvent(Map<String, dynamic> event) {
    switch (event['kind']) {
      case 'connection':
        connectionState.value = event['state']?.toString() ?? 'disconnected';
        if (isConnected) {
          ConnectedDeviceRegistry.instance.markConnected(device);
        } else if (connectionState.value == 'disconnected' ||
            connectionState.value == 'error' ||
            connectionState.value == 'failed') {
          ConnectedDeviceRegistry.instance.markDisconnected(
            device.type,
            deviceId: device.id,
          );
        }
        if (!isConnected) isRunning.value = false;
        unawaited(
          _database.upsertDevice(
            deviceId: device.id,
            name: device.name,
            type: 'mmwave_radar',
            connected: isConnected,
          ),
        );
      case 'pointCloud':
        pointFrameIndex.value = (event['frameIndex'] as num?)?.toInt() ?? 0;
        pointCount.value = (event['pointCount'] as num?)?.toInt() ?? 0;
        final raw = event['points'] as List? ?? const [];
        points.assignAll(
          raw.map((item) => Map<String, dynamic>.from(item as Map)),
        );
      case 'vitalSample':
        vitalSample.assignAll(event);
      case 'vitalMetrics':
        vitalMetrics.assignAll(event);
        unawaited(_persistVitalMetrics(event));
      case 'pointCloudCapture':
        _applyPointCloudExport(RadarPointCloudExport.fromMap(event));
      case 'vitalMetricsCapture':
        _applyVitalMetricsExport(RadarVitalMetricsExport.fromMap(event));
      case 'response':
      case 'error':
        latestResponse.value = event['message']?.toString() ?? event.toString();
    }
  }

  Future<void> exportPointCloudCsv() async {
    if (!hasPointCloudExport) {
      AlToast.showInfo("Capture radar data before exporting point cloud CSV");
      return;
    }
    isExportingPointCloud.value = true;
    try {
      final export = await _repository.exportPointCloudCsv();
      _applyPointCloudExport(export);
      AlToast.showSuccess(
        'Exported ${export.frameCount} frames, ${export.pointCount} raw point cloud points',
      );
      AlLogger.info(
        'Point-cloud CSV exported: ${export.path}, '
        'frames=${export.frameCount}, points=${export.pointCount}',
        tag: 'RADAR_EXPORT',
      );
    } catch (error, stackTrace) {
      AlLogger.error(
        'Failed to export radar point-cloud CSV',
        tag: 'RADAR_EXPORT',
        error: error,
        stackTrace: stackTrace,
      );
      AlToast.showError('Could not export point cloud CSV: $error');
    } finally {
      isExportingPointCloud.value = false;
    }
  }

  Future<void> sharePointCloudCsv() async {
    if (!hasPointCloudExport) return;
    isExportingPointCloud.value = true;
    try {
      final export = await _repository.exportPointCloudCsv();
      _applyPointCloudExport(export);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(export.path)],
          subject: 'Radar point-cloud capture',
        ),
      );
      AlLogger.info(
        'Shared point-cloud CSV: ${export.path}',
        tag: 'RADAR_EXPORT',
      );
    } catch (error, stackTrace) {
      AlLogger.error(
        'Failed to share radar point-cloud CSV',
        tag: 'RADAR_EXPORT',
        error: error,
        stackTrace: stackTrace,
      );
      AlToast.showError('Could not share point cloud CSV: $error');
    } finally {
      isExportingPointCloud.value = false;
    }
  }

  Future<void> exportVitalMetricsCsv() async {
    if (!hasVitalMetricsExport) {
      AlToast.showInfo("Capture radar vital signs data first");
      return;
    }
    isExportingVitalMetrics.value = true;
    try {
      final export = await _repository.exportVitalMetricsCsv();
      _applyVitalMetricsExport(export);
      AlToast.showSuccess('Exported ${export.recordCount} vital signs records');
      AlLogger.info(
        'Vital-metrics CSV exported: ${export.path}, records=${export.recordCount}',
        tag: 'RADAR_EXPORT',
      );
    } catch (error, stackTrace) {
      AlLogger.error(
        'Failed to export radar vital-metrics CSV',
        tag: 'RADAR_EXPORT',
        error: error,
        stackTrace: stackTrace,
      );
      AlToast.showError('Could not export vital signs CSV: $error');
    } finally {
      isExportingVitalMetrics.value = false;
    }
  }

  Future<void> shareVitalMetricsCsv() async {
    if (!hasVitalMetricsExport) return;
    isExportingVitalMetrics.value = true;
    try {
      final export = await _repository.exportVitalMetricsCsv();
      _applyVitalMetricsExport(export);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(export.path)],
          subject: 'Radar vital metrics capture',
        ),
      );
      AlLogger.info(
        'Shared vital-metrics CSV: ${export.path}',
        tag: 'RADAR_EXPORT',
      );
    } catch (error, stackTrace) {
      AlLogger.error(
        'Failed to share radar vital-metrics CSV',
        tag: 'RADAR_EXPORT',
        error: error,
        stackTrace: stackTrace,
      );
      AlToast.showError('Could not share vital signs CSV: $error');
    } finally {
      isExportingVitalMetrics.value = false;
    }
  }

  void _applyPointCloudExport(RadarPointCloudExport export) {
    pointCloudCsvPath.value = export.path;
    pointCloudCaptureState.value = export.state;
    capturedPointCloudFrames.value = export.frameCount;
    capturedPointCloudPoints.value = export.pointCount;
  }

  void _applyVitalMetricsExport(RadarVitalMetricsExport export) {
    vitalMetricsCsvPath.value = export.path;
    vitalMetricsCaptureState.value = export.state;
    capturedVitalMetricRows.value = export.recordCount;
  }

  Future<void> _persistVitalMetrics(Map<String, dynamic> event) async {
    final heartRate = _asFiniteDouble(event['heartBpm']);
    final respiratoryRate = _asFiniteDouble(event['breathingBpm']);
    final heartConfidence = _asFiniteDouble(event['heartConfidence']);
    final breathingConfidence = _asFiniteDouble(event['breathingConfidence']);
    final confidences = [
      heartConfidence,
      breathingConfidence,
    ].whereType<double>().toList();
    final confidence = confidences.isEmpty
        ? null
        : confidences.reduce((sum, value) => sum + value) / confidences.length;
    try {
      await _database.saveVitalReading(
        source: 'mmwave_radar',
        deviceId: device.id,
        recordedAt: DateTime.now().toUtc(),
        heartRate: heartRate,
        respiratoryRate: respiratoryRate,
        confidence: confidence,
        isValid: heartRate != null || respiratoryRate != null,
        rawData: {'recordKind': 'radar_vital_metrics', ...event},
      );
    } catch (_) {
      // Sensor rendering must continue even if a local write temporarily fails.
    }
  }

  double? _asFiniteDouble(Object? value) {
    if (value is num) {
      final result = value.toDouble();
      return result.isFinite ? result : null;
    }
    if (value is String) {
      final result = double.tryParse(value);
      return result != null && result.isFinite ? result : null;
    }
    return null;
  }

  Future<void> connect() => _run(() async {
    connectionState.value = 'connecting';
    await _repository.connect(device);
  });

  Future<void> disconnect() => _run(() async {
    await _repository.disconnect();
    connectionState.value = 'disconnected';
    ConnectedDeviceRegistry.instance.markDisconnected(
      device.type,
      deviceId: device.id,
    );
  });

  Future<void> wakeup() => _run(_repository.wakeup);
  Future<void> start() => _run(() async {
    capturedPointCloudFrames.value = 0;
    capturedPointCloudPoints.value = 0;
    pointCloudCsvPath.value = '';
    pointCloudCaptureState.value = 'starting';
    capturedVitalMetricRows.value = 0;
    vitalMetricsCsvPath.value = '';
    vitalMetricsCaptureState.value = 'starting';
    try {
      await _repository.start();
      isRunning.value = true;
    } catch (_) {
      pointCloudCaptureState.value = 'idle';
      rethrow;
    }
  });
  Future<void> stop() => _run(() async {
    try {
      await _repository.stop();
    } finally {
      isRunning.value = false;
    }
  });
  Future<void> queryVitalConfig() => _run(_repository.queryVitalConfig);
  Future<void> selectAutomaticBin() => _run(() async {
    await _repository.selectVitalBinAutomatically();
    manualBin.value = false;
  });

  Future<void> applyVitalConfig() => _run(
    () => _repository.configureVital(
      phaseEnabled: phaseEnabled.value,
      pointCloudEnabled: pointCloudEnabled.value,
      manualBin: manualBin.value,
      selectedBin: selectedBin.value,
      minBin: minBin.value,
      maxBin: maxBin.value,
    ),
  );

  Future<void> lockNearestPointBin() => _run(() async {
    final resolutionMm = (vitalSample['rangeResolutionMm'] as num?)?.toDouble();
    final distance = nearestPointDistance;
    if (resolutionMm == null || resolutionMm <= 0 || distance == null) {
      throw StateError("Start the radar and wait for valid point cloud and I/Q data");
    }
    selectedBin.value = ((distance * 1000) / resolutionMm).round().clamp(
      0,
      0xffff,
    );
    manualBin.value = true;
    await _repository.configureVital(
      phaseEnabled: phaseEnabled.value,
      pointCloudEnabled: pointCloudEnabled.value,
      manualBin: true,
      selectedBin: selectedBin.value,
      minBin: minBin.value,
      maxBin: maxBin.value,
    );
  });

  double? get nearestPointDistance {
    if (points.isEmpty) return null;
    final distances = points.map((point) {
      final x = (point['x'] as num?)?.toDouble() ?? 0;
      final y = (point['y'] as num?)?.toDouble() ?? 0;
      final z = (point['z'] as num?)?.toDouble() ?? 0;
      return math.sqrt(x * x + y * y + z * z);
    });
    return distances.reduce((a, b) => a < b ? a : b);
  }

  Future<void> sendHif(int messageId, String payloadHex) =>
      _run(() => _repository.sendHif(messageId, payloadHex));

  Future<void> _run(Future<void> Function() action) async {
    isBusy.value = true;
    try {
      await action();
    } catch (error) {
      latestResponse.value = error.toString();
      if (!isConnected) connectionState.value = 'error';
    } finally {
      isBusy.value = false;
    }
  }
}
