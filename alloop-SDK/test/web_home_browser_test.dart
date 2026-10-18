import 'package:alloop/main_web.dart';
import 'package:alloop/foundations/localization/app_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  setUp(() {
    Get.testMode = true;
    Get.put(AppLanguageController()..currentLocale.value = const Locale('en', 'US'));
  });
  tearDown(() { Get.reset(); });

  testWidgets('web preview opens the original panda and all five primary pages without login', (tester) async {
    await tester.pumpWidget(const WebApp());
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('panda-avatar-stable-frame')), findsOneWidget);
    expect(find.textContaining('Includes original sample data'), findsOneWidget);
    expect(find.text('Find a doctor'), findsOneWidget);
    for (var index = 0; index < 5; index++) {
      await tester.tap(find.byKey(Key('bottom-nav-$index')));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull, reason: 'Primary tab $index');
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
