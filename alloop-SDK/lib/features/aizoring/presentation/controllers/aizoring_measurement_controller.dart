import 'dart:async';

import 'package:aizoring_blue_lite/aizoring_blue_lite.dart';
import 'package:get/get.dart';

import '../../data/repositories/measurement_history_repository.dart';
import '../../domain/models/measurement_record.dart';

/// Controller for AIZORING instant measurement.
class AizoringMeasurementController extends GetxController {
  final String deviceId;
  final AizoringBlueLite _aizoring = AizoringBlueLite.instance;
  final MeasurementHistoryRepository _historyRepo =
      MeasurementHistoryRepository();

  final RxBool isMeasuring = false.obs;
  final RxBool isTimedOut = false.obs;
  final Rx<AizoMeasureResult?> latestResult = Rx<AizoMeasureResult?>(null);
  final RxInt selectedType = AizoInstantMeasurementType.heartRate.obs;

  StreamSubscription<AizoMeasureResult>? _resultSub;
  Timer? _timeoutTimer;
  String? _measurementSessionId;

  AizoringMeasurementController({required this.deviceId});

  @override
  void onInit() {
    super.onInit();
    _resultSub = _aizoring.measurementResultStream.listen((result) {
      _timeoutTimer?.cancel();
      latestResult.value = result;
      isMeasuring.value = false;
      isTimedOut.value = false;
      // Auto-save to local history
      _saveToHistory(result, sessionId: _measurementSessionId);
      _measurementSessionId = null;
    });

    // Filter measurement types based on device capabilities
    _aizoring.deviceStatusStream.listen((map) {
      if (map['kind'] == 'deviceConfig') {
        final config = AizoDeviceConfig.fromMap(map);
        _supportedTypes.value = measurementTypes
            .where((t) => _isTypeSupported(t['type'] as int, config))
            .toList();
        // Default to first supported type
        if (_supportedTypes.isNotEmpty &&
            !_supportedTypes.any((t) => t['type'] == selectedType.value)) {
          selectedType.value = _supportedTypes.first['type'] as int;
        }
      }
    });
  }

  bool _isTypeSupported(int type, AizoDeviceConfig config) {
    switch (type) {
      case AizoInstantMeasurementType.heartRate:
        return config.supportsHeartRate;
      case AizoInstantMeasurementType.bloodOxygen:
        return config.supportsBloodOxygen;
      case AizoInstantMeasurementType.temperature:
        return config.supportsTemperature;
      default:
        return false;
    }
  }

  final RxList<Map<String, dynamic>> _supportedTypes =
      <Map<String, dynamic>>[].obs;

  List<Map<String, dynamic>> get supportedTypes =>
      _supportedTypes.isEmpty ? measurementTypes : _supportedTypes;

  @override
  void onClose() {
    _resultSub?.cancel();
    _timeoutTimer?.cancel();
    super.onClose();
  }

  Future<void> startMeasurement() async {
    if (isMeasuring.value) return;
    isMeasuring.value = true;
    final startedAt = DateTime.now().toUtc();
    _measurementSessionId =
        'aizo_instant_${deviceId}_${startedAt.millisecondsSinceEpoch}';
    isTimedOut.value = false;
    latestResult.value = null;
    _timeoutTimer?.cancel();
    // Timeout after 30s — some measurement types may not be supported
    _timeoutTimer = Timer(const Duration(seconds: 30), () {
      if (isMeasuring.value) {
        isMeasuring.value = false;
        isTimedOut.value = true;
      }
    });
    await _aizoring.startInstantMeasurement(selectedType.value);
  }

  Future<void> stopMeasurement() async {
    _timeoutTimer?.cancel();
    if (!isMeasuring.value) return;
    await _aizoring.stopInstantMeasurement(selectedType.value);
    isMeasuring.value = false;
  }

  Future<void> _saveToHistory(
    AizoMeasureResult result, {
    String? sessionId,
  }) async {
    try {
      await _historyRepo.save(MeasurementRecord(
        savedAt: DateTime.now().millisecondsSinceEpoch,
        result: result,
      ), deviceId: deviceId, sessionId: sessionId);
    } catch (_) {}
  }

  void selectType(int type) {
    if (isMeasuring.value) return;
    selectedType.value = type;
    latestResult.value = null;
  }

  String get typeLabel {
    switch (selectedType.value) {
      case AizoInstantMeasurementType.heartRate:
        return 'Heart Rate';
      case AizoInstantMeasurementType.bloodOxygen:
        return 'Blood Oxygen';
      case AizoInstantMeasurementType.temperature:
        return 'Temperature';
      default:
        return 'Unknown';
    }
  }

  /// Measurement type list for UI.
  /// Type codes per AIZORING SDK:
  ///   0x01=Heart Rate, 0x02=Blood Oxygen, 0x03=Body Temperature,
  ///   0x06=Blood Pressure (not exposed by this UI).
  static const List<Map<String, dynamic>> measurementTypes = [
    {'type': AizoInstantMeasurementType.heartRate, 'label': 'Heart Rate', 'unit': 'bpm', 'icon': '❤️'},
    {'type': AizoInstantMeasurementType.bloodOxygen, 'label': 'Blood Oxygen', 'unit': '%', 'icon': '🩸'},
    {'type': AizoInstantMeasurementType.temperature, 'label': 'Temperature', 'unit': '°C', 'icon': '🌡️'},
  ];
}
