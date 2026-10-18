/// A scanned AIZORING Bluetooth device.
class AizoDevice {
  /// MAC address of the device.
  final String id;

  /// Bluetooth advertisement name.
  final String name;

  /// Signal strength in dBm.
  final int rssi;

  const AizoDevice({
    required this.id,
    required this.name,
    required this.rssi,
  });

  factory AizoDevice.fromMap(Map<dynamic, dynamic> map) {
    return AizoDevice(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      rssi: map['rssi'] as int? ?? -100,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'rssi': rssi,
    };
  }

  @override
  String toString() => 'AizoDevice(id: $id, name: $name, rssi: $rssi)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AizoDevice && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
