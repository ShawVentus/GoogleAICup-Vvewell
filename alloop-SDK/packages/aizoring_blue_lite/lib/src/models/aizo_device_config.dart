/// Device capability configuration from AIZORING SDK.
class AizoDeviceConfig {
  /// Heart rate monitoring mode (0x00=off, 0x01=auto, 0x03=APP controlled).
  final int heartRateMonitoring;

  /// Blood oxygen monitoring mode.
  final int bloodOxygenMonitoring;

  /// Temperature monitoring mode.
  final int temperatureMonitoring;

  /// Blood pressure monitoring mode.
  final int bloodPressureMonitoring;

  /// Blood sugar monitoring mode.
  final int bloodSugarMonitoring;

  /// ECG monitoring mode.
  final int ecgMonitoring;

  /// Pressure/stress monitoring mode.
  final int pressureMonitoring;

  /// Mood/emotion monitoring mode.
  final int moodMonitoring;

  /// Sleep monitoring mode.
  final int sleepMonitoring;

  /// Breath monitoring mode.
  final int breatheMonitoring;

  /// Whether heart rate is supported.
  final bool isHeartRateSupport;

  /// Touch configuration (0x00=none, 0x01=1-point, 0x02=2-point).
  final int isTouchSet;

  /// Whether wake by gesture is supported.
  final bool supportWakeupByGesture;

  /// SOS support (0x00=none, 0x01=basic, 0x02=advanced).
  final int supportSos;

  /// SOS trigger mode.
  final int sosTriggerMode;

  /// Vibration support (0x00=none, 0x01=v1, 0x02=v2).
  final int vibrate;

  /// Whether message notification is supported.
  final bool msgNotify;

  /// Sport version (0x00=none, 0x01=v1 6-axis, 0x02=v2 30-axis).
  final int sportVersion;

  /// Whether care reminder is supported.
  final bool careReminder;

  /// Whether ultraviolet sensor is supported.
  final bool supportUltraviolet;

  /// Whether voice recording is supported.
  final bool supportVoiceRecord;

  /// Whether BMI/body fat is supported.
  final bool supportBmi;

  const AizoDeviceConfig({
    this.heartRateMonitoring = 0,
    this.bloodOxygenMonitoring = 0,
    this.temperatureMonitoring = 0,
    this.bloodPressureMonitoring = 0,
    this.bloodSugarMonitoring = 0,
    this.ecgMonitoring = 0,
    this.pressureMonitoring = 0,
    this.moodMonitoring = 0,
    this.sleepMonitoring = 0,
    this.breatheMonitoring = 0,
    this.isHeartRateSupport = false,
    this.isTouchSet = 0,
    this.supportWakeupByGesture = false,
    this.supportSos = 0,
    this.sosTriggerMode = 0,
    this.vibrate = 0,
    this.msgNotify = false,
    this.sportVersion = 0,
    this.careReminder = false,
    this.supportUltraviolet = false,
    this.supportVoiceRecord = false,
    this.supportBmi = false,
  });

  factory AizoDeviceConfig.fromMap(Map<dynamic, dynamic> map) {
    return AizoDeviceConfig(
      heartRateMonitoring: map['heartRateMonitoring'] as int? ?? 0,
      bloodOxygenMonitoring: map['bloodOxygenMonitoring'] as int? ?? 0,
      temperatureMonitoring: map['temperatureMonitoring'] as int? ?? 0,
      bloodPressureMonitoring: map['bloodPressureMonitoring'] as int? ?? 0,
      bloodSugarMonitoring: map['bloodSugarMonitoring'] as int? ?? 0,
      ecgMonitoring: map['ecgMonitoring'] as int? ?? 0,
      pressureMonitoring: map['pressureMonitoring'] as int? ?? 0,
      moodMonitoring: map['moodMonitoring'] as int? ?? 0,
      sleepMonitoring: map['sleepMonitoring'] as int? ?? 0,
      breatheMonitoring: map['breatheMonitoring'] as int? ?? 0,
      isHeartRateSupport: (map['isHeartRateSupport'] as int? ?? 0) == 1,
      isTouchSet: map['isTouchSet'] as int? ?? 0,
      supportWakeupByGesture:
          (map['supportWakeupByGesture'] as int? ?? 0) == 1,
      supportSos: map['supportSos'] as int? ?? 0,
      sosTriggerMode: map['sosTriggerMode'] as int? ?? 0,
      vibrate: map['vibrate'] as int? ?? 0,
      msgNotify: (map['msgNotify'] as int? ?? 0) == 1,
      sportVersion: map['sportVersion'] as int? ?? 0,
      careReminder: (map['careReminder'] as int? ?? 0) == 1,
      supportUltraviolet: (map['supportUltraviolet'] as int? ?? 0) == 1,
      supportVoiceRecord: (map['supportVoiceRecord'] as int? ?? 0) == 1,
      supportBmi: (map['supportBmi'] as int? ?? 0) == 1,
    );
  }

  /// Whether instant measurement for a given type is likely supported.
  bool get supportsHeartRate => heartRateMonitoring != 0 || isHeartRateSupport;
  bool get supportsBloodOxygen => bloodOxygenMonitoring != 0;
  bool get supportsTemperature => temperatureMonitoring != 0;
  bool get supportsEcg => ecgMonitoring != 0;
  bool get supportsSleep => sleepMonitoring != 0;
}
