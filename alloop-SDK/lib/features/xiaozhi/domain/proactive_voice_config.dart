/// Configuration for XiaoZhi's companion-app initiated conversations.
///
/// The defaults intentionally favour frequent friendly check-ins while still
/// avoiding repeated health alerts and late-night greetings.
class ProactiveVoiceConfig {
  const ProactiveVoiceConfig({
    this.enabled = true,
    this.heartRateLow = 50,
    this.heartRateHigh = 120,
    this.spo2Low = 92,
    this.healthAlertCooldown = const Duration(minutes: 15),
    this.hourlyGreetingEnabled = true,
    this.scheduledGreetingMinutes = const <int>[],
    this.quietHoursStart = 22 * 60,
    this.quietHoursEnd = 7 * 60,
  })  : assert(heartRateLow >= 30 && heartRateLow < heartRateHigh),
        assert(heartRateHigh <= 220),
        assert(spo2Low >= 70 && spo2Low <= 100),
        assert(quietHoursStart >= 0 && quietHoursStart < 24 * 60),
        assert(quietHoursEnd >= 0 && quietHoursEnd < 24 * 60);

  final bool enabled;
  final int heartRateLow;
  final int heartRateHigh;
  final int spo2Low;
  final Duration healthAlertCooldown;
  final bool hourlyGreetingEnabled;

  /// Local minutes after midnight, kept sorted and unique by [normalized].
  final List<int> scheduledGreetingMinutes;
  final int quietHoursStart;
  final int quietHoursEnd;

  List<int> get normalizedScheduledGreetingMinutes {
    final values = scheduledGreetingMinutes
        .where((minute) => minute >= 0 && minute < 24 * 60)
        .toSet()
        .toList()
      ..sort();
    return values;
  }

  bool isQuietAt(DateTime time) {
    if (quietHoursStart == quietHoursEnd) return false;
    final minute = time.hour * 60 + time.minute;
    if (quietHoursStart < quietHoursEnd) {
      return minute >= quietHoursStart && minute < quietHoursEnd;
    }
    return minute >= quietHoursStart || minute < quietHoursEnd;
  }

  ProactiveVoiceConfig copyWith({
    bool? enabled,
    int? heartRateLow,
    int? heartRateHigh,
    int? spo2Low,
    Duration? healthAlertCooldown,
    bool? hourlyGreetingEnabled,
    List<int>? scheduledGreetingMinutes,
    int? quietHoursStart,
    int? quietHoursEnd,
  }) =>
      ProactiveVoiceConfig(
        enabled: enabled ?? this.enabled,
        heartRateLow: heartRateLow ?? this.heartRateLow,
        heartRateHigh: heartRateHigh ?? this.heartRateHigh,
        spo2Low: spo2Low ?? this.spo2Low,
        healthAlertCooldown: healthAlertCooldown ?? this.healthAlertCooldown,
        hourlyGreetingEnabled:
            hourlyGreetingEnabled ?? this.hourlyGreetingEnabled,
        scheduledGreetingMinutes:
            scheduledGreetingMinutes ?? this.scheduledGreetingMinutes,
        quietHoursStart: quietHoursStart ?? this.quietHoursStart,
        quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
      );

  /// Parses an editable comma-separated list such as `08:30, 12:00, 20:15`.
  static List<int> parseScheduledGreetingTimes(String value) {
    final minutes = <int>{};
    for (final part in value.split(',')) {
      final match = RegExp(r'^\s*(\d{1,2}):(\d{2})\s*$').firstMatch(part);
      if (match == null) continue;
      final hour = int.tryParse(match.group(1)!);
      final minute = int.tryParse(match.group(2)!);
      if (hour == null || minute == null || hour > 23 || minute > 59) continue;
      minutes.add(hour * 60 + minute);
    }
    return minutes.toList()..sort();
  }

  static String formatScheduledGreetingTimes(Iterable<int> minutes) {
    final values = minutes
        .where((minute) => minute >= 0 && minute < 24 * 60)
        .toSet()
        .toList()
      ..sort();
    return values
        .map(
          (minute) =>
              '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}',
        )
        .join(', ');
  }
}

/// The specific medical value that made a reading worthy of a spoken nudge.
enum ProactiveVitalAlertType { heartRateLow, heartRateHigh, spo2Low }

class ProactiveVitalAlert {
  const ProactiveVitalAlert(this.type, this.value);

  final ProactiveVitalAlertType type;
  final double value;
}

/// Returns only physiologically plausible, configured-out-of-range values.
///
/// Placeholder values from devices are commonly below these ranges, so they
/// must not be turned into an alarming speech prompt.
List<ProactiveVitalAlert> detectProactiveVitalAlerts({
  required ProactiveVoiceConfig config,
  required bool isValid,
  double? heartRate,
  double? spo2,
}) {
  if (!isValid) return const [];
  final alerts = <ProactiveVitalAlert>[];
  if (heartRate != null && heartRate.isFinite && heartRate >= 30 && heartRate <= 220) {
    if (heartRate <= config.heartRateLow) {
      alerts.add(ProactiveVitalAlert(ProactiveVitalAlertType.heartRateLow, heartRate));
    } else if (heartRate >= config.heartRateHigh) {
      alerts.add(ProactiveVitalAlert(ProactiveVitalAlertType.heartRateHigh, heartRate));
    }
  }
  if (spo2 != null && spo2.isFinite && spo2 >= 70 && spo2 <= 100 && spo2 <= config.spo2Low) {
    alerts.add(ProactiveVitalAlert(ProactiveVitalAlertType.spo2Low, spo2));
  }
  return alerts;
}
