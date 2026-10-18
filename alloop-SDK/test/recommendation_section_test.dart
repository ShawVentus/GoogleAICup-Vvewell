import 'package:alloop/features/recommendations/data/recommendation_api_service.dart';
import 'package:alloop/features/recommendations/domain/recommendation_models.dart';
import 'package:alloop/features/recommendations/presentation/recommendation_section.dart';
import 'package:alloop/features/family/presentation/controllers/family_profile_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('recommendation item parses persisted task identity', () {
    final item = RecommendationItem.fromJson({
      'catalog_item_id': '95000000-0000-4000-8000-000000000001',
      'intent_code': 'TASK.BREATH.SHORT',
      'item_kind': 'TASK',
      'title': 'Breathing task',
      'description': 'Five minutes.',
      'explanation_codes': ['AFFINITY:relative_hr_elevated'],
      'task': {'task_id': '96000000-0000-4000-8000-000000000001'},
    });

    expect(item.taskId, '96000000-0000-4000-8000-000000000001');
    expect(item.itemKind, 'TASK');
  });

  testWidgets(
    'recommendation section shows empty local state without network',
    (tester) async {
      final tags = FamilyProfileController().activeMember.tags;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecommendationSection(
              repository: _FakeRepository(null),
              healthTags: tags,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('把睡眠趋势读懂'), findsOneWidget);
      expect(find.text('睡眠呼吸风险'), findsWidgets);
    },
  );

  testWidgets('local task starts without a cloud request', (tester) async {
    final item = RecommendationItem.fromJson({
      'catalog_item_id': 'catalog-1',
      'intent_code': 'TASK.BREATH.SHORT',
      'item_kind': 'TASK',
      'title': 'Breathing task',
      'description': 'Five minutes.',
      'explanation_codes': ['AFFINITY:relative_hr_elevated'],
      'task': {'task_id': 'task-1'},
    });
    final repository = _FakeRepository(
      RecommendationPlan(
        decisionId: 'decision-1',
        status: 'READY',
        reasonCode: null,
        items: [item],
        analyzedAt: DateTime.utc(2026, 8, 3, 10),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: RecommendationSection(repository: repository)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('开始任务'));
    await tester.pumpAndSettle();

    expect(repository.impressionRank, 1);
    expect(repository.impressionSession, isNotEmpty);
    expect(repository.updatedStatus, 'started');
    expect(repository.updatedRank, 1);
    expect(repository.updatedSession, repository.impressionSession);
    expect(find.byTooltip('完成任务'), findsOneWidget);
    expect(find.textContaining('尚未同步'), findsOneWidget);
  });
}

class _FakeRepository implements RecommendationRepository {
  _FakeRepository(this.plan);
  final RecommendationPlan? plan;
  String? updatedStatus;
  String? impressionSession;
  int? impressionRank;
  String? updatedSession;
  int? updatedRank;

  @override
  Future<RecommendationPlan?> load() async => plan;

  @override
  Future<void> recordImpression(
    String decisionId,
    RecommendationItem item, {
    required String sessionId,
    required int displayedRank,
  }) async {
    impressionSession = sessionId;
    impressionRank = displayedRank;
  }

  @override
  Future<void> updateTask(
    RecommendationItem item,
    String status, {
    required String sessionId,
    required int displayedRank,
  }) async {
    updatedStatus = status;
    updatedSession = sessionId;
    updatedRank = displayedRank;
  }
}
