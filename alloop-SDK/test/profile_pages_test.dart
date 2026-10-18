import 'package:alloop/features/profile/presentation/pages/benefits_page.dart';
import 'package:alloop/features/profile/presentation/pages/language_settings_page.dart';
import 'package:alloop/features/profile/presentation/pages/notification_settings_page.dart';
import 'package:alloop/features/profile/presentation/pages/orders_page.dart';
import 'package:alloop/foundations/localization/app_localization.dart';
import 'package:alloop/foundations/ui/vvewell_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  setUp(() {
    Get.testMode = true;
    Get.put(AppLanguageController()..setEnglish(false));
  });

  tearDown(() {
    Get.locale = const Locale('zh', 'CN');
    Get.reset();
  });

  Widget app(Widget page) {
    final controller = Get.find<AppLanguageController>();
    return Obx(
      () => GetMaterialApp(
        theme: vvewellTheme(),
        translations: VvewellTranslations(),
        locale: controller.currentLocale.value,
        home: page,
      ),
    );
  }

  test('English catalog contains no untranslated Chinese text', () {
    final english = VvewellTranslations().keys['en_US']!;
    final chinese = RegExp(r'[\u3400-\u9fff]');

    expect(
      english.entries.where((entry) => chinese.hasMatch(entry.value)),
      isEmpty,
    );
  });

  testWidgets('orders expose mock order states and actions', (tester) async {
    await tester.pumpWidget(app(const OrdersPage()));
    await tester.pumpAndSettle();

    expect(find.text('Alloop Ring 健康套装'), findsOneWidget);
    expect(find.text('跨境医疗专家会诊'), findsOneWidget);
    expect(find.text('待付款'), findsWidgets);
    expect(find.text('去付款'), findsOneWidget);
  });

  testWidgets('benefits page follows member, task, and points hierarchy', (
    tester,
  ) async {
    await tester.pumpWidget(app(const BenefitsPage()));
    await tester.pumpAndSettle();

    expect(find.text('2,380'), findsOneWidget);
    expect(find.text('AI 健康咨询'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('每日任务'),
      420,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('每日任务'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('积分记录'),
      420,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('积分记录'), findsOneWidget);
  });

  testWidgets('notification switches and English mode are interactive', (
    tester,
  ) async {
    await tester.pumpWidget(app(const NotificationSettingsPage()));
    await tester.pumpAndSettle();
    final switches = find.byType(Switch);
    expect(switches, findsAtLeastNWidgets(6));
    await tester.tap(switches.first);
    await tester.pump();
    expect(tester.widget<Switch>(switches.first).value, isFalse);

    await tester.pumpWidget(app(const LanguageSettingsPage()));
    await tester.pumpAndSettle();
    final languageControl = find.byType(SegmentedButton<bool>);
    expect(
      tester.widget<SegmentedButton<bool>>(languageControl).onSelectionChanged,
      isNotNull,
    );
    Get.find<AppLanguageController>().setEnglish(true);
    await tester.pump();
    expect(Get.find<AppLanguageController>().isEnglish, isTrue);
  });

  testWidgets('English mode updates translated shell copy', (tester) async {
    final controller = Get.find<AppLanguageController>();
    await tester.pumpWidget(
      Obx(
        () => GetMaterialApp(
          translations: VvewellTranslations(),
          locale: controller.currentLocale.value,
          home: const _TranslatedHomeLabel(),
        ),
      ),
    );
    expect(find.text('首页'), findsOneWidget);

    controller.setEnglish(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(Get.locale?.languageCode, 'en');
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('English profile pages show complete text without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Get.find<AppLanguageController>().setEnglish(true);

    for (final page in const [
      NotificationSettingsPage(),
      OrdersPage(),
      BenefitsPage(),
    ]) {
      await tester.pumpWidget(app(page));
      await tester.pumpAndSettle();

      final visibleText = tester
          .widgetList<Text>(find.byType(Text))
          .map((widget) => widget.data ?? widget.textSpan?.toPlainText() ?? '')
          .where((text) => text.isNotEmpty);
      expect(
        visibleText.where(RegExp(r'[\u3400-\u9fff]').hasMatch),
        isEmpty,
        reason: '${page.runtimeType} left Chinese text visible in English mode',
      );
      expect(tester.takeException(), isNull);
    }
  });
}

class _TranslatedHomeLabel extends StatelessWidget {
  const _TranslatedHomeLabel();

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AppLanguageController>();
    return Obx(() {
      controller.currentLocale.value;
      return Scaffold(body: Center(child: Text('首页'.tr)));
    });
  }
}
