import 'package:alloop_blue_lite/alloop_blue_lite.dart';

abstract interface class DeviceDetailDataSource {
  String get deviceId;

  Future<void> connect();

  Future<void> disconnect();

  Stream<LiteConnectionState> get connectionStateStream;

  Future<LiteDeviceInfo> getDeviceInfo();

  Future<void> startAllMeasurements();

  Future<void> stopMeasurement();

  Stream<Spo2Result> get spo2ResultStream;

  Stream<PpgWave> get ppgWaveStream;

  Stream<AccWave> get accWaveStream;

  Stream<HistorySyncEvent> syncHistory();
}

/// Device detail data repository: wraps device connection and status queries.
class DeviceDetailRepository implements DeviceDetailDataSource {
  @override
  final String deviceId;

  final AlloopBlueLite _blue = AlloopBlueLite.instance;

  DeviceDetailRepository({required this.deviceId});

  /// Connect to the device (progress/result via [connectionStateStream])
  @override
  Future<void> connect() => _blue.connect(deviceId);

  /// Disconnect
  @override
  Future<void> disconnect() => _blue.disconnect(deviceId);

  /// Device connection state stream
  @override
  Stream<LiteConnectionState> get connectionStateStream =>
      _blue.connectionStateStream(deviceId);

  /// Get device info (firmware version, battery, device state)
  @override
  Future<LiteDeviceInfo> getDeviceInfo() => _blue.getDeviceInfo(deviceId);

  /// The Alloop SDK starts SpO2/HR acquisition and emits PPG + ACC through the
  /// same verification session.
  @override
  Future<void> startAllMeasurements() => _blue.startSpo2Verification(deviceId);

  @override
  Future<void> stopMeasurement() => _blue.stopMeasurement(deviceId);

  @override
  Stream<Spo2Result> get spo2ResultStream => _blue.spo2ResultStream(deviceId);

  @override
  Stream<PpgWave> get ppgWaveStream => _blue.ppgWaveStream(deviceId);

  @override
  Stream<AccWave> get accWaveStream => _blue.accStream(deviceId);

  @override
  Stream<HistorySyncEvent> syncHistory() => _blue.syncHistory(deviceId);
}
