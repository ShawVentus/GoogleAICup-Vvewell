/// Identifies the type of smart ring device.
enum SmartRingType {
  /// Original Alloop Kit ring.
  alloop,

  /// AIZORING ring.
  aizoring,

  /// XiaoZhi BLE voice assistant device.
  xiaozhi,

  /// JDY-23 UART bridge connected to an MRS6130 mmWave radar.
  radar,

  /// Rokid AI glasses connected through the CXRLink companion service.
  glasses,

  /// vvewell-robot BLE expression and servo controller.
  robot;

  /// Human-readable display name.
  String get displayName {
    switch (this) {
      case SmartRingType.alloop:
        return 'Alloop';
      case SmartRingType.aizoring:
        return 'AIZORING';
      case SmartRingType.xiaozhi:
        return "Health Assistant";
      case SmartRingType.radar:
        return "mmWave radar";
      case SmartRingType.robot:
        return 'vvewell Robot';
      case SmartRingType.glasses:
        return "AI glasses";
    }
  }
}
