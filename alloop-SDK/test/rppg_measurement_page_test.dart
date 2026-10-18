import 'dart:async';

import 'package:alloop/features/rppg/data/rppg_platform_client.dart';
import 'package:alloop/features/rppg/domain/models/rppg_session_result.dart';
import 'package:alloop/features/rppg/presentation/pages/rppg_measurement_page.dart';
import 'package:alloop/foundations/localization/app_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  setUp(() {
    Get.testMode = true;
    Get.put(AppLanguageController());
  });

  tearDown(Get.reset);

  Widget app(RppgPlatformClient client) => GetMaterialApp(
    translations: VvewellTranslations(),
    locale: Get.find<AppLanguageController>().currentLocale.value,
    home: RppgMeasurementPage(client: client),
  );

  testWidgets('rapid start taps launch only one native measurement', (
    tester,
  ) async {
    final client = _DelayedRppgClient();
    await tester.pumpWidget(app(client));

    final startButton = find.widgetWithText(FilledButton, '开始测量');
    await tester.tap(startButton, warnIfMissed: false);
    await tester.tap(startButton, warnIfMissed: false);
    await tester.pump();

    expect(client.startCount, 1);

    client.complete();
    await tester.pumpAndSettle();

    expect(client.startCount, 1);
    expect(find.text('测量已取消'), findsOneWidget);
  });

  testWidgets('English rPPG states and results translate without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Get.find<AppLanguageController>().setEnglish(true);
    final client = _DelayedRppgClient();

    await tester.pumpWidget(app(client));
    await tester.pump();
    expect(find.text('Phone rPPG ready'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.widgetWithText(FilledButton, 'Start measurement'));
    await tester.pump();
    client.complete();
    await tester.pumpAndSettle();

    final chinese = RegExp(r'[\u3400-\u9fff]');
    final untranslated = tester
        .widgetList<Text>(find.byType(Text))
        .map((widget) => widget.data ?? widget.textSpan?.toPlainText() ?? '')
        .where(chinese.hasMatch)
        .toSet();
    expect(untranslated, isEmpty);
    expect(find.text('Measurement cancelled'), findsOneWidget);
    expect(find.text('Final result'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _DelayedRppgClient extends RppgPlatformClient {
  _DelayedRppgClient();

  final _result = Completer<RppgSessionResult>();
  int startCount = 0;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<RppgSessionResult> startMeasurement() {
    startCount += 1;
    return _result.future;
  }

  void complete() {
    final now = DateTime.utc(2026, 8, 4);
    _result.complete(
      RppgSessionResult(
        sessionId: 'test-session',
        startedAt: now,
        completedAt: now,
        source: RppgSessionResult.expectedSource,
        deviceId: 'phone_camera',
        schemaVersion: 1,
        completionReason: 'cancelled',
        demoOnly: false,
        estimateSamples: const [],
        summary: const RppgEstimateSummary(
          heartRate: null,
          heartRateConfidence: 0,
          respiratoryRate: null,
          respiratoryRateConfidence: 0,
          aggregateQuality: 0,
        ),
      ),
    );
  }
}
