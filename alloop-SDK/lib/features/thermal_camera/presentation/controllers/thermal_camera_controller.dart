import 'dart:async';

import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../data/thermal_camera_repository.dart';

class ThermalCameraController extends GetxController {
  ThermalCameraController({required ThermalCameraRepository repository})
    : _repository = repository;

  final ThermalCameraRepository _repository;
  final RxString connectionState = 'disconnected'.obs;
  final RxString errorMessage = ''.obs;
  final RxBool isBusy = false.obs;
  final RxInt sdkVersion = 0.obs;
  StreamSubscription<Map<String, dynamic>>? _subscription;

  bool get isConnected =>
      connectionState.value == 'connected' ||
      connectionState.value == 'previewing';
  bool get isPreviewing => connectionState.value == 'previewing';

  @override
  void onInit() {
    super.onInit();
    _subscription = _repository.events.listen(
      _onEvent,
      onError: (Object error) => errorMessage.value = error.toString(),
    );
    Future.microtask(_connectOnOpen);
  }

  @override
  void onClose() {
    _subscription?.cancel();
    super.onClose();
  }

  Future<void> _connectOnOpen() async {
    await refreshStatus();
    if (!isConnected) await connect();
  }

  Future<void> refreshStatus() => _run(() async {
    _applyState(await _repository.getState());
  });

  Future<void> connect() => _run(() async {
    connectionState.value = 'connecting';
    _applyState(await _repository.connect());
  });

  Future<void> disconnect() => _run(() async {
    await _repository.disconnect();
    connectionState.value = 'disconnected';
  });

  void _onEvent(Map<String, dynamic> event) {
    _applyState(event);
  }

  void _applyState(Map<String, dynamic> state) {
    connectionState.value = state['state']?.toString() ?? connectionState.value;
    sdkVersion.value =
        (state['sdkVersion'] as num?)?.toInt() ?? sdkVersion.value;
    final error = state['error']?.toString();
    if (error != null && error.isNotEmpty) errorMessage.value = error;
  }

  Future<void> _run(Future<void> Function() action) async {
    isBusy.value = true;
    errorMessage.value = '';
    try {
      await action();
    } on PlatformException catch (error) {
      errorMessage.value = error.message ?? error.code;
      if (!isConnected) connectionState.value = 'error';
    } catch (error) {
      errorMessage.value = error.toString();
      if (!isConnected) connectionState.value = 'error';
    } finally {
      isBusy.value = false;
    }
  }
}
