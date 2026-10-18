import 'dart:async';

import 'package:aizoring_blue_lite/aizoring_blue_lite.dart';
import 'package:get/get.dart';

import '../../../../core/database/local_health_database.dart';
import '../../../scan/data/connected_device_registry.dart';
import '../../domain/models/smart_ring_device.dart';
import '../../data/repositories/aizoring_device_repository.dart';

/// Controller for the AIZORING device detail page.
class AizoringDeviceDetailController extends GetxController {
  final SmartRingDevice device;
  final AizoringDeviceRepository _repository;

  final RxBool isConnected = false.obs;
  final RxBool isConnecting = false.obs;
  final Rx<AizoDeviceInfo?> deviceInfo = Rx<AizoDeviceInfo?>(null);
  final RxInt batteryPercent = 0.obs;
  final RxBool isCharging = false.obs;
  final Rx<AizoDeviceConfig?> deviceConfig = Rx<AizoDeviceConfig?>(null);

  StreamSubscription<AizoConnectionState>? _connectionSub;
  StreamSubscription<Map<dynamic, dynamic>>? _statusSub;
  bool _hasPowerState = false;

  AizoringDeviceDetailController({
    required this.device,
    required AizoringDeviceRepository repository,
  }) : _repository = repository;

  @override
  void onInit() {
    super.onInit();
    _bindConnection();
    _bindDeviceStatus();

    // Trigger auto-connect after a microtask to let the cached connection
    // state arrive first via the stream replay.
    Future.microtask(() {
      if (!isConnected.value && !isConnecting.value) {
        connect();
      }
    });
  }

  @override
  void onClose() {
    _connectionSub?.cancel();
    _statusSub?.cancel();
    super.onClose();
  }

  void _bindConnection() {
    _connectionSub = _repository.connectionStateStream.listen((state) {
      switch (state.state) {
        case AizoConnectionStateValue.connected:
          isConnected.value = true;
          isConnecting.value = false;
          ConnectedDeviceRegistry.instance.markConnected(device);
          unawaited(_loadDeviceInfo());
        case AizoConnectionStateValue.connecting:
          isConnecting.value = true;
        case AizoConnectionStateValue.disconnected:
          isConnected.value = false;
          isConnecting.value = false;
          ConnectedDeviceRegistry.instance.markDisconnected(
            device.type,
            deviceId: device.id,
          );
          unawaited(_persistDevice(connected: false));
      }
    });
  }

  void _bindDeviceStatus() {
    _statusSub = _repository.deviceStatusStream.listen((map) {
      if (map['kind'] == 'deviceConfig') {
        deviceConfig.value = AizoDeviceConfig.fromMap(map);
        return;
      }
      final pct = (map['batteryPercent'] as num?)?.toInt();
      if (pct != null) {
        batteryPercent.value = pct;
        isCharging.value = (map['isCharging'] as num? ?? 0) == 1;
        _hasPowerState = true;
        unawaited(_persistDevice(connected: isConnected.value));
      }
    });
  }

  Future<void> connect() async {
    isConnecting.value = true;
    try {
      await _repository.connect(device.id);
    } catch (e) {
      isConnecting.value = false;
    }
  }

  Future<void> disconnect() async {
    await _repository.disconnect();
  }

  Future<void> _loadDeviceInfo() async {
    try {
      final info = await _repository.getDeviceInfo();
      deviceInfo.value = info;
      await _persistDevice(connected: isConnected.value, info: info);
    } catch (_) {}
  }

  Future<void> _persistDevice({required bool connected, AizoDeviceInfo? info}) {
    final latestInfo = info ?? deviceInfo.value;
    return LocalHealthDatabase.instance.upsertDevice(
      deviceId: device.id,
      name: latestInfo?.modelName.isNotEmpty == true
          ? latestInfo!.modelName
          : device.name,
      type: 'aizo_ring',
      firmwareVersion: latestInfo?.firmwareVersion,
      batteryPercent: _hasPowerState ? batteryPercent.value : null,
      connected: connected,
    );
  }
}
