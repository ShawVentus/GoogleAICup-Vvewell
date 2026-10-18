import 'package:alloop/features/avatar_coach/data/mock_avatar_coach_service.dart';
import 'package:alloop/features/avatar_coach/presentation/controllers/avatar_coach_controller.dart';
import 'package:alloop/features/family/domain/family_member.dart';
import 'package:alloop/features/family/presentation/controllers/family_profile_controller.dart';
import 'package:alloop/features/health_reports/data/medical_report_store.dart';
import 'package:alloop/features/main/home_page.dart';
import 'package:alloop/foundations/localization/app_localization.dart';
import 'package:alloop/foundations/ui/vvewell_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  late AvatarCoachController controller;

  setUp(() {
    Get.testMode = true;
    controller = AvatarCoachController();
    Get.put(AppLanguageController());
  });

  tearDown(() {
    controller.onClose();
    Get.reset();
  });

  Widget app() => GetMaterialApp(
    theme: vvewellTheme(),
    translations: VvewellTranslations(),
    locale: Get.find<AppLanguageController>().currentLocale.value,
    home: HomePage(avatarCoachController: controller),
  );

  testWidgets('language icon toggles immediately without opening settings', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pump();

    expect(Get.find<AppLanguageController>().isEnglish, isFalse);
    await tester.tap(find.byIcon(Icons.language_outlined).first);
    await tester.pump();

    expect(Get.find<AppLanguageController>().isEnglish, isTrue);
    expect(Get.currentRoute, isNot('/languageSettings'));
    expect(find.text('Good evening'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.language_outlined).first);
    await tester.pump();
    expect(Get.find<AppLanguageController>().isEnglish, isFalse);
    expect(find.text('晚上好'), findsOneWidget);
  });

  testWidgets('English primary tabs contain no visible Chinese or overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Get.find<AppLanguageController>().setEnglish(true);
    await tester.pumpWidget(app());
    await tester.pump();

    final chinese = RegExp(r'[\u3400-\u9fff]');
    const originalData = {'王国良'};
    void audit(int index, String location) {
      final untranslated = tester
          .widgetList<Text>(find.byType(Text))
          .map((widget) => widget.data ?? widget.textSpan?.toPlainText() ?? '')
          .where(chinese.hasMatch)
          .where((text) => !originalData.any(text.contains))
          .toSet();
      if (untranslated.isNotEmpty) {
        fail(
          'Bottom tab $index $location left untranslated text visible:\n'
          '${untranslated.join('\n')}',
        );
      }
      expect(
        tester.takeException(),
        isNull,
        reason: 'Bottom tab $index $location overflowed in English mode',
      );
    }

    for (var index = 0; index < 5; index++) {
      await tester.tap(find.byKey(Key('bottom-nav-$index')));
      await tester.pump();
      audit(index, 'top');

      final verticalScrolls = tester
          .stateList<ScrollableState>(find.byType(Scrollable))
          .where(
            (state) =>
                state.position.axisDirection == AxisDirection.down ||
                state.position.axisDirection == AxisDirection.up,
          )
          .where((state) => state.position.maxScrollExtent > 0)
          .toList();
      if (verticalScrolls.isEmpty) continue;
      verticalScrolls.sort(
        (a, b) =>
            b.position.maxScrollExtent.compareTo(a.position.maxScrollExtent),
      );
      final position = verticalScrolls.first.position;
      final max = position.maxScrollExtent;
      for (double offset = 320; offset < max; offset += 320) {
        position.jumpTo(offset);
        await tester.pump();
        audit(index, 'offset ${offset.round()}');
      }
      position.jumpTo(max);
      await tester.pump();
      audit(index, 'bottom');
    }
  });

  testWidgets('default sleepy fixture and W coach toggle work', (tester) async {
    await tester.pumpWidget(app());
    await tester.pump();

    expect(
      find.text(MockAvatarCoachService.defaultSleepyMessage),
      findsOneWidget,
    );
    expect(find.text('需要关注'), findsOneWidget);

    await tester.tap(find.byKey(const Key('coach-toggle')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      find.text(MockAvatarCoachService.defaultSleepyMessage),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('coach-toggle')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      find.text(MockAvatarCoachService.defaultSleepyMessage),
      findsOneWidget,
    );
  });

  testWidgets('warning risk is placed before coach and ordinary content', (
    tester,
  ) async {
    controller.switchFixture(AvatarCoachFixture.redWarning);
    await tester.pumpWidget(app());
    await tester.pump();

    final risk = find.byKey(const Key('risk-display-priority'));
    final panda = find.byKey(const Key('panda-avatar-stable-frame'));
    expect(risk, findsOneWidget);
    expect(find.text('需要专业关注'), findsOneWidget);
    expect(find.textContaining('人工测量或寻求专业帮助'), findsOneWidget);
    expect(tester.getTopLeft(risk).dy, lessThan(tester.getTopLeft(panda).dy));
  });

  testWidgets('system status uses the confirmed four labels', (tester) async {
    await tester.pumpWidget(app());
    await tester.pump();

    for (final label in ['心血管', '呼吸', '运动', '睡眠']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('62%'), findsOneWidget);
    expect(find.text('平均'), findsOneWidget);
    expect(find.text('66%'), findsNothing);
  });

  testWidgets('coach completion runs boost, follow-up and visible deltas', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pump();

    await tester.tap(find.byKey(const Key('coach-action-completed')));
    await tester.pump();
    expect(controller.viewModel.value.avatarState.name, 'completedBoost');
    expect(find.textContaining('任务已完成'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 380));
    expect(controller.viewModel.value.avatarState.name, 'normal');
    expect(find.text('+18'), findsOneWidget);
    expect(find.byKey(const Key('metric-delta-身体活力')), findsOneWidget);
    expect(find.byKey(const Key('coach-action-completed')), findsNothing);
    expect(find.byKey(const Key('coach-action-snooze')), findsNothing);
    expect(find.byKey(const Key('coach-action-decline')), findsNothing);

    await tester.pump(const Duration(seconds: 2));
    expect(controller.currentScenario.id.name, 'stressed');
    expect(find.byKey(const Key('coach-action-completed')), findsOneWidget);
    expect(find.textContaining('三分钟呼吸放松'), findsOneWidget);
  });

  testWidgets('320px viewport has no overflow exception', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(app());
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('home-scroll-view')), findsOneWidget);
    expect(find.byKey(const Key('panda-avatar-stable-frame')), findsOneWidget);
  });

  testWidgets('loading error empty and fallback states are explicit', (
    tester,
  ) async {
    const fixtures = <AvatarCoachFixture, String>{
      AvatarCoachFixture.loading: 'loading',
      AvatarCoachFixture.error: 'error',
      AvatarCoachFixture.empty: 'empty',
      AvatarCoachFixture.fallback: 'fallback',
    };

    await tester.pumpWidget(app());
    for (final entry in fixtures.entries) {
      controller.switchFixture(entry.key);
      await tester.pump();
      expect(find.byKey(Key('avatar-coach-${entry.value}')), findsOneWidget);
    }
  });

  testWidgets('completed boost only reports execution feedback', (
    tester,
  ) async {
    controller.viewModel.value = MockAvatarCoachService().getFixture(
      AvatarCoachFixture.completedBoost,
    );
    await tester.pumpWidget(app());
    await tester.pump();

    expect(find.textContaining('任务已完成'), findsOneWidget);
    expect(find.textContaining('指标已经改善'), findsNothing);
    expect(find.textContaining('身体已经改善'), findsNothing);
  });

  testWidgets('warning fallback keeps risk and manual retest usable', (
    tester,
  ) async {
    controller.switchFixture(AvatarCoachFixture.redWarning);
    await tester.pumpWidget(
      GetMaterialApp(
        theme: vvewellTheme(),
        home: DefaultAssetBundle(
          bundle: _FailingAssetBundle(),
          child: HomePage(avatarCoachController: controller),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('panda-avatar-fallback')), findsOneWidget);
    expect(find.byKey(const Key('risk-display-priority')), findsOneWidget);
    expect(find.byKey(const Key('mock-warning-normal-retest')), findsOneWidget);
    final warningCompleteButton = find.descendant(
      of: find.byKey(const Key('coach-action-completed')),
      matching: find.byType(FilledButton),
    );
    expect(
      tester.widget<FilledButton>(warningCompleteButton).onPressed,
      isNull,
    );

    await tester.tap(find.byKey(const Key('mock-warning-normal-retest')));
    await tester.pump();
    expect(find.byKey(const Key('risk-display-priority')), findsNothing);
    expect(controller.viewModel.value.avatarState.name, 'normal');

    await tester.pump(const Duration(seconds: 2));
    expect(controller.currentScenario.id.name, 'normal');
    expect(find.byKey(const Key('coach-action-completed')), findsOneWidget);
  });

  testWidgets('all home quick entries are wired to actions and destinations', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app());
    await tester.pump();
    final medical = find.byKey(const Key('quick-entry-医疗'));

    for (final label in ['医疗', '健康档案', '设备', '手机测量', '营养']) {
      final inkWell = tester.widget<InkWell>(
        find.byKey(Key('quick-entry-$label')),
      );
      expect(inkWell.onTap, isNotNull);
    }

    await tester.tap(find.byKey(const Key('quick-entry-营养')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
    expect(
      tester.state<NavigatorState>(find.byType(Navigator)).canPop(),
      isTrue,
    );
    expect(find.text('营养中心'), findsOneWidget);
    expect(find.text('针对睡眠风险的补剂候选'), findsOneWidget);
    Navigator.of(tester.element(find.text('营养中心'))).pop();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.byKey(const Key('quick-entry-健康档案')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('健康档案'), findsWidgets);
    Navigator.of(tester.element(find.text('健康档案').last)).pop();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(medical);
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byKey(const Key('medical-hub-scroll-view')), findsOneWidget);
  });

  testWidgets('health report demo upload creates an OCR summary', (
    tester,
  ) async {
    final reports = MedicalReportStore();
    addTearDown(reports.dispose);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      GetMaterialApp(
        theme: vvewellTheme(),
        home: HomePage(
          avatarCoachController: controller,
          medicalReportStore: reports,
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('bottom-nav-1')));
    await tester.pump();
    await tester.fling(
      find.byKey(const Key('health-scroll-view')),
      const Offset(0, -1200),
      2200,
    );
    await tester.pump(const Duration(milliseconds: 350));

    final reportEntry = find.byKey(const Key('medical-report-upload-entry'));
    final reportTap = find.descendant(
      of: reportEntry,
      matching: find.byType(InkWell),
    );
    tester.widget<InkWell>(reportTap).onTap!();
    await tester.pump(const Duration(milliseconds: 350));

    final demo = find.byKey(const Key('use-demo-medical-report'));
    tester.widget<TextButton>(demo).onPressed!();
    await tester.pump();
    final consent = find.widgetWithText(
      CheckboxListTile,
      '确认报告归属与内容，并同意用于本人的健康档案分析',
    );
    tester.widget<CheckboxListTile>(consent).onChanged!(true);
    await tester.pump();
    final submit = find.byKey(const Key('submit-medical-report'));
    tester.widget<ElevatedButton>(submit).onPressed!();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('最近医疗报告'), findsOneWidget);
    expect(find.textContaining('已提取体检项目与异常提示'), findsOneWidget);
    expect(reports.reportsFor('member-self'), hasLength(1));
  });

  testWidgets('chat suggestions change with the selected consultation scene', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pump();
    await tester.tap(find.byKey(const Key('bottom-nav-2')));
    await tester.pump();

    expect(find.textContaining('年度心血管复查'), findsOneWidget);
    await tester.tap(find.byKey(const Key('chat-topic-3')));
    await tester.pump();

    expect(find.textContaining('昨晚只睡了 6 小时 30 分钟'), findsOneWidget);
    expect(find.textContaining('睡眠呼吸风险为中等意味着什么'), findsOneWidget);
    expect(find.text('先看睡眠时长、趋势与风险标签'), findsOneWidget);
  });

  testWidgets(
    'report consultation exposes OCR upload without implementation details',
    (tester) async {
      await tester.pumpWidget(app());
      await tester.pump();
      await tester.tap(find.byKey(const Key('bottom-nav-2')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('chat-topic-1')));
      await tester.pump();

      expect(find.text('报告咨询'), findsWidgets);
      expect(find.text('上传报告后继续咨询'), findsOneWidget);
      expect(
        find.byKey(const Key('report-consultation-upload')),
        findsOneWidget,
      );
      expect(find.textContaining('Dirty Demo'), findsNothing);
      expect(find.textContaining('API 凭据'), findsNothing);
      expect(find.textContaining('APK 内置凭据'), findsNothing);
      expect(find.text('报告识别'), findsNothing);
    },
  );

  testWidgets('report consultation upload stays out of the medical archive', (
    tester,
  ) async {
    final reports = MedicalReportStore();
    addTearDown(reports.dispose);
    await tester.pumpWidget(
      GetMaterialApp(
        theme: vvewellTheme(),
        home: HomePage(
          avatarCoachController: controller,
          medicalReportStore: reports,
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('bottom-nav-2')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('chat-topic-1')));
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('report-consultation-welcome-upload')),
    );
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.textContaining('Dirty Demo'), findsNothing);
    expect(find.textContaining('API 凭据'), findsNothing);

    tester
        .widget<TextButton>(find.byKey(const Key('use-demo-medical-report')))
        .onPressed!();
    await tester.pump();
    final consent = find.widgetWithText(CheckboxListTile, '确认报告内容，并同意用于本次报告咨询');
    tester.widget<CheckboxListTile>(consent).onChanged!(true);
    await tester.pump();
    tester
        .widget<ElevatedButton>(find.byKey(const Key('submit-medical-report')))
        .onPressed!();
    await tester.pump(const Duration(milliseconds: 350));

    expect(reports.reportsFor('member-self'), isEmpty);
    expect(find.textContaining('已载入脱敏演示报告'), findsOneWidget);
  });

  testWidgets('consultation context refreshes after switching family member', (
    tester,
  ) async {
    final family = FamilyProfileController(
      initialMembers: const [
        FamilyMember(
          id: 'member-a',
          name: '成员甲',
          relationship: '本人',
          gender: '男',
          birthYear: 1990,
          healthScore: 80,
          tags: [],
        ),
        FamilyMember(
          id: 'member-b',
          name: '成员乙',
          relationship: '家人',
          gender: '女',
          birthYear: 1992,
          healthScore: 82,
          tags: [],
        ),
      ],
    );
    final reports = MedicalReportStore();
    addTearDown(family.dispose);
    addTearDown(reports.dispose);

    await tester.pumpWidget(
      GetMaterialApp(
        theme: vvewellTheme(),
        home: HomePage(
          avatarCoachController: controller,
          familyProfileController: family,
          medicalReportStore: reports,
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('bottom-nav-2')));
    await tester.pump();
    expect(find.text('成员甲 的个性化咨询场景'), findsOneWidget);

    family.selectMember('member-b');
    await tester.pump();
    expect(find.text('成员乙 的个性化咨询场景'), findsOneWidget);
    expect(find.text('成员甲 的个性化咨询场景'), findsNothing);
  });
}

class _FailingAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) =>
      Future<ByteData>.error(StateError('Simulated missing asset: $key'));
}
