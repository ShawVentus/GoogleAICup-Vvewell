import 'package:alloop/features/common/presentation/controllers/connected_device_registry.dart';
import 'package:alloop/features/main/device_center_page.dart';
import 'package:alloop/foundations/localization/app_localization.dart';
import 'package:alloop/foundations/ui/vvewell_theme.dart';
import 'package:alloop_blue_lite/alloop_blue_lite.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  setUp(() {
    Get.testMode = true;
    Get.put(AppLanguageController());
    ConnectedDeviceRegistry.instance.clear();
  });

  tearDown(() {
    ConnectedDeviceRegistry.instance.clear();
    Get.reset();
  });

  testWidgets('English device center tabs contain no Chinese or overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Get.find<AppLanguageController>().setEnglish(true);

    await tester.pumpWidget(
      GetMaterialApp(
        theme: vvewellTheme(),
        translations: VvewellTranslations(),
        locale: Get.find<AppLanguageController>().currentLocale.value,
        home: DeviceCenterPage(
          connectedDevicesStream: Stream.value(const <LiteDevice>[]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final chinese = RegExp(r'[\u3400-\u9fff]');
    void audit(String tab) {
      final untranslated = tester
          .widgetList<Text>(find.byType(Text))
          .map((widget) => widget.data ?? widget.textSpan?.toPlainText() ?? '')
          .where(chinese.hasMatch)
          .toSet();
      expect(untranslated, isEmpty, reason: '$tab left Chinese visible');
      expect(tester.takeException(), isNull, reason: '$tab overflowed');
    }

    audit('My devices');
    await tester.tap(find.text('Hardware shop'));
    await tester.pump();
    audit('Hardware shop');
  });
}
