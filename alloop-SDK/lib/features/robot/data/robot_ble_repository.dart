import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

import '../../aizoring/domain/models/smart_ring_device.dart';
import '../../aizoring/domain/models/smart_ring_type.dart';

/// Native Android GATT bridge for the vvewell-robot firmware protocol.
class RobotBleRepository {
  static const MethodChannel _channel = MethodChannel('alloop/robot_ble');
  static const EventChannel _eventsChannel =
      EventChannel('alloop/robot_ble/events');

  static final Stream<Map<String, dynamic>> _events = _eventsChannel
      .receiveBroadcastStream()
      .map((event) => Map<String, dynamic>.from(event as Map));

  Stream<Map<String, dynamic>> get events => _events;

  Future<List<SmartRingDevice>> scan() async {
    final raw = await _channel.invokeListMethod<dynamic>('scan') ?? const [];
    return raw
        .map((item) => Map<String, dynamic>.from(item as Map))
        .map((item) => SmartRingDevice(
              id: item['address'] as String,
              name: item['name'] as String? ?? '',
              rssi: (item['rssi'] as num?)?.toInt() ?? -127,
              type: SmartRingType.robot,
            ))
        .toList();
  }

  Future<void> stopScan() => _channel.invokeMethod<void>('stopScan');

  Future<void> connect(SmartRingDevice device) => _channel.invokeMethod<void>(
        'connect',
        {'address': device.id},
      );

  Future<void> disconnect() => _channel.invokeMethod<void>('disconnect');

  Future<void> sendCommand(String command, [Map<String, dynamic> values = const {}]) {
    return _channel.invokeMethod<void>('sendCommand', {
      'payload': jsonEncode({'cmd': command, ...values}),
    });
  }
}
