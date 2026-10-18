import 'package:alloop/features/xiaozhi/domain/proactive_voice_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const config = ProactiveVoiceConfig();

  test('only plausible out-of-range vital readings create alerts', () {
    final alerts = detectProactiveVitalAlerts(
      config: config,
      isValid: true,
      heartRate: 128,
      spo2: 91,
    );

    expect(
      alerts.map((alert) => alert.type),
      containsAll(<ProactiveVitalAlertType>[
        ProactiveVitalAlertType.heartRateHigh,
        ProactiveVitalAlertType.spo2Low,
      ]),
    );
    expect(
      detectProactiveVitalAlerts(
        config: config,
        isValid: true,
        heartRate: 12,
        spo2: 55,
      ),
      isEmpty,
    );
    expect(
      detectProactiveVitalAlerts(
        config: config,
        isValid: false,
        heartRate: 130,
      ),
      isEmpty,
    );
  });

  test('quiet-hours and custom greeting times handle midnight correctly', () {
    const quietConfig = ProactiveVoiceConfig(
      quietHoursStart: 22 * 60,
      quietHoursEnd: 7 * 60,
    );

    expect(quietConfig.isQuietAt(DateTime(2026, 8, 3, 23, 30)), isTrue);
    expect(quietConfig.isQuietAt(DateTime(2026, 8, 4, 6, 59)), isTrue);
    expect(quietConfig.isQuietAt(DateTime(2026, 8, 4, 7)), isFalse);
    expect(
      ProactiveVoiceConfig.parseScheduledGreetingTimes('08:30, 12:00, 08:30, bad'),
      <int>[510, 720],
    );
    expect(
      ProactiveVoiceConfig.formatScheduledGreetingTimes(<int>[720, 510]),
      '08:30, 12:00',
    );
  });
}
