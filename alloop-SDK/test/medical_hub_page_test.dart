import 'package:alloop/features/family/presentation/controllers/family_profile_controller.dart';
import 'package:alloop/features/medical/presentation/medical_hub_page.dart';
import 'package:alloop/foundations/ui/vvewell_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FamilyProfileController controller;

  setUp(() => controller = FamilyProfileController());
  tearDown(() => controller.dispose());

  Widget app() => MaterialApp(
    theme: vvewellTheme(),
    home: Scaffold(
      body: SafeArea(
        child: MedicalHubPage(
          familyProfileController: controller,
          header: const SizedBox(height: 1),
        ),
      ),
    ),
  );

  testWidgets('medical hub exposes referral, insurance and community tabs', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    expect(find.text('选择一个主服务'), findsOneWidget);

    await tester.tap(find.byKey(const Key('medical-hub-tab-1')));
    await tester.pumpAndSettle();
    expect(find.text('家庭保障规划'), findsOneWidget);
    expect(find.text('保障缺口分析'), findsOneWidget);

    await tester.tap(find.byKey(const Key('medical-hub-tab-2')));
    await tester.pumpAndSettle();
    expect(find.text('康友社区'), findsWidgets);
    expect(find.byKey(const Key('community-search')), findsOneWidget);
  });

  testWidgets('referral intake creates a visible journey', (tester) async {
    await tester.pumpWidget(app());
    await tester.tap(find.byKey(const Key('start-referral')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('referral-complaint')),
      '反复胸闷两周，希望进一步评估',
    );
    final identity = find.widgetWithText(CheckboxListTile, 'Confirm the patient is 王国良');
    await tester.ensureVisible(identity);
    await tester.tap(identity);
    final consent = find.widgetWithText(
      CheckboxListTile,
      'I consent to the minimum necessary information being used for referral assessment and care coordination',
    );
    await tester.ensureVisible(consent);
    await tester.tap(consent);
    final submit = find.byKey(const Key('submit-referral-intake'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(find.text('Initial review'), findsOneWidget);
    expect(find.textContaining('Advisor review expected within one business day'), findsOneWidget);
  });

  testWidgets('joining a disease community requires explicit consent', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.tap(find.byKey(const Key('medical-hub-tab-2')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('join-community-breast-cancer')));
    await tester.pumpAndSettle();
    final joinButton = find.widgetWithText(ElevatedButton, '使用匿名别名加入');
    expect(tester.widget<ElevatedButton>(joinButton).onPressed, isNull);

    await tester.tap(
      find.widgetWithText(CheckboxListTile, '我已阅读社区规则和隐私说明，并同意加入'),
    );
    await tester.pump();
    expect(tester.widget<ElevatedButton>(joinButton).onPressed, isNotNull);
    await tester.tap(joinButton);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('join-community-breast-cancer')),
      findsOneWidget,
    );
    expect(find.text('已加入'), findsWidgets);
  });

  testWidgets('licensed advisor action opens and submits contact form', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app());
    await tester.tap(find.byKey(const Key('medical-hub-tab-1')));
    await tester.pumpAndSettle();

    final advisor = find.byKey(
      const Key('advisor-contact-Premium Health Shield'),
    );
    final advisorButton = tester.widget<ElevatedButton>(advisor);
    expect(advisorButton.onPressed, isNotNull);
    advisorButton.onPressed!();
    await tester.pumpAndSettle();

    expect(find.text('预约具名持牌顾问复核'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('advisor-contact-phone')),
      '13800138000',
    );
    final consent = find.byKey(const Key('advisor-contact-consent'));
    tester.widget<CheckboxListTile>(consent).onChanged!(true);
    await tester.pump();
    final submit = find.byKey(const Key('submit-advisor-contact'));
    tester.widget<ElevatedButton>(submit).onPressed!();
    await tester.pumpAndSettle();

    expect(find.textContaining('回访申请已提交'), findsOneWidget);
    expect(find.text('预约具名持牌顾问复核'), findsNothing);
  });

  testWidgets('provider filters rerank locations and departments', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app());
    final location = find.byKey(const Key('provider-location-filter'));
    expect(find.text('最优推荐'), findsOneWidget);
    tester.widget<DropdownButtonFormField<String>>(location).onChanged!('上海');
    await tester.pump();

    final department = find.byKey(const Key('provider-department-filter'));
    tester.widget<DropdownButtonFormField<String>>(department).onChanged!(
      '呼吸与睡眠',
    );
    await tester.pump();

    expect(find.text('上海交通大学医学院附属瑞金医院 · 呼吸与睡眠'), findsOneWidget);
    expect(find.text('标签匹配 96%'), findsOneWidget);
  });

  testWidgets('medical hub has no overflow at 320px', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(app());
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('medical-hub-scroll-view')), findsOneWidget);
  });
}
