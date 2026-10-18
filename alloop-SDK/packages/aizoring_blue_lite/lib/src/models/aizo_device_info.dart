import 'aizo_device_config.dart';

/// Device information for a connected AIZORING ring.
class AizoDeviceInfo {
  /// Firmware version string.
  final String firmwareVersion;

  /// Model name.
  final String modelName;

  /// Brand name.
  final String brandName;

  /// Product serial number.
  final String productSn;

  /// Battery percentage (0-100).
  final int batteryPercent;

  /// Whether the device is currently charging.
  final bool isCharging;

  /// Device capabilities (may be null before config callback fires).
  final AizoDeviceConfig? config;

  const AizoDeviceInfo({
    this.firmwareVersion = '',
    this.modelName = '',
    this.brandName = '',
    this.productSn = '',
    this.batteryPercent = 0,
    this.isCharging = false,
    this.config,
  });

  factory AizoDeviceInfo.fromMap(Map<dynamic, dynamic> map) {
    return AizoDeviceInfo(
      firmwareVersion: map['firmwareVersion'] as String? ?? '',
      modelName: map['modelName'] as String? ?? '',
      brandName: map['brandName'] as String? ?? '',
      productSn: map['productSn'] as String? ?? '',
      batteryPercent: map['batteryPercent'] as int? ?? 0,
      isCharging: (map['isCharging'] as int? ?? 0) == 1,
      config: map['config'] != null
          ? AizoDeviceConfig.fromMap(map['config'] as Map<dynamic, dynamic>)
          : null,
    );
  }

  AizoDeviceInfo copyWith({
    String? firmwareVersion,
    String? modelName,
    String? brandName,
    String? productSn,
    int? batteryPercent,
    bool? isCharging,
    AizoDeviceConfig? config,
  }) {
    return AizoDeviceInfo(
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      modelName: modelName ?? this.modelName,
      brandName: brandName ?? this.brandName,
      productSn: productSn ?? this.productSn,
      batteryPercent: batteryPercent ?? this.batteryPercent,
      isCharging: isCharging ?? this.isCharging,
      config: config ?? this.config,
    );
  }

  @override
  String toString() =>
      'AizoDeviceInfo(fw: $firmwareVersion, bat: $batteryPercent%, charging: $isCharging)';
}
