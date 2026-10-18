import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../aizoring/domain/models/smart_ring_device.dart';
import '../../aizoring/domain/models/smart_ring_type.dart';

/// Process-wide connection registry for devices whose SDKs expose a single
/// connection state instead of an Alloop-style connected-device list.
class ConnectedDeviceRegistry {
  ConnectedDeviceRegistry._();

  static final ConnectedDeviceRegistry instance = ConnectedDeviceRegistry._();

  final Map<String, SmartRingDevice> _devices = {};
  final StreamController<List<SmartRingDevice>> _changes =
      StreamController<List<SmartRingDevice>>.broadcast();

  List<SmartRingDevice> get devices => List.unmodifiable(_sortedDevices());

  Stream<List<SmartRingDevice>> get stream {
    late StreamController<List<SmartRingDevice>> controller;
    StreamSubscription<List<SmartRingDevice>>? subscription;
    controller = StreamController<List<SmartRingDevice>>(
      onListen: () {
        controller.add(devices);
        subscription = _changes.stream.listen(
          controller.add,
          onError: controller.addError,
        );
      },
      onCancel: () => subscription?.cancel(),
    );
    return controller.stream;
  }

  void markConnected(SmartRingDevice device) {
    _devices[_key(device.type, device.id)] = device;
    _emit();
  }

  void markDisconnected(SmartRingType type, {String? deviceId}) {
    if (deviceId != null) {
      _devices.remove(_key(type, deviceId));
    } else {
      _devices.removeWhere((_, device) => device.type == type);
    }
    _emit();
  }

  @visibleForTesting
  void resetForTest() {
    _devices.clear();
    _emit();
  }

  List<SmartRingDevice> _sortedDevices() =>
      _devices.values.toList()..sort((a, b) {
        final typeOrder = a.type.index.compareTo(b.type.index);
        return typeOrder != 0 ? typeOrder : a.name.compareTo(b.name);
      });

  void _emit() => _changes.add(devices);

  String _key(SmartRingType type, String id) => '${type.name}:$id';
}
