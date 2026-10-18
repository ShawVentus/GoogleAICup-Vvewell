import 'dart:async';

import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../data/rokid_glasses_repository.dart';

class RokidGlassesController extends GetxController {
  RokidGlassesController({required RokidGlassesRepository repository})
    : _repository = repository;

  final RokidGlassesRepository _repository;
  final RxBool isBusy = false.obs;
  final RxBool companionInstalled = false.obs;
  final RxBool companionConnected = false.obs;
  final RxBool authorized = false.obs;
  final RxBool cxrlConnected = false.obs;
  final RxBool bluetoothConnected = false.obs;
  final RxBool ready = false.obs;
  final RxMap<String, dynamic> deviceInfo = <String, dynamic>{}.obs;
  final RxString errorMessage = ''.obs;
  StreamSubscription<Map<String, dynamic>>? _subscription;

  @override
  void onInit() {
    super.onInit();
    _subscription = _repository.events.listen(
      _applyStatus,
      onError: (Object error) => errorMessage.value = error.toString(),
    );
    Future.microtask(refreshStatus);
  }

  @override
  void onClose() {
    _subscription?.cancel();
    super.onClose();
  }

  Future<void> refreshStatus() => _run(() async {
    _applyStatus(await _repository.refreshStatus());
    if (ready.value) await _repository.requestDeviceInfo();
  });

  Future<void> authorizeAndConnect() => _run(() async {
    _applyStatus(await _repository.authorizeAndConnect());
  });

  Future<void> disconnect() => _run(() async {
    await _repository.disconnect();
    _applyStatus(const {
      'authorized': false,
      'cxrlConnected': false,
      'bluetoothConnected': false,
      'ready': false,
    });
  });

  Future<void> openCompanionMarket() => _run(_repository.openCompanionMarket);

  void _applyStatus(Map<String, dynamic> status) {
    companionInstalled.value =
        status['companionInstalled'] as bool? ?? companionInstalled.value;
    companionConnected.value =
        status['companionConnected'] as bool? ?? companionConnected.value;
    authorized.value = status['authorized'] as bool? ?? authorized.value;
    cxrlConnected.value =
        status['cxrlConnected'] as bool? ?? cxrlConnected.value;
    bluetoothConnected.value =
        status['bluetoothConnected'] as bool? ?? bluetoothConnected.value;
    ready.value = status['ready'] as bool? ?? ready.value;
    if (status['deviceInfo'] is Map) {
      deviceInfo.assignAll(
        Map<String, dynamic>.from(status['deviceInfo'] as Map),
      );
    }
    final error = status['error']?.toString();
    if (error != null && error.isNotEmpty) errorMessage.value = error;
  }

  Future<void> _run(Future<void> Function() action) async {
    isBusy.value = true;
    errorMessage.value = '';
    try {
      await action();
    } on PlatformException catch (error) {
      errorMessage.value = error.message ?? error.code;
    } catch (error) {
      errorMessage.value = error.toString();
    } finally {
      isBusy.value = false;
    }
  }
}
