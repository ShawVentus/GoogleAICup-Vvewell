import 'package:alloop/features/family/presentation/controllers/family_profile_controller.dart';
import 'package:alloop/features/recommendations/domain/recommendation_models.dart';
import 'package:alloop/features/recommendations/presentation/recommendation_section.dart';
import 'package:alloop/features/medical/presentation/medical_hub_page.dart';
import 'package:alloop/foundations/localization/app_localization.dart';
import 'package:alloop/foundations/ui/vvewell_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  final cjk = RegExp(r'[\u3400-\u9fff]');
  late FamilyProfileController familyController;

  setUp(() {
    Get.testMode = true;
    Get.put(AppLanguageController()..setEnglish(true));
    familyController = FamilyProfileController();
  });

  tearDown(() {
    familyController.dispose();
    Get.reset();
  });

  void expectNoChinese(WidgetTester tester) {
    final strings = <String>[
      ...tester
          .widgetList<Text>(find.byType(Text))
          .map((text) => text.data ?? text.textSpan?.toPlainText() ?? ''),
      ...tester
          .widgetList<TextField>(find.byType(TextField))
          .expand(
            (field) => [
              field.decoration?.labelText ?? '',
              field.decoration?.hintText ?? '',
              field.decoration?.helperText ?? '',
            ],
          ),
    ];
    final untranslated = strings.where(cjk.hasMatch).toSet();
    expect(
      untranslated,
      isEmpty,
      reason: 'Visible text remained Chinese: $untranslated',
    );
  }

  Widget medicalApp() => GetMaterialApp(
    translations: VvewellTranslations(),
    locale: const Locale('en', 'US'),
    fallbackLocale: const Locale('en', 'US'),
    theme: vvewellTheme(),
    home: Scaffold(
      body: SafeArea(
        child: MedicalHubPage(
          familyProfileController: familyController,
          header: const SizedBox(height: 1),
        ),
      ),
    ),
  );

  testWidgets(
    'Insurance tab and planning, policy, claim, and plan details are English',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(medicalApp());
      await tester.tap(find.byKey(const Key('medical-hub-tab-1')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'initial insurance tab');
      expectNoChinese(tester);
      expect(find.textContaining('CNY'), findsWidgets);

      await tester.tap(find.byKey(const Key('start-insurance-planning')));
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'insurance planning sheet',
      );
      expectNoChinese(tester);
      expect(find.text('Coverage priorities'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Policies and claims'));
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'insurance policy section',
      );
      expectNoChinese(tester);
      await tester.ensureVisible(find.byKey(const Key('create-claim-draft')));
      await tester.tap(find.byKey(const Key('create-claim-draft')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'claim form');
      expectNoChinese(tester);
      expect(find.text('Document checklist'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      final medicalScroll = find
          .descendant(
            of: find.byKey(const Key('medical-hub-scroll-view')),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.text('View terms and costs').first,
        280,
        scrollable: medicalScroll,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'before plan details');
      await tester.tap(find.text('View terms and costs').first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'plan details sheet');
      expectNoChinese(tester);
      expect(find.text('Important limitations'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const Key('advisor-contact-from-details')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('advisor-contact-from-details')));
      await tester.pumpAndSettle();
      expectNoChinese(tester);
      expect(find.text('Contact name *'), findsOneWidget);
    },
  );

  testWidgets(
    'Peer community scroll, English search, join, leave, post, and report are English',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(medicalApp());
      await tester.tap(find.byKey(const Key('medical-hub-tab-2')));
      await tester.pumpAndSettle();
      expectNoChinese(tester);
      expect(find.text('Breast Cancer Peer Support'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('community-search')),
        'breast',
      );
      await tester.pumpAndSettle();
      expect(find.text('Breast Cancer Peer Support'), findsOneWidget);
      expectNoChinese(tester);

      await tester.tap(find.text('Breast Cancer Peer Support'));
      await tester.pumpAndSettle();
      expectNoChinese(tester);
      expect(find.text('Allowed content'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('join-community-breast-cancer')));
      await tester.pumpAndSettle();
      expectNoChinese(tester);
      final consent = find.text(
        'I have read the community rules and privacy notice and agree to join',
      );
      await tester.ensureVisible(consent);
      await tester.tap(consent);
      await tester.pump();
      await tester.tap(find.text('Join with an alias'));
      await tester.pumpAndSettle();
      expect(find.text('Joined'), findsWidgets);
      expectNoChinese(tester);

      await tester.tap(find.byKey(const Key('join-community-breast-cancer')));
      await tester.pumpAndSettle();
      expect(find.text('Join'), findsWidgets);
      expectNoChinese(tester);

      await tester.enterText(find.byKey(const Key('community-search')), '');
      await tester.pumpAndSettle();
      final communityScroll = find
          .descendant(
            of: find.byKey(const Key('medical-hub-scroll-view')),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.byKey(const Key('create-community-post')),
        260,
        scrollable: communityScroll,
      );
      await tester.pumpAndSettle();
      final createPost = tester.widget<IconButton>(
        find.byKey(const Key('create-community-post')),
      );
      expect(createPost.onPressed, isNotNull);
      createPost.onPressed!();
      await tester.pumpAndSettle();
      expectNoChinese(tester);
      expect(find.text('Post type *'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byTooltip('More actions').first,
        260,
        scrollable: communityScroll,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('More actions').first);
      await tester.pumpAndSettle();
      expect(find.text('Report post'), findsOneWidget);
      await tester.tap(find.text('Report post'));
      await tester.pumpAndSettle();
      expectNoChinese(tester);
      expect(find.text('Medical misinformation'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Reply').first,
        260,
        scrollable: communityScroll,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reply').first);
      await tester.pumpAndSettle();
      expectNoChinese(tester);
      expect(find.text('Post reply'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.textContaining('For adult members'),
        260,
        scrollable: communityScroll,
      );
      await tester.pumpAndSettle();
      expectNoChinese(tester);
    },
  );

  testWidgets(
    'Care referral subtab remains English after the Insurance and Peer tabs',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(medicalApp());
      await tester.pumpAndSettle();
      expectNoChinese(tester);
      final scrollable = find
          .descendant(
            of: find.byKey(const Key('medical-hub-scroll-view')),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.text('Candidate care providers'),
        280,
        scrollable: scrollable,
      );
      await tester.pumpAndSettle();
      expectNoChinese(tester);
    },
  );

  testWidgets(
    'home bottom Recommended reading cards, summaries, and tags are English',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        GetMaterialApp(
          translations: VvewellTranslations(),
          locale: const Locale('en', 'US'),
          fallbackLocale: const Locale('en', 'US'),
          theme: vvewellTheme(),
          home: Scaffold(
            body: ListView(
              key: const Key('home-scroll-view'),
              children: [
                const SizedBox(height: 1000),
                const Text('Recommended reading'),
                RecommendationSection(
                  repository: _EmptyRecommendationRepository(),
                  healthTags: familyController.activeMember.tags,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      final scroll = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byKey(const Key('home-scroll-view')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      scroll.position.jumpTo(scroll.position.maxScrollExtent);
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Understand sleep trends: three signals that matter more than one night’s duration',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'What to prepare in your health record before a family cardiovascular check-up',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Understand outpatient coverage: limits, deductibles, and provider networks',
        ),
        findsOneWidget,
      );
      expect(find.text('Blood pressure trends'), findsWidgets);
      expect(find.text('Sleep-breathing risk'), findsWidgets);
      expect(find.text('Annual cardiovascular check-up'), findsWidgets);
      expect(find.text('Outpatient coverage'), findsWidgets);
      expectNoChinese(tester);
    },
  );
}

class _EmptyRecommendationRepository implements RecommendationRepository {
  const _EmptyRecommendationRepository();

  @override
  Future<RecommendationPlan?> load() async => null;

  @override
  Future<void> recordImpression(
    String decisionId,
    RecommendationItem item, {
    required String sessionId,
    required int displayedRank,
  }) async {}

  @override
  Future<void> updateTask(
    RecommendationItem item,
    String status, {
    required String sessionId,
    required int displayedRank,
  }) async {}
}
