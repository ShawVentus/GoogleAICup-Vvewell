import 'package:alloop_blue_lite/alloop_blue_lite.dart';
import 'package:aizoring_blue_lite/aizoring_blue_lite.dart';

import 'smart_ring_type.dart';

/// A unified device model that wraps either an Alloop or AIZORING ring.
///
/// Used throughout the scan and device detail flows so a single UI can
/// handle both device types.
class SmartRingDevice {
  /// MAC address or device ID.
  final String id;

  /// Bluetooth advertisement name.
  final String name;

  /// Signal strength in dBm.
  final int rssi;

  /// Which ring type this device represents.
  final SmartRingType type;

  const SmartRingDevice({
    required this.id,
    required this.name,
    required this.rssi,
    required this.type,
  });

  /// Creates a [SmartRingDevice] from an Alloop [LiteDevice].
  factory SmartRingDevice.fromAlloop(LiteDevice device) {
    return SmartRingDevice(
      id: device.id,
      name: device.name,
      rssi: device.rssi,
      type: SmartRingType.alloop,
    );
  }

  /// Creates a [SmartRingDevice] from an AIZORING [AizoDevice].
  factory SmartRingDevice.fromAizoring(AizoDevice device) {
    return SmartRingDevice(
      id: device.id,
      name: device.name,
      rssi: device.rssi,
      type: SmartRingType.aizoring,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SmartRingDevice && id == other.id && type == other.type;

  @override
  int get hashCode => Object.hash(id, type);

  @override
  String toString() =>
      'SmartRingDevice(id: $id, name: $name, rssi: $rssi, type: ${type.displayName})';
}
