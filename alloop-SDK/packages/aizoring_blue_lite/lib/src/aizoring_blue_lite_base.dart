import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'models/aizo_connection_state.dart';
import 'models/aizo_continuous_data.dart';
import 'models/aizo_device.dart';
import 'models/aizo_device_info.dart';
import 'models/aizo_ecg_data.dart';
import 'models/aizo_exception.dart';
import 'models/aizo_health_data.dart';
import 'models/aizo_measure_result.dart';
import 'models/aizo_sleep_data.dart';

/// Entry point for the AIZORING Blue Lite plugin.
///
/// Provides a thin, stream-based Dart API over the native AIZORING
/// [ServiceSdkCommandV2] SDK: scanning, connecting, instant and continuous
/// measurement, health/sleep data retrieval, and ECG measurement.
class AizoringBlueLite {
  AizoringBlueLite._();

  /// The shared singleton instance.
  static final AizoringBlueLite instance = AizoringBlueLite._();

  static const MethodChannel _methodChannel =
      MethodChannel('aizoring_blue_lite/methods');

  static const EventChannel _scanChannel =
      EventChannel('aizoring_blue_lite/events/scan');
  static const EventChannel _connectionChannel =
      EventChannel('aizoring_blue_lite/events/connection');
  static const EventChannel _deviceStatusChannel =
      EventChannel('aizoring_blue_lite/events/device_status');
  static const EventChannel _measurementChannel =
      EventChannel('aizoring_blue_lite/events/measurement');
  static const EventChannel _continuousDataChannel =
      EventChannel('aizoring_blue_lite/events/continuous_data');
  static const EventChannel _healthDataChannel =
      EventChannel('aizoring_blue_lite/events/health_data');
  static const EventChannel _sleepDataChannel =
      EventChannel('aizoring_blue_lite/events/sleep_data');
  static const EventChannel _ecgChannel =
      EventChannel('aizoring_blue_lite/events/ecg');

  StreamController<Map<dynamic, dynamic>>? _scanController;
  StreamController<Map<dynamic, dynamic>>? _connectionController;
  StreamController<Map<dynamic, dynamic>>? _deviceStatusController;
  StreamController<Map<dynamic, dynamic>>? _measurementController;
  StreamController<Map<dynamic, dynamic>>? _continuousDataController;
  StreamController<Map<dynamic, dynamic>>? _healthDataController;
  StreamController<Map<dynamic, dynamic>>? _sleepDataController;
  StreamController<Map<dynamic, dynamic>>? _ecgController;

  StreamSubscription<dynamic>? _scanSubscription;
  StreamSubscription<dynamic>? _connectionSubscription;
  StreamSubscription<dynamic>? _deviceStatusSubscription;
  StreamSubscription<dynamic>? _measurementSubscription;
  StreamSubscription<dynamic>? _continuousDataSubscription;
  StreamSubscription<dynamic>? _healthDataSubscription;
  StreamSubscription<dynamic>? _sleepDataSubscription;
  StreamSubscription<dynamic>? _ecgSubscription;

  bool _isScanning = false;
  Timer? _scanTimeoutTimer;

  /// Last known connection state, used to replay to late subscribers.
  AizoConnectionState? _lastConnectionState;

  /// Display info remembered from scan results, keyed by device MAC.
  final Map<String, AizoDevice> _knownDevices = {};

  /// Resets all cached listeners and derived state (for tests).
  @visibleForTesting
  void resetForTest() {
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
    _deviceStatusSubscription?.cancel();
    _measurementSubscription?.cancel();
    _continuousDataSubscription?.cancel();
    _healthDataSubscription?.cancel();
    _sleepDataSubscription?.cancel();
    _ecgSubscription?.cancel();
    _scanTimeoutTimer?.cancel();

    _scanSubscription = null;
    _connectionSubscription = null;
    _deviceStatusSubscription = null;
    _measurementSubscription = null;
    _continuousDataSubscription = null;
    _healthDataSubscription = null;
    _sleepDataSubscription = null;
    _ecgSubscription = null;
    _scanTimeoutTimer = null;

    _scanController?.close();
    _connectionController?.close();
    _deviceStatusController?.close();
    _measurementController?.close();
    _continuousDataController?.close();
    _healthDataController?.close();
    _sleepDataController?.close();
    _ecgController?.close();

    _scanController = null;
    _connectionController = null;
    _deviceStatusController = null;
    _measurementController = null;
    _continuousDataController = null;
    _healthDataController = null;
    _sleepDataController = null;
    _ecgController = null;

    _isScanning = false;
    _lastConnectionState = null;
    _knownDevices.clear();
  }

  StreamController<Map<dynamic, dynamic>> get _scan =>
      _scanController ??= StreamController<Map<dynamic, dynamic>>.broadcast();
  StreamController<Map<dynamic, dynamic>> get _connection =>
      _connectionController ??=
          StreamController<Map<dynamic, dynamic>>.broadcast();
  StreamController<Map<dynamic, dynamic>> get _deviceStatus =>
      _deviceStatusController ??=
          StreamController<Map<dynamic, dynamic>>.broadcast();
  StreamController<Map<dynamic, dynamic>> get _measurement =>
      _measurementController ??=
          StreamController<Map<dynamic, dynamic>>.broadcast();
  StreamController<Map<dynamic, dynamic>> get _continuousData =>
      _continuousDataController ??=
          StreamController<Map<dynamic, dynamic>>.broadcast();
  StreamController<Map<dynamic, dynamic>> get _healthData =>
      _healthDataController ??=
          StreamController<Map<dynamic, dynamic>>.broadcast();
  StreamController<Map<dynamic, dynamic>> get _sleepData =>
      _sleepDataController ??=
          StreamController<Map<dynamic, dynamic>>.broadcast();
  StreamController<Map<dynamic, dynamic>> get _ecg =>
      _ecgController ??= StreamController<Map<dynamic, dynamic>>.broadcast();

  // ---------------------------------------------------------------------------
  // Public streams
  // ---------------------------------------------------------------------------

  /// Devices discovered while a scan is in progress.
  Stream<AizoDevice> get deviceDiscoveredStream => _scan.stream
      .where((m) => m['kind'] == 'device')
      .map((m) => AizoDevice.fromMap(m));

  /// Scan lifecycle events (start/stop markers).
  Stream<String> get scanStateStream =>
      _scan.stream.where((m) => m['kind'] != 'device').map((m) => m['kind'] as String);

  /// Whether a scan is currently in progress.
  bool get isScanning => _isScanning;

  /// Connection state changes.
  ///
  /// Late subscribers immediately receive the last known state (if any).
  Stream<AizoConnectionState> get connectionStateStream {
    _ensureConnectionListener();
    late StreamController<AizoConnectionState> controller;
    StreamSubscription<Map<dynamic, dynamic>>? subscription;
    controller = StreamController<AizoConnectionState>(
      onListen: () {
        final cached = _lastConnectionState;
        if (cached != null) {
          controller.add(cached);
        }
        subscription = _connection.stream.listen((map) {
          final state = AizoConnectionState.fromMap(map);
          _lastConnectionState = state;
          controller.add(state);
        }, onError: controller.addError, onDone: controller.close);
      },
      onCancel: () => subscription?.cancel(),
    );
    return controller.stream;
  }

  /// Device status updates: battery percentage, charging state, and device
  /// config capabilities.
  Stream<Map<dynamic, dynamic>> get deviceStatusStream {
    _ensureDeviceStatusListener();
    return _deviceStatus.stream;
  }

  /// Instant measurement results.
  Stream<AizoMeasureResult> get measurementResultStream {
    _ensureMeasurementListener();
    return _measurement.stream
        .where((m) => m['kind'] == 'result')
        .map((m) => AizoMeasureResult.fromMap(m));
  }

  /// Continuous measurement data (PPI or Loving raw data).
  Stream<AizoContinuousData> get continuousDataStream {
    _ensureContinuousDataListener();
    return _continuousData.stream.map((m) => AizoContinuousData.fromMap(m));
  }

  /// Continuous measurement lifecycle events (start/end).
  Stream<Map<dynamic, dynamic>> get continuousStateStream {
    _ensureContinuousDataListener();
    return _continuousData.stream
        .where((m) => m['kind'] == 'continuousStart' || m['kind'] == 'continuousEnd');
  }

  /// Historical health data records (JSON from native fastjson).
  Stream<List<AizoHealthData>> get healthDataStream {
    _ensureHealthDataListener();
    return _healthData.stream.where((m) => m['kind'] == 'healthData').map((m) {
      final json = m['json'] as String?;
      if (json == null) return <AizoHealthData>[];
      try {
        return AizoHealthData.fromJsonString(json);
      } catch (e) {
        debugPrint('[Aizoring] Health data parse error: $e');
        return <AizoHealthData>[];
      }
    });
  }

  /// Health data sync completion events.
  Stream<Map<dynamic, dynamic>> get healthDataStateStream {
    _ensureHealthDataListener();
    return _healthData.stream.where((m) => m['kind'] == 'healthDataComplete');
  }

  /// Sleep data records (JSON from native fastjson).
  Stream<List<AizoSleepRecord>> get sleepDataStream {
    _ensureSleepDataListener();
    return _sleepData.stream.where((m) => m['kind'] == 'sleepData').map((m) {
      final json = m['json'] as String?;
      if (json == null) return <AizoSleepRecord>[];
      return AizoSleepRecord.fromJsonString(json);
    });
  }

  /// ECG data stream — raw samples, start/error/finish events.
  Stream<Map<dynamic, dynamic>> get ecgStream {
    _ensureEcgListener();
    return _ecg.stream;
  }

  /// ECG raw waveform samples.
  Stream<AizoEcgSamples> get ecgSamplesStream {
    _ensureEcgListener();
    return _ecg.stream
        .where((m) => m['kind'] == 'ecgData')
        .map((m) => AizoEcgSamples.fromMap(m));
  }

  /// ECG completion result.
  Stream<AizoEcgResult> get ecgResultStream {
    _ensureEcgListener();
    return _ecg.stream
        .where((m) => m['kind'] == 'ecgFinish')
        .map((m) => AizoEcgResult.fromMap(m));
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Initializes the AIZORING SDK. Call once before any other method.
  ///
  /// [btConnectId] is an optional 32-character hex string used as the
  /// Bluetooth connection identifier.
  Future<void> initialize({
    String? btConnectId,
    int region = 1,
    String appVersion = '1.0.0',
    String appName = 'AlloopKit',
    String appId = 'com.alloop.blue.test',
    String country = 'CN',
    String language = 'ZH',
    bool debugging = true,
  }) async {
    _ensureConnectionListener();
    _ensureDeviceStatusListener();
    await _invoke('initialize', {
      'btConnectId': btConnectId,
      'region': region,
      'appVersion': appVersion,
      'appName': appName,
      'appId': appId,
      'country': country,
      'language': language,
      'debugging': debugging,
    });
  }

  // ---------------------------------------------------------------------------
  // Scan
  // ---------------------------------------------------------------------------

  /// Starts scanning for nearby AIZORING devices.
  Future<void> startScan({Duration? timeout}) async {
    _scanTimeoutTimer?.cancel();
    _scanTimeoutTimer = null;
    _ensureScanListener();

    await _invoke('startScan', {});
    _isScanning = true;

    if (timeout != null) {
      _scanTimeoutTimer = Timer(timeout, () {
        _scanTimeoutTimer = null;
        _isScanning = false;
      });
    }
  }

  /// Stops an in-progress scan.
  Future<void> stopScan() async {
    _scanTimeoutTimer?.cancel();
    _scanTimeoutTimer = null;
    await _invoke('stopScan', {});
    _isScanning = false;
  }

  // ---------------------------------------------------------------------------
  // Connection
  // ---------------------------------------------------------------------------

  /// Connects to the device identified by MAC [deviceId].
  Future<void> connect(String deviceId) async {
    _ensureConnectionListener();
    await _invoke('connect', {'deviceId': deviceId});
  }

  /// Disconnects the currently connected device.
  Future<void> disconnect() async {
    await _invoke('disconnect', {});
  }

  /// Fetches device information (firmware, battery, etc.).
  Future<AizoDeviceInfo> getDeviceInfo() async {
    final result = await _invoke('getDeviceInfo', {});
    return AizoDeviceInfo.fromMap(result as Map<dynamic, dynamic>);
  }

  // ---------------------------------------------------------------------------
  // Instant measurement
  // ---------------------------------------------------------------------------

  /// Starts an instant (single-shot) measurement of the given [type].
  ///
  /// [type] measurement codes:
  /// - 0x01: Heart Rate
  /// - 0x02: Blood Oxygen (SpO2)
  /// - 0x03: Temperature
  /// - 0x04: Stress/Pressure
  /// - 0x05: UV Index
  /// - 0x06: Blood Pressure
  Future<void> startInstantMeasurement(int type) async {
    await _invoke('instantMeasurement', {'type': type, 'operation': 0x01});
  }

  /// Stops an ongoing instant measurement for the given [type].
  Future<void> stopInstantMeasurement(int type) async {
    await _invoke('instantMeasurement', {'type': type, 'operation': 0x02});
  }

  // ---------------------------------------------------------------------------
  // Continuous measurement
  // ---------------------------------------------------------------------------

  /// Starts continuous raw data measurement.
  ///
  /// [measureType] determines the data type (e.g. 0x010B for PPI+raw).
  /// [measureMode] controls the mode (default 1).
  /// [timeout] in seconds, or 0 for no timeout.
  Future<void> startContinuousMeasure({
    required int measureType,
    int measureMode = 1,
    int timeout = 0,
  }) async {
    await _invoke('startContinuousMeasure', {
      'measureType': measureType,
      'measureMode': measureMode,
      'timeout': timeout,
    });
  }

  /// Stops the ongoing continuous measurement for [measureType].
  Future<void> stopContinuousMeasure(int measureType) async {
    await _invoke('stopContinuousMeasure', {'measureType': measureType});
  }

  // ---------------------------------------------------------------------------
  // Health / Sleep data
  // ---------------------------------------------------------------------------

  /// Retrieves historical health data for the given [time] (start-of-day unix
  /// timestamp in seconds). Results arrive via [healthDataStream].
  Future<void> getHealthData(int time) async {
    await _invoke('getHealthData', {'time': time});
  }

  /// Retrieves sleep data for the given [time] (start-of-day unix timestamp in
  /// seconds). Results arrive via [sleepDataStream].
  Future<void> getSleepData(int time) async {
    await _invoke('getSleepData', {'time': time});
  }

  // ---------------------------------------------------------------------------
  // ECG
  // ---------------------------------------------------------------------------

  /// Starts an ECG measurement.
  ///
  /// [wearType]: 0x01 = left hand, 0x02 = right hand.
  Future<void> startEcgMeasure({int wearType = 0x01}) async {
    await _invoke('startEcgMeasure', {'wearType': wearType});
  }

  /// Stops an ongoing ECG measurement.
  Future<void> stopEcgMeasure() async {
    await _invoke('stopEcgMeasure', {});
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  void _ensureScanListener() {
    _scanSubscription ??= _scanChannel.receiveBroadcastStream().listen((event) {
      final map = event as Map<dynamic, dynamic>;
      if (map['kind'] == 'device') {
        final device = AizoDevice.fromMap(map);
        _knownDevices[device.id] = device;
      }
      _scan.add(map);
    });
  }

  void _ensureConnectionListener() {
    _connectionSubscription ??=
        _connectionChannel.receiveBroadcastStream().listen((event) {
      _connection.add(event as Map<dynamic, dynamic>);
    });
  }

  void _ensureDeviceStatusListener() {
    _deviceStatusSubscription ??=
        _deviceStatusChannel.receiveBroadcastStream().listen((event) {
      _deviceStatus.add(event as Map<dynamic, dynamic>);
    });
  }

  void _ensureMeasurementListener() {
    _measurementSubscription ??=
        _measurementChannel.receiveBroadcastStream().listen((event) {
      _measurement.add(event as Map<dynamic, dynamic>);
    });
  }

  void _ensureContinuousDataListener() {
    _continuousDataSubscription ??=
        _continuousDataChannel.receiveBroadcastStream().listen((event) {
      _continuousData.add(event as Map<dynamic, dynamic>);
    });
  }

  void _ensureHealthDataListener() {
    _healthDataSubscription ??=
        _healthDataChannel.receiveBroadcastStream().listen((event) {
      _healthData.add(event as Map<dynamic, dynamic>);
    });
  }

  void _ensureSleepDataListener() {
    _sleepDataSubscription ??=
        _sleepDataChannel.receiveBroadcastStream().listen((event) {
      _sleepData.add(event as Map<dynamic, dynamic>);
    });
  }

  void _ensureEcgListener() {
    _ecgSubscription ??=
        _ecgChannel.receiveBroadcastStream().listen((event) {
      _ecg.add(event as Map<dynamic, dynamic>);
    });
  }

  Future<dynamic> _invoke(String method, Map<String, dynamic> args) async {
    try {
      return await _methodChannel.invokeMethod(method, args);
    } on PlatformException catch (error) {
      throw _toException(error);
    }
  }

  AizoringBlueLiteException _toException(Object error) {
    if (error is PlatformException) {
      return AizoringBlueLiteException(error.code, error.message);
    }
    return AizoringBlueLiteException('UNKNOWN', error.toString());
  }
}
