import 'package:alloop/features/family/presentation/controllers/family_profile_controller.dart';
import 'package:alloop/features/family/presentation/pages/family_members_page.dart';
import 'package:alloop/features/family/presentation/pages/health_record_page.dart';
import 'package:alloop/features/nutrition_demo/presentation/nutrition_center_page.dart';
import 'package:alloop/features/nutrition_demo/presentation/nutrition_demo_controller.dart';
import 'package:alloop/features/profile/presentation/pages/benefits_page.dart';
import 'package:alloop/features/profile/presentation/pages/language_settings_page.dart';
import 'package:alloop/features/profile/presentation/pages/notification_settings_page.dart';
import 'package:alloop/features/profile/presentation/pages/orders_page.dart';
import 'package:alloop/features/rppg/presentation/pages/rppg_measurement_page.dart';
import 'package:alloop/features/women_health/presentation/women_health_panel.dart';
import 'package:alloop/foundations/localization/app_localization.dart';
import 'package:alloop/foundations/ui/vvewell_theme.dart';
import 'package:alloop/main_web.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const database = MethodChannel('alloop/local_health_database');

  setUp(() {
    Get.testMode = true;
    Get.put(AppLanguageController(), permanent: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(database, (call) async => <Object?>[]);
  });
  tearDown(() {
    Get.reset();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(database, null);
  });

  test('new app sessions default to English', () {
    final language = Get.find<AppLanguageController>();
    expect(language.currentLocale.value, const Locale('en', 'US'));
    expect(language.isEnglish, isTrue);
  });

  void audit(WidgetTester tester, String page) {
    final strings = <String>[
      ...tester.widgetList<Text>(find.byType(Text)).map(
        (text) => text.data ?? text.textSpan?.toPlainText() ?? '',
      ),
      ...tester.widgetList<Tooltip>(find.byType(Tooltip)).map(
        (tooltip) => tooltip.message ?? '',
      ),
      ...tester.widgetList<TextField>(find.byType(TextField)).expand(
        (field) => [
          field.decoration?.labelText ?? '',
          field.decoration?.hintText ?? '',
          field.decoration?.helperText ?? '',
        ],
      ),
    ];
    expect(
      strings.where(RegExp(r'[\u3400-\u9fff]').hasMatch).toSet(),
      isEmpty,
      reason: '$page contains untranslated interface text',
    );
    expect(tester.takeException(), isNull, reason: '$page layout');
  }

  for (final width in [320.0, 390.0]) {
    testWidgets('native primary tabs are English at ${width}px', (tester) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const WebApp());
      await tester.pump(const Duration(milliseconds: 500));
      for (var tab = 0; tab < 5; tab++) {
        await tester.tap(find.byKey(Key('bottom-nav-$tab')));
        await tester.pump(const Duration(milliseconds: 500));
        audit(tester, 'tab $tab at $width');
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('secondary pages are English at ${width}px', (tester) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final family = FamilyProfileController();
      final nutrition = NutritionDemoController();
      addTearDown(family.dispose);
      addTearDown(nutrition.dispose);
      final pages = <Widget>[
        const LanguageSettingsPage(),
        const OrdersPage(),
        const BenefitsPage(),
        const NotificationSettingsPage(),
        FamilyMembersPage(controller: family),
        HealthRecordPage(controller: family),
        const RppgMeasurementPage(),
        const Scaffold(body: SingleChildScrollView(child: WomenHealthPanel())),
        for (var tab = 0; tab < 4; tab++)
          NutritionCenterPage(
            controller: nutrition,
            familyProfileController: family,
            initialTab: tab,
          ),
      ];
      for (final page in pages) {
        await tester.pumpWidget(GetMaterialApp(
          key: UniqueKey(),
          translations: VvewellTranslations(),
          locale: Get.find<AppLanguageController>().currentLocale.value,
          fallbackLocale: const Locale('en', 'US'),
          theme: vvewellTheme(),
          home: page,
        ));
        await tester.pump(const Duration(milliseconds: 500));
        audit(tester, '${page.runtimeType} at $width');
        final scrolls = find.byType(Scrollable);
        if (scrolls.evaluate().isNotEmpty) {
          await tester.drag(scrolls.first, const Offset(0, -600));
          await tester.pump(const Duration(milliseconds: 500));
          audit(tester, '${page.runtimeType} scrolled at $width');
        }
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }
}
