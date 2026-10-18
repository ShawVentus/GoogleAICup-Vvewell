import 'package:alloop/features/family/presentation/controllers/family_profile_controller.dart';
import 'package:alloop/features/nutrition_demo/presentation/nutrition_center_page.dart';
import 'package:alloop/features/nutrition_demo/presentation/nutrition_capture_sheet.dart';
import 'package:alloop/features/nutrition_demo/presentation/nutrition_demo_controller.dart';
import 'package:alloop/foundations/localization/app_localization.dart';
import 'package:alloop/foundations/ui/vvewell_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  late NutritionDemoController nutritionController;
  late FamilyProfileController familyController;

  setUp(() {
    Get.testMode = true;
    Get.put(AppLanguageController()..setEnglish(false));
    nutritionController = NutritionDemoController();
    familyController = FamilyProfileController();
  });

  tearDown(() {
    nutritionController.dispose();
    familyController.dispose();
    Get.reset();
  });

  Widget app() => GetMaterialApp(
    theme: vvewellTheme(),
    translations: VvewellTranslations(),
    locale: Get.find<AppLanguageController>().currentLocale.value,
    home: NutritionCenterPage(
      controller: nutritionController,
      familyProfileController: familyController,
    ),
  );

  testWidgets('nutrition center exposes assessment ai tracking and shop', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app());
    expect(find.text('针对睡眠风险的补剂候选'), findsOneWidget);

    await tester.tap(find.byKey(const Key('nutrition-tab-1')));
    await tester.pumpAndSettle();
    expect(find.text('AI 营养顾问'), findsOneWidget);
    expect(find.textContaining('优先通过食物改善营养'), findsOneWidget);

    await tester.tap(find.byKey(const Key('nutrition-tab-2')));
    await tester.pumpAndSettle();
    expect(find.text('今日补剂概览'), findsOneWidget);
    await tester.fling(
      find.byKey(const Key('nutrition-tracking-scroll')),
      const Offset(0, -1600),
      2200,
    );
    await tester.pumpAndSettle();
    final completeAll = find.byKey(const Key('complete-all-supplements'));
    tester.widget<ElevatedButton>(completeAll).onPressed!();
    await tester.pump();
    expect(nutritionController.completedPurchasedCount, 5);

    await tester.tap(find.byKey(const Key('nutrition-tab-3')));
    await tester.pumpAndSettle();
    expect(find.text('补剂商城'), findsOneWidget);
    final addToCart = find.byKey(const Key('add-to-cart-d3'));
    tester.widget<IconButton>(addToCart).onPressed!();
    await tester.pump();
    expect(nutritionController.cartCount, 1);
  });

  testWidgets('nutrition center has no overflow at 320px on every tab', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(app());
    for (var index = 0; index < 4; index++) {
      await tester.tap(find.byKey(Key('nutrition-tab-$index')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'English nutrition tabs translate all visible text without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Get.find<AppLanguageController>().setEnglish(true);

      await tester.pumpWidget(app());
      await tester.pump();

      final chinese = RegExp(r'[\u3400-\u9fff]');
      void audit(String location) {
        final untranslated = tester
            .widgetList<Text>(find.byType(Text))
            .map(
              (widget) => widget.data ?? widget.textSpan?.toPlainText() ?? '',
            )
            .where(chinese.hasMatch)
            .where((text) => !text.contains('王国良'))
            .toSet();
        expect(untranslated, isEmpty, reason: '$location left Chinese visible');
        expect(tester.takeException(), isNull, reason: '$location overflowed');
      }

      const scrollKeys = [
        Key('nutrition-assessment-scroll'),
        Key('nutrition-ai-scroll'),
        Key('nutrition-tracking-scroll'),
        Key('nutrition-shop-scroll'),
      ];
      for (var index = 0; index < scrollKeys.length; index++) {
        await tester.tap(find.byKey(Key('nutrition-tab-$index')));
        await tester.pumpAndSettle();
        audit('Nutrition tab $index top');

        final scrollable = find.descendant(
          of: find.byKey(scrollKeys[index]),
          matching: find.byType(Scrollable),
        );
        final state = tester.state<ScrollableState>(scrollable.first);
        final max = state.position.maxScrollExtent;
        for (double offset = 280; offset < max; offset += 280) {
          state.position.jumpTo(offset);
          await tester.pump();
          audit('Nutrition tab $index offset ${offset.round()}');
        }
        state.position.jumpTo(max);
        await tester.pump();
        audit('Nutrition tab $index bottom');
      }
    },
  );

  testWidgets(
    'English meal upload sheet translates all content without overflow',
    (tester) async {
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
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showNutritionCaptureSheet(
                  context,
                  controller: nutritionController,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final chinese = RegExp(r'[\u3400-\u9fff]');
      final untranslated = tester
          .widgetList<Text>(find.byType(Text))
          .map((widget) => widget.data ?? widget.textSpan?.toPlainText() ?? '')
          .where(chinese.hasMatch)
          .toSet();
      expect(untranslated, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
