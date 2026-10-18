import 'package:alloop/features/health_score/presentation/health_score_card.dart';
import 'package:alloop/foundations/ui/vvewell_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('alloop/local_health_database');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('health card shows fused age metrics without old disclaimer', (
    tester,
  ) async {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          return switch (call.method) {
            'loadVitalReadings' => [
              {
                'recorded_at': yesterday.millisecondsSinceEpoch,
                'is_valid': 1,
                'hrv': 42.0,
                'stress': 44.0,
                'steps': 4100,
              },
              {
                'recorded_at': now.millisecondsSinceEpoch,
                'is_valid': 1,
                'hrv': 56.0,
                'stress': 28.0,
                'steps': 6900,
              },
            ],
            'loadHealthInterventions' => <Object?>[],
            _ => null,
          };
        });

    await tester.pumpWidget(
      MaterialApp(
        theme: vvewellTheme(),
        home: const Scaffold(
          body: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: HealthScoreCard(actualAge: 38),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byKey(const Key('health-age-fusion-panel')), findsOneWidget);
    expect(find.text('实际年龄'), findsOneWidget);
    expect(find.text('生理年龄'), findsOneWidget);
    expect(find.text('衰老速度'), findsWidgets);
    expect(find.textContaining('不是生理年龄检测'), findsNothing);
  });
}
