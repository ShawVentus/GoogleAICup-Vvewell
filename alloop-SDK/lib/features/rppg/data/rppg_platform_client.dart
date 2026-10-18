import 'package:flutter/services.dart';

import '../domain/models/rppg_session_result.dart';

class RppgPlatformClient {
  const RppgPlatformClient({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('alloop/rppg_phone');

  final MethodChannel _channel;

  Future<bool> isAvailable() async {
    return await _channel.invokeMethod<bool>('isAvailable') ?? false;
  }

  Future<RppgSessionResult> startMeasurement() async {
    final payload = await _channel.invokeMethod<Object?>('startMeasurement');
    return RppgSessionResult.fromPlatform(payload);
  }

  Future<bool> cancelMeasurement() async {
    return await _channel.invokeMethod<bool>('cancelMeasurement') ?? false;
  }

  Future<RppgSessionResult?> getLastResult() async {
    final payload = await _channel.invokeMethod<Object?>('getLastResult');
    if (payload == null) return null;
    return RppgSessionResult.fromPlatform(payload);
  }
}
