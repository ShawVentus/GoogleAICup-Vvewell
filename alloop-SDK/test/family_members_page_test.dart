import 'package:alloop/features/family/presentation/controllers/family_profile_controller.dart';
import 'package:alloop/features/family/presentation/pages/family_members_page.dart';
import 'package:alloop/features/family/presentation/pages/health_record_page.dart';
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

  tearDown(Get.reset);

  Widget app(Widget home) => GetMaterialApp(
    theme: vvewellTheme(),
    translations: VvewellTranslations(),
    locale: Get.find<AppLanguageController>().currentLocale.value,
    home: home,
  );

  testWidgets('family member form adds and selects the new profile', (
    tester,
  ) async {
    final controller = FamilyProfileController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(app(FamilyMembersPage(controller: controller)));

    await tester.tap(find.byKey(const Key('add-family-member')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('family-member-name')), '李敏');
    await tester.enterText(
      find.byKey(const Key('family-member-birth-year')),
      '1990',
    );
    final authorization = find.widgetWithText(
      CheckboxListTile,
      '我已获得该成员授权，或拥有合法代理权限',
    );
    await tester.ensureVisible(authorization);
    await tester.tap(authorization);
    await tester.pump();
    final submit = find.byKey(const Key('submit-family-member'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(controller.members, hasLength(2));
    expect(controller.activeMember.name, '李敏');
    expect(find.text('李敏'), findsWidgets);
  });

  testWidgets('English family pages and form contain no Chinese or overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Get.find<AppLanguageController>().setEnglish(true);
    final controller = FamilyProfileController();
    addTearDown(controller.dispose);
    final chinese = RegExp(r'[\u3400-\u9fff]');

    void audit(String page) {
      final untranslated = tester
          .widgetList<Text>(find.byType(Text))
          .map((widget) => widget.data ?? widget.textSpan?.toPlainText() ?? '')
          .where(chinese.hasMatch)
          .where((text) => !text.contains('王国良'))
          .toSet();
      expect(untranslated, isEmpty, reason: '$page left Chinese visible');
      expect(tester.takeException(), isNull, reason: '$page overflowed');
    }

    await tester.pumpWidget(app(FamilyMembersPage(controller: controller)));
    await tester.pump();
    audit('Family members');

    await tester.tap(find.byKey(const Key('add-family-member')));
    await tester.pumpAndSettle();
    audit('Add family member form');

    await tester.pumpWidget(app(HealthRecordPage(controller: controller)));
    await tester.pump();
    audit('Health record');
  });

  testWidgets('health record shows mock dynamic tags as a compact legend', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = FamilyProfileController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(app(HealthRecordPage(controller: controller)));
    await tester.pump();

    expect(find.byKey(const Key('health-tag-legend')), findsOneWidget);
    for (final tag in controller.activeMember.tags) {
      final legendItem = find.byKey(Key('health-tag-legend-${tag.id}'));
      expect(legendItem, findsOneWidget);
      expect(
        find.descendant(of: legendItem, matching: find.text(tag.label)),
        findsOneWidget,
      );
    }
    expect(tester.takeException(), isNull);
  });
}
