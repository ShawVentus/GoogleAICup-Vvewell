import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

import '../../aizoring/domain/models/smart_ring_device.dart';
import '../../aizoring/domain/models/smart_ring_type.dart';

/// Android bridge for the XiaoZhi SDK bundled in hardware/xiaozhi.
///
/// All platform calls intentionally stay in this repository. The ring SDKs do
/// not share this bridge, so their connection paths are unchanged.
class XiaoZhiBleRepository {
  static const MethodChannel _channel = MethodChannel('alloop/xiaozhi_ble');
  static const EventChannel _eventsChannel = EventChannel('alloop/xiaozhi_ble/events');
  static final Stream<Map<String, dynamic>> _events = _eventsChannel
      .receiveBroadcastStream()
      .map((event) => Map<String, dynamic>.from(event as Map));

  /// Shared so the persistent proactive-voice service and device page both
  /// receive one native EventChannel subscription instead of replacing it.
  Stream<Map<String, dynamic>> get events => _events;

  Future<List<SmartRingDevice>> scan() async {
    final raw = await _channel.invokeListMethod<dynamic>('scan') ?? const [];
    return raw
        .map((item) => Map<String, dynamic>.from(item as Map))
        .map(
          (item) => SmartRingDevice(
            id: item['address'] as String,
            name: item['name'] as String? ?? '',
            rssi: (item['rssi'] as num?)?.toInt() ?? -127,
            type: SmartRingType.xiaozhi,
          ),
        )
        .where((device) => device.name.toUpperCase().startsWith('XIAOZHI'))
        .toList();
  }

  Future<void> stopScan() => _invoke('stopScan');

  Future<void> connect(SmartRingDevice device) => _invoke('connect', {
        'address': device.id,
        'name': device.name,
        'rssi': device.rssi,
      });

  Future<void> disconnect() => _invoke('disconnect');
  Future<String> readDeviceStatus() => _read('readDeviceStatus');
  Future<String> readSystemInfo() => _read('readSystemInfo');
  Future<String> readWifiStatus() => _read('readWifiStatus');

  Future<void> configureWifi(String ssid, String password) => _invoke(
        'configureWifi',
        {'ssid': ssid, 'password': password},
      );

  Future<void> sendCommand(String command, [String paramsJson = '{}']) =>
      _invoke('sendCommand', {'command': command, 'paramsJson': paramsJson});

  /// Sends a text interaction that XiaoZhi will route to its dialog and TTS
  /// pipeline. The request id lets the firmware report its async lifecycle.
  Future<void> sendText({
    required String requestId,
    required String text,
  }) {
    if (requestId.isEmpty || requestId.length > 64) {
      throw ArgumentError.value(requestId, 'requestId', 'Must contain 1..64 bytes');
    }
    if (text.trim().isEmpty) {
      throw ArgumentError.value(text, 'text', 'Must not be empty');
    }
    return sendCommand(
      'send_text',
      jsonEncode({'request_id': requestId, 'text': text}),
    );
  }

  Future<void> initializeMcp([int requestId = 1]) =>
      _invoke('initializeMcp', {'requestId': requestId});

  Future<void> listMcpTools([int requestId = 2]) =>
      _invoke('listMcpTools', {'requestId': requestId});

  Future<void> callMcpTool(
    String name,
    String argumentsJson, [
    int requestId = 3,
  ]) =>
      _invoke('callMcpTool', {
        'name': name,
        'argumentsJson': argumentsJson,
        'requestId': requestId,
      });

  Future<void> sendMcpRequest(String requestJson) =>
      _invoke('sendMcpRequest', {'requestJson': requestJson});

  Future<String> _read(String method) async =>
      await _channel.invokeMethod<String>(method) ?? '';

  Future<void> _invoke(String method, [Map<String, dynamic>? arguments]) =>
      _channel.invokeMethod<void>(method, arguments);
}
