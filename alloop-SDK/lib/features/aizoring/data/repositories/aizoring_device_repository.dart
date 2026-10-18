import 'package:aizoring_blue_lite/aizoring_blue_lite.dart';

/// Repository for AIZORING device connection and info.
class AizoringDeviceRepository {
  final AizoringBlueLite _aizoring = AizoringBlueLite.instance;

  Stream<AizoConnectionState> get connectionStateStream =>
      _aizoring.connectionStateStream;

  Stream<Map<dynamic, dynamic>> get deviceStatusStream =>
      _aizoring.deviceStatusStream;

  Future<void> connect(String deviceId) => _aizoring.connect(deviceId);

  Future<void> disconnect() => _aizoring.disconnect();

  Future<AizoDeviceInfo> getDeviceInfo() => _aizoring.getDeviceInfo();
}
