import 'package:alloop/features/recommendations/domain/phone_recommendation_policy.dart';
import 'package:alloop/features/health_analysis/domain/phone_health_analyzer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const policy = PhoneRecommendationPolicy();
  final now = DateTime.utc(2026, 8, 3, 10);

  test('matches TypeScript data-insufficient fallback', () {
    final result = policy.execute(
      _context(now, tags: [_tag('data_insufficient')]),
      const PhoneRecommendationRequestContext(),
      now,
    );
    expect(result.items.map((item) => item['intent_code']), [
      'ADVICE.MEASUREMENT.RETRY',
    ]);
  });

  test('matches elevated-state ranking and contribution scores', () {
    final result = policy.execute(
      _context(
        now,
        tags: [
          _tag('relative_hr_elevated'),
          _tag('relative_resp_rate_elevated'),
        ],
      ),
      const PhoneRecommendationRequestContext(),
      now,
    );
    expect(
      result.items.map((item) => item['intent_code']),
      containsAll(['TASK.BREATH.SHORT', 'ADVICE.RECOVERY.REST']),
    );
    for (final candidate in result.candidates) {
      final sum = (candidate['contributions'] as List)
          .whereType<Map>()
          .fold<double>(
            0,
            (total, item) => total + (item['contribution'] as num).toDouble(),
          );
      expect(sum, closeTo((candidate['score'] as num).toDouble(), 1e-10));
    }
  });

  final positiveCases =
      <(String, Map<String, Object?>, PhoneRecommendationRequestContext)>[
        (
          'TASK.BREATH.SHORT',
          {
            'tags': [_tag('relative_hr_elevated')],
          },
          const PhoneRecommendationRequestContext(),
        ),
        (
          'TASK.WALK.LIGHT',
          {
            'tags': [_tag('low_activity')],
          },
          const PhoneRecommendationRequestContext(canWalk: true),
        ),
        (
          'TASK.SLEEP.BEFORE_23',
          {
            'tags': [_tag('poor_sleep')],
          },
          const PhoneRecommendationRequestContext(),
        ),
        (
          'TASK.ALCOHOL_FREE_DAY',
          const {},
          const PhoneRecommendationRequestContext(
            alcoholGoal: true,
            alcoholWithdrawalRiskCleared: true,
          ),
        ),
        (
          'TASK.APPROVED_VITAMIN_PLAN',
          {
            'verifiedPlan': true,
            'verifiedPlanId': '97000000-0000-4000-8000-000000000001',
          },
          const PhoneRecommendationRequestContext(),
        ),
        (
          'ADVICE.SLEEP.ENVIRONMENT',
          {
            'tags': [_tag('poor_sleep')],
          },
          const PhoneRecommendationRequestContext(),
        ),
        (
          'ADVICE.RECOVERY.REST',
          {
            'tags': [_tag('relative_hrv_suppressed')],
          },
          const PhoneRecommendationRequestContext(),
        ),
        (
          'ADVICE.MEASUREMENT.RETRY',
          {
            'tags': [_tag('measurement_stale')],
          },
          const PhoneRecommendationRequestContext(),
        ),
        (
          'GOODS.MEASUREMENT_HARDWARE',
          {
            'tags': [_tag('low_data_coverage')],
            'consents': ['commercial_recommendation'],
          },
          const PhoneRecommendationRequestContext(),
        ),
        (
          'GOODS.APPROVED_NUTRITION_SUPPORT',
          {
            'verifiedPlan': true,
            'verifiedPlanId': '97000000-0000-4000-8000-000000000001',
            'consents': ['commercial_recommendation'],
          },
          const PhoneRecommendationRequestContext(),
        ),
        (
          'SERVICE.GENERAL_CHECKUP',
          {
            'checkupDue': true,
            'consents': ['medical_service_recommendation'],
          },
          const PhoneRecommendationRequestContext(),
        ),
        (
          'SERVICE.CHRONIC_FOLLOWUP',
          {
            'verifiedDiagnosis': true,
            'consents': ['medical_service_recommendation'],
          },
          const PhoneRecommendationRequestContext(),
        ),
        (
          'SERVICE.INSURANCE_REVIEW',
          {
            'consents': ['insurance_recommendation'],
          },
          const PhoneRecommendationRequestContext(),
        ),
      ];

  for (final (intent, overrides, request) in positiveCases) {
    test('has canonical positive route for $intent', () {
      final result = policy.execute(
        _context(now, overrides: overrides),
        request,
        now,
      );
      expect(result.items.map((item) => item['intent_code']), contains(intent));
    });
  }

  test('stale context fails closed for goods and services', () {
    final result = policy.execute(
      _context(
        now,
        expiresAt: now.subtract(const Duration(seconds: 1)),
        overrides: {
          'verifiedPlan': true,
          'verifiedPlanId': '97000000-0000-4000-8000-000000000001',
          'verifiedDiagnosis': true,
          'checkupDue': true,
          'consents': [
            'commercial_recommendation',
            'medical_service_recommendation',
            'insurance_recommendation',
          ],
        },
      ),
      const PhoneRecommendationRequestContext(),
      now,
    );
    expect(
      result.items.where(
        (item) => {'GOODS', 'SERVICE'}.contains(item['item_kind']),
      ),
      isEmpty,
    );
  });

  test('minor restriction and care escalation are isolated', () {
    final minor = policy.execute(
      _context(
        now,
        overrides: {
          'ageGroup': 'child',
          'verifiedPlan': true,
          'verifiedPlanId': '97000000-0000-4000-8000-000000000001',
          'verifiedDiagnosis': true,
          'consents': [
            'commercial_recommendation',
            'medical_service_recommendation',
            'insurance_recommendation',
          ],
        },
      ),
      const PhoneRecommendationRequestContext(),
      now,
    );
    expect(
      minor.candidates
          .where(
            (item) =>
                item['intent_code'].toString().startsWith('GOODS.') ||
                item['intent_code'].toString().startsWith('SERVICE.'),
          )
          .every((item) => item['eligible'] == false),
      isTrue,
    );
    final care = policy.execute(
      _context(now, overrides: {'careEscalation': true}),
      const PhoneRecommendationRequestContext(),
      now,
    );
    expect(care.status, 'CARE_ESCALATION');
    expect(care.items, isEmpty);
    expect(care.candidates, isEmpty);
  });

  test('vitamin task copies only verified plan reference', () {
    const planId = '97000000-0000-4000-8000-000000000001';
    final result = policy.execute(
      _context(
        now,
        overrides: {'verifiedPlan': true, 'verifiedPlanId': planId},
      ),
      const PhoneRecommendationRequestContext(),
      now,
    );
    final task =
        result.items.singleWhere(
              (item) => item['intent_code'] == 'TASK.APPROVED_VITAMIN_PLAN',
            )['task']
            as Map;
    expect(task['goal'], {
      'type': 'verified_plan_completion',
      'target': 1,
      'verified_plan_id': planId,
    });
    expect(task.toString().toLowerCase(), isNot(contains('dose')));
    expect(task.toString().toLowerCase(), isNot(contains('amount')));
  });
}

PhoneRecommendationContext _context(
  DateTime now, {
  List<PhoneHealthTag> tags = const [],
  DateTime? expiresAt,
  Map<String, Object?> overrides = const {},
}) => PhoneRecommendationContext(
  memberId: '00000000-0000-4000-8000-000000000001',
  ageGroup: (overrides['ageGroup'] ?? 'adult').toString(),
  tags: (overrides['tags'] as List<PhoneHealthTag>?) ?? tags,
  consentScopes: ((overrides['consents'] as List?) ?? const [])
      .map((item) => item.toString())
      .toList(),
  verifiedDiagnosis: overrides['verifiedDiagnosis'] == true,
  verifiedPlan: overrides['verifiedPlan'] == true,
  verifiedPlanId: overrides['verifiedPlanId']?.toString(),
  checkupDue: overrides['checkupDue'] == true,
  careEscalation: overrides['careEscalation'] == true,
  catalogItems: _catalog(),
  contextExpiresAt: expiresAt ?? now.add(const Duration(hours: 24)),
);

List<PhoneCatalogItem> _catalog() => [
  for (var index = 0; index < phoneRecommendationIntents.length; index++)
    PhoneCatalogItem(
      id: '90000000-0000-4000-8000-${(index + 1).toString().padLeft(12, '0')}',
      intentCode: phoneRecommendationIntents[index].code,
      itemKind: phoneRecommendationIntents[index].kind,
      title: phoneRecommendationIntents[index].code,
      description: 'Approved general-wellness content.',
      consentScope: phoneRecommendationIntents[index].requiredScopes,
      approvalStatus: 'APPROVED',
      dataOrigin: 'REAL',
      commercialDisclosure:
          {'GOODS', 'SERVICE'}.contains(phoneRecommendationIntents[index].kind)
          ? 'Commercial recommendation disclosure.'
          : null,
    ),
];

PhoneHealthTag _tag(String key) => PhoneHealthTag(
  tagType: 'state',
  tagKey: key,
  tagValue: const {'active': true},
  weight: 1,
  confidence: 1,
  validFrom: DateTime.utc(2026, 8, 3),
  validTo: DateTime.utc(2026, 8, 4),
  evidence: const {},
  inputFingerprint: key.padRight(64, '0').substring(0, 64),
  demoBaseline: false,
  dataOrigin: 'REAL',
);
