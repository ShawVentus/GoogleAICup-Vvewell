import 'dart:async';

import 'package:flutter/services.dart';

class ThermalCameraRepository {
  static const MethodChannel _channel = MethodChannel('alloop/thermal_camera');
  static const EventChannel _eventChannel = EventChannel(
    'alloop/thermal_camera/events',
  );

  static final Stream<Map<String, dynamic>> _events = _eventChannel
      .receiveBroadcastStream()
      .map((event) => Map<String, dynamic>.from(event as Map))
      .asBroadcastStream();

  Stream<Map<String, dynamic>> get events => _events;

  Future<Map<String, dynamic>> getState() async {
    final raw = await _channel.invokeMapMethod<dynamic, dynamic>('getState');
    return Map<String, dynamic>.from(raw ?? const {});
  }

  Future<Map<String, dynamic>> connect() async {
    final raw = await _channel.invokeMapMethod<dynamic, dynamic>('connect');
    return Map<String, dynamic>.from(raw ?? const {});
  }

  Future<void> disconnect() => _channel.invokeMethod<void>('disconnect');
}
