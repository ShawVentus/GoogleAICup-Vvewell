import 'dart:async';

import 'package:flutter/services.dart';

import '../../aizoring/domain/models/smart_ring_device.dart';
import '../../aizoring/domain/models/smart_ring_type.dart';
import '../../scan/data/connected_device_registry.dart';

/// Flutter bridge for the Rokid CXRLink client used by the companion app.
class RokidGlassesRepository {
  static const MethodChannel _channel = MethodChannel('alloop/rokid_glasses');
  static const EventChannel _eventChannel = EventChannel(
    'alloop/rokid_glasses/events',
  );

  static final Stream<Map<String, dynamic>> _events = _eventChannel
      .receiveBroadcastStream()
      .map((event) => Map<String, dynamic>.from(event as Map))
      .asBroadcastStream();
  static StreamSubscription<Map<String, dynamic>>? _trackingSubscription;
  static Map<String, dynamic> _lastStatus = const {};

  RokidGlassesRepository() {
    _trackingSubscription ??= _events.listen(_applyStatus, onError: (_) {});
  }

  Stream<Map<String, dynamic>> get events => _events;
  Map<String, dynamic> get lastStatus => Map.unmodifiable(_lastStatus);

  Future<Map<String, dynamic>> refreshStatus() async {
    final raw = await _channel.invokeMapMethod<dynamic, dynamic>('getStatus');
    final status = Map<String, dynamic>.from(raw ?? const {});
    _applyStatus(status);
    return status;
  }

  Future<Map<String, dynamic>> authorizeAndConnect() async {
    final raw = await _channel.invokeMapMethod<dynamic, dynamic>(
      'authorizeAndConnect',
    );
    final status = Map<String, dynamic>.from(raw ?? const {});
    _applyStatus(status);
    return status;
  }

  Future<void> requestDeviceInfo() =>
      _channel.invokeMethod<void>('requestDeviceInfo');

  Future<void> disconnect() async {
    await _channel.invokeMethod<void>('disconnect');
    ConnectedDeviceRegistry.instance.markDisconnected(SmartRingType.glasses);
  }

  Future<void> openCompanionMarket() =>
      _channel.invokeMethod<void>('openCompanionMarket');

  static void _applyStatus(Map<String, dynamic> event) {
    _lastStatus = {..._lastStatus, ...event};
    final connected =
        _lastStatus['ready'] == true ||
        _lastStatus['companionConnected'] == true;
    if (!connected) {
      ConnectedDeviceRegistry.instance.markDisconnected(SmartRingType.glasses);
      return;
    }

    final info = _lastStatus['deviceInfo'] is Map
        ? Map<String, dynamic>.from(_lastStatus['deviceInfo'] as Map)
        : const <String, dynamic>{};
    final serial = info['serialNumber']?.toString().trim();
    final deviceName = info['deviceName']?.toString().trim();
    ConnectedDeviceRegistry.instance.markConnected(
      SmartRingDevice(
        id: serial?.isNotEmpty == true ? serial! : 'rokid-glasses',
        name: deviceName?.isNotEmpty == true ? deviceName! : 'Rokid AI 眼镜',
        rssi: 0,
        type: SmartRingType.glasses,
      ),
    );
  }
}
