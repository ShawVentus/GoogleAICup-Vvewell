import 'package:alloop/main_web.dart';
import 'package:alloop/foundations/localization/app_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  setUp(() {
    Get.testMode = true;
    Get.put(
      AppLanguageController()..currentLocale.value = const Locale('en', 'US'),
    );
  });
  tearDown(() => Get.reset());

  testWidgets('primary web pages render English interface text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const WebApp());
    final untranslated = <int, Set<String>>{};
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byKey(Key('bottom-nav-$i')));
      await tester.pump(const Duration(milliseconds: 500));
      if (i == 0) expect(find.byIcon(Icons.language_outlined), findsNothing);
      final chinese = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
          .where((s) => RegExp(r'[\u4e00-\u9fff]').hasMatch(s))
          .toSet();
      if (chinese.isNotEmpty) untranslated[i] = chinese;
      expect(tester.takeException(), isNull);
    }
    if (untranslated.isNotEmpty) print('UNTRANSLATED: $untranslated');
    expect(
      untranslated,
      isEmpty,
      reason: 'Untranslated interface text: $untranslated',
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
