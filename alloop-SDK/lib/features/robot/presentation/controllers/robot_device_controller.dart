import 'dart:async';

import 'package:get/get.dart';

import '../../../aizoring/domain/models/smart_ring_device.dart';
import '../../../scan/data/connected_device_registry.dart';
import '../../data/robot_ble_repository.dart';

class RobotDeviceController extends GetxController {
  RobotDeviceController({required this.device, required RobotBleRepository repository})
      : _repository = repository;

  final SmartRingDevice device;
  final RobotBleRepository _repository;
  final connectionState = 'disconnected'.obs;
  final angle = 90.0.obs;
  final selectedExpression = 'off'.obs;
  final latestResponse = ''.obs;
  final isBusy = false.obs;
  StreamSubscription<Map<String, dynamic>>? _eventsSubscription;

  bool get isConnected => connectionState.value == 'connected';

  @override
  void onInit() {
    super.onInit();
    _eventsSubscription = _repository.events.listen(_onEvent);
    Future.microtask(connect);
  }

  @override
  void onClose() {
    _eventsSubscription?.cancel();
    super.onClose();
  }

  void _onEvent(Map<String, dynamic> event) {
    switch (event['kind']) {
      case 'connection':
        connectionState.value = event['state']?.toString() ?? 'disconnected';
        if (isConnected) {
          ConnectedDeviceRegistry.instance.markConnected(device);
        } else if (connectionState.value == 'disconnected' ||
            connectionState.value == 'failed') {
          ConnectedDeviceRegistry.instance.markDisconnected(device.type, deviceId: device.id);
        }
      case 'response':
        latestResponse.value = event['payload']?.toString() ?? '';
    }
  }

  Future<void> connect() => _run(() => _repository.connect(device));

  Future<void> disconnect() => _run(() async {
        await _repository.disconnect();
        connectionState.value = 'disconnected';
        ConnectedDeviceRegistry.instance.markDisconnected(device.type, deviceId: device.id);
      });

  Future<void> setExpression(String name) => _run(() async {
        selectedExpression.value = name;
        await _repository.sendCommand('expression', {'name': name});
      });

  Future<void> setServoAngle(double value) => _run(() async {
        final normalized = value.round().clamp(0, 180);
        angle.value = normalized.toDouble();
        await _repository.sendCommand('servo', {'angle': normalized});
      });

  Future<void> turnServoOff() => _run(() => _repository.sendCommand('servo_off'));
  Future<void> requestStatus() => _run(() => _repository.sendCommand('status'));

  Future<void> _run(Future<void> Function() action) async {
    isBusy.value = true;
    try {
      await action();
    } catch (error) {
      latestResponse.value = error.toString();
      if (!isConnected) connectionState.value = 'failed';
    } finally {
      isBusy.value = false;
    }
  }
}
