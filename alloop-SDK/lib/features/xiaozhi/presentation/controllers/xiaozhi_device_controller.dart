import 'dart:async';

import 'package:get/get.dart';

import '../../../aizoring/domain/models/smart_ring_device.dart';
import '../../../scan/data/connected_device_registry.dart';
import '../../data/xiaozhi_ble_repository.dart';
import '../../domain/proactive_voice_config.dart';
import '../../services/xiaozhi_proactive_voice_service.dart';

class XiaoZhiDeviceController extends GetxController {
  XiaoZhiDeviceController({
    required this.device,
    required XiaoZhiBleRepository repository,
  }) : _repository = repository;

  final SmartRingDevice device;
  final XiaoZhiBleRepository _repository;
  final RxString connectionState = 'disconnected'.obs;
  final RxString deviceStatus = ''.obs;
  final RxString systemInfo = ''.obs;
  final RxString wifiStatus = ''.obs;
  final RxString latestResponse = ''.obs;
  final RxString latestMcpResponse = ''.obs;
  final RxInt volume = 50.obs;
  final RxInt brightness = 50.obs;
  final RxBool isBusy = false.obs;
  final Rx<ProactiveVoiceStatus> proactiveVoiceStatus =
      const ProactiveVoiceStatus(
        config: ProactiveVoiceConfig(),
        isXiaoZhiConnected: false,
        pendingConversationCount: 0,
      ).obs;
  StreamSubscription<Map<String, dynamic>>? _eventSubscription;
  StreamSubscription<ProactiveVoiceStatus>? _proactiveVoiceSubscription;

  XiaoZhiProactiveVoiceService get _proactiveVoice =>
      XiaoZhiProactiveVoiceService.instance;

  bool get isConnected => connectionState.value == 'ready';
  bool get isConnecting =>
      const {'connecting', 'pairing'}.contains(connectionState.value);

  @override
  void onInit() {
    super.onInit();
    _eventSubscription = _repository.events.listen(_onEvent);
    unawaited(_proactiveVoice.initialize());
    proactiveVoiceStatus.value = _proactiveVoice.status;
    _proactiveVoiceSubscription = _proactiveVoice.statusStream.listen((status) {
      proactiveVoiceStatus.value = status;
    });
    Future.microtask(connect);
  }

  @override
  void onClose() {
    _eventSubscription?.cancel();
    _proactiveVoiceSubscription?.cancel();
    super.onClose();
  }

  void _onEvent(Map<String, dynamic> event) {
    final kind = event['kind'];
    final payload =
        event['payload']?.toString() ?? event['detail']?.toString() ?? '';
    switch (kind) {
      case 'connection':
        connectionState.value = event['state']?.toString() ?? 'disconnected';
        if (isConnected) {
          ConnectedDeviceRegistry.instance.markConnected(device);
        } else if (connectionState.value == 'disconnected' ||
            connectionState.value == 'failed') {
          ConnectedDeviceRegistry.instance.markDisconnected(
            device.type,
            deviceId: device.id,
          );
        }
      case 'deviceStatus':
        deviceStatus.value = payload;
      case 'commandResponse':
        latestResponse.value = payload;
      case 'mcpResponse':
        latestMcpResponse.value = payload;
      case 'connectionLost':
        connectionState.value = 'disconnected';
        ConnectedDeviceRegistry.instance.markDisconnected(
          device.type,
          deviceId: device.id,
        );
        latestResponse.value = payload;
    }
  }

  Future<void> connect() => _run(() async {
    connectionState.value = 'connecting';
    await _repository.connect(device);
    await refreshAll();
    await initializeMcp();
  });

  Future<void> disconnect() => _run(() async {
    await _repository.disconnect();
    connectionState.value = 'disconnected';
    ConnectedDeviceRegistry.instance.markDisconnected(
      device.type,
      deviceId: device.id,
    );
  });

  Future<void> refreshAll() => _run(() async {
    final values = await Future.wait([
      _repository.readDeviceStatus(),
      _repository.readSystemInfo(),
      _repository.readWifiStatus(),
    ]);
    deviceStatus.value = values[0];
    systemInfo.value = values[1];
    wifiStatus.value = values[2];
  });

  Future<void> configureWifi(String ssid, String password) => _run(() async {
    await _repository.configureWifi(ssid, password);
    wifiStatus.value = await _repository.readWifiStatus();
  });

  Future<void> setVolume(int value) =>
      _command('set_volume', '{"volume":$value}');
  Future<void> setBrightness(int value) =>
      _command('set_brightness', '{"brightness":$value}');
  Future<void> startListening() => _command('start_listening');
  Future<void> stopListening() => _command('stop_listening');
  Future<void> scanWifi() => _command('get_wifi_scan');

  Future<void> _command(String command, [String paramsJson = '{}']) =>
      _run(() async {
        await _repository.sendCommand(command, paramsJson);
      });

  Future<void> sendCustomCommand(String command, String paramsJson) =>
      _command(command, paramsJson.trim().isEmpty ? '{}' : paramsJson);

  Future<void> initializeMcp() => _run(() => _repository.initializeMcp());
  Future<void> listMcpTools() => _run(() => _repository.listMcpTools());
  Future<void> callMcpTool(String name, String argumentsJson) => _run(
    () => _repository.callMcpTool(
      name,
      argumentsJson.trim().isEmpty ? '{}' : argumentsJson,
    ),
  );
  Future<void> sendRawMcpRequest(String requestJson) =>
      _run(() => _repository.sendMcpRequest(requestJson));

  void updateProactiveVoiceConfig(ProactiveVoiceConfig config) {
    _proactiveVoice.updateConfig(config);
  }

  Future<void> speakNow() => _run(() async {
    final sent = await _proactiveVoice.speakNow();
    if (!sent) {
      latestResponse.value =
          _proactiveVoice.status.lastError ?? '小智未连接或主动语音已关闭';
    }
  });

  Future<void> _run(Future<void> Function() action) async {
    isBusy.value = true;
    try {
      await action();
    } catch (error) {
      latestResponse.value = error.toString();
      if (connectionState.value != 'ready') connectionState.value = 'failed';
    } finally {
      isBusy.value = false;
    }
  }
}
