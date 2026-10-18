import 'dart:convert';

import 'package:flutter/services.dart';

import '../../health_analysis/domain/canonical_contract.dart';
import '../../health_analysis/domain/phone_health_analyzer.dart';

const phoneFeatureSchemaVersion = 'health-tag-feature-schema-v2';
const phoneMatrixVersion = 'recommendation-affinity-matrix-v2';
const phoneRegistryVersion = 'recommendation-intent-registry-v2';
const phoneRecommendationPolicyVersion = 'recommendation-policy-dart-v2';
const phoneRecommendationSafetyVersion = 'recommendation-safety-v2';

const phoneFeatureIds = <String>[
  'relative_hr_elevated',
  'relative_hr_suppressed',
  'relative_resp_rate_elevated',
  'relative_hrv_suppressed',
  'distribution_shift',
  'recovery_need',
  'poor_sleep',
  'sleep_debt',
  'low_activity',
  'data_insufficient',
  'low_data_coverage',
  'source_conflict',
  'measurement_stale',
  'is_night',
  'before_23',
  'can_walk',
  'alcohol_goal',
  'verified_plan',
  'verified_diagnosis',
  'checkup_due',
  'commercial_consent',
  'medical_service_consent',
  'insurance_consent',
  'state_confidence',
  'data_coverage',
];

class PhoneRecommendationIntent {
  const PhoneRecommendationIntent(
    this.code,
    this.kind,
    this.requiredScopes,
    this.requiredFact,
  );
  final String code;
  final String kind;
  final List<String> requiredScopes;
  final String? requiredFact;
}

const phoneRecommendationIntents = <PhoneRecommendationIntent>[
  PhoneRecommendationIntent('TASK.BREATH.SHORT', 'TASK', [], null),
  PhoneRecommendationIntent('TASK.WALK.LIGHT', 'TASK', [], null),
  PhoneRecommendationIntent('TASK.SLEEP.BEFORE_23', 'TASK', [], null),
  PhoneRecommendationIntent(
    'TASK.ALCOHOL_FREE_DAY',
    'TASK',
    [],
    'ALCOHOL_GOAL',
  ),
  PhoneRecommendationIntent(
    'TASK.APPROVED_VITAMIN_PLAN',
    'TASK',
    [],
    'VERIFIED_PLAN',
  ),
  PhoneRecommendationIntent('ADVICE.SLEEP.ENVIRONMENT', 'ADVICE', [], null),
  PhoneRecommendationIntent('ADVICE.RECOVERY.REST', 'ADVICE', [], null),
  PhoneRecommendationIntent('ADVICE.MEASUREMENT.RETRY', 'ADVICE', [], null),
  PhoneRecommendationIntent('GOODS.MEASUREMENT_HARDWARE', 'GOODS', [
    'commercial_recommendation',
  ], null),
  PhoneRecommendationIntent('GOODS.APPROVED_NUTRITION_SUPPORT', 'GOODS', [
    'commercial_recommendation',
  ], 'VERIFIED_PLAN'),
  PhoneRecommendationIntent('SERVICE.GENERAL_CHECKUP', 'SERVICE', [
    'medical_service_recommendation',
  ], null),
  PhoneRecommendationIntent('SERVICE.CHRONIC_FOLLOWUP', 'SERVICE', [
    'medical_service_recommendation',
  ], 'VERIFIED_DIAGNOSIS'),
  PhoneRecommendationIntent('SERVICE.INSURANCE_REVIEW', 'SERVICE', [
    'insurance_recommendation',
  ], null),
];

class PhoneCatalogItem {
  const PhoneCatalogItem({
    required this.id,
    required this.intentCode,
    required this.itemKind,
    required this.title,
    required this.description,
    required this.consentScope,
    required this.approvalStatus,
    required this.dataOrigin,
    required this.commercialDisclosure,
  });
  final String id;
  final String intentCode;
  final String itemKind;
  final String title;
  final String description;
  final List<String> consentScope;
  final String approvalStatus;
  final String dataOrigin;
  final String? commercialDisclosure;

  factory PhoneCatalogItem.fromJson(Map<String, Object?> json) =>
      PhoneCatalogItem(
        id: json['id'].toString(),
        intentCode: json['intent_code'].toString(),
        itemKind: json['item_kind'].toString(),
        title: json['title'].toString(),
        description: json['description'].toString(),
        consentScope: (json['consent_scope'] as List? ?? const [])
            .map((item) => item.toString())
            .toList(),
        approvalStatus: json['approval_status'].toString(),
        dataOrigin: json['data_origin'].toString(),
        commercialDisclosure: json['commercial_disclosure']?.toString(),
      );

  Map<String, Object?> toJson() => {
    'id': id,
    'intent_code': intentCode,
    'item_kind': itemKind,
    'title': title,
    'description': description,
    'consent_scope': consentScope,
    'approval_status': approvalStatus,
    'data_origin': dataOrigin,
    'commercial_disclosure': commercialDisclosure,
  };
}

class PhoneRecommendationContext {
  const PhoneRecommendationContext({
    required this.memberId,
    required this.ageGroup,
    required this.tags,
    required this.consentScopes,
    required this.verifiedDiagnosis,
    required this.verifiedPlan,
    required this.verifiedPlanId,
    required this.checkupDue,
    required this.careEscalation,
    required this.catalogItems,
    this.contextExpiresAt,
  });
  final String memberId;
  final String? ageGroup;
  final List<PhoneHealthTag> tags;
  final List<String> consentScopes;
  final bool verifiedDiagnosis;
  final bool verifiedPlan;
  final String? verifiedPlanId;
  final bool checkupDue;
  final bool careEscalation;
  final List<PhoneCatalogItem> catalogItems;
  final DateTime? contextExpiresAt;

  bool isFresh(DateTime now) =>
      contextExpiresAt != null && contextExpiresAt!.isAfter(now);
}

class PhoneRecommendationRequestContext {
  const PhoneRecommendationRequestContext({
    this.canWalk = false,
    this.alcoholGoal = false,
    this.alcoholWithdrawalRiskCleared = false,
    this.timezoneOffsetMinutes = 0,
  });
  final bool canWalk;
  final bool alcoholGoal;
  final bool alcoholWithdrawalRiskCleared;
  final int timezoneOffsetMinutes;
}

class PhoneRecommendationExecution {
  const PhoneRecommendationExecution({
    required this.status,
    required this.reasonCode,
    required this.items,
    required this.features,
    required this.candidates,
  });
  final String status;
  final String? reasonCode;
  final List<Map<String, Object?>> items;
  final Map<String, double> features;
  final List<Map<String, Object?>> candidates;

  Map<String, Object?> toJson() => {
    'status': status,
    'reason_code': reasonCode,
    'items': items,
    'features': features,
    'candidates': candidates,
    'feature_schema_version': phoneFeatureSchemaVersion,
    'matrix_version': phoneMatrixVersion,
    'registry_version': phoneRegistryVersion,
    'policy_version': phoneRecommendationPolicyVersion,
    'safety_version': phoneRecommendationSafetyVersion,
  };
}

class PhoneCatalogLoader {
  static Future<List<PhoneCatalogItem>> load() async {
    final raw =
        jsonDecode(
              await rootBundle.loadString(
                'assets/recommendation_v2/catalog.json',
              ),
            )
            as Map;
    return (raw['items'] as List)
        .map(
          (item) =>
              PhoneCatalogItem.fromJson(Map<String, Object?>.from(item as Map)),
        )
        .toList(growable: false);
  }
}

class PhoneRecommendationPolicy {
  const PhoneRecommendationPolicy();

  static const _affinity = <String, Map<String, double>>{
    'relative_hr_elevated': {
      'TASK.BREATH.SHORT': .9,
      'ADVICE.RECOVERY.REST': .7,
      'SERVICE.GENERAL_CHECKUP': .25,
    },
    'relative_hr_suppressed': {
      'ADVICE.RECOVERY.REST': .8,
      'SERVICE.GENERAL_CHECKUP': .35,
    },
    'relative_resp_rate_elevated': {
      'TASK.BREATH.SHORT': .85,
      'ADVICE.RECOVERY.REST': .6,
      'SERVICE.GENERAL_CHECKUP': .3,
    },
    'relative_hrv_suppressed': {
      'ADVICE.RECOVERY.REST': .9,
      'TASK.SLEEP.BEFORE_23': .55,
      'ADVICE.SLEEP.ENVIRONMENT': .45,
    },
    'distribution_shift': {
      'SERVICE.GENERAL_CHECKUP': .65,
      'ADVICE.RECOVERY.REST': .4,
    },
    'recovery_need': {
      'ADVICE.RECOVERY.REST': 1,
      'TASK.BREATH.SHORT': .45,
      'TASK.SLEEP.BEFORE_23': .45,
    },
    'poor_sleep': {'TASK.SLEEP.BEFORE_23': 1, 'ADVICE.SLEEP.ENVIRONMENT': .9},
    'sleep_debt': {'TASK.SLEEP.BEFORE_23': 1, 'ADVICE.SLEEP.ENVIRONMENT': .7},
    'low_activity': {'TASK.WALK.LIGHT': 1},
    'data_insufficient': {'ADVICE.MEASUREMENT.RETRY': 1},
    'low_data_coverage': {
      'ADVICE.MEASUREMENT.RETRY': .9,
      'GOODS.MEASUREMENT_HARDWARE': .65,
    },
    'source_conflict': {
      'ADVICE.MEASUREMENT.RETRY': 1,
      'GOODS.MEASUREMENT_HARDWARE': .45,
    },
    'measurement_stale': {'ADVICE.MEASUREMENT.RETRY': .9},
    'is_night': {
      'TASK.WALK.LIGHT': -.8,
      'TASK.SLEEP.BEFORE_23': .5,
      'ADVICE.SLEEP.ENVIRONMENT': .4,
    },
    'before_23': {'TASK.SLEEP.BEFORE_23': .4},
    'can_walk': {'TASK.WALK.LIGHT': .65},
    'alcohol_goal': {'TASK.ALCOHOL_FREE_DAY': 1},
    'verified_plan': {
      'TASK.APPROVED_VITAMIN_PLAN': .9,
      'GOODS.APPROVED_NUTRITION_SUPPORT': .65,
    },
    'verified_diagnosis': {'SERVICE.CHRONIC_FOLLOWUP': 1},
    'checkup_due': {'SERVICE.GENERAL_CHECKUP': .85},
    'commercial_consent': {
      'GOODS.MEASUREMENT_HARDWARE': .2,
      'GOODS.APPROVED_NUTRITION_SUPPORT': .2,
    },
    'medical_service_consent': {
      'SERVICE.GENERAL_CHECKUP': .2,
      'SERVICE.CHRONIC_FOLLOWUP': .2,
    },
    'insurance_consent': {'SERVICE.INSURANCE_REVIEW': .8},
    'state_confidence': {'ADVICE.MEASUREMENT.RETRY': -.6},
    'data_coverage': {'ADVICE.MEASUREMENT.RETRY': -.5},
  };

  PhoneRecommendationExecution execute(
    PhoneRecommendationContext context,
    PhoneRecommendationRequestContext request,
    DateTime now,
  ) {
    final features = encodeFeatures(context, request, now);
    if (context.careEscalation && context.isFresh(now)) {
      return PhoneRecommendationExecution(
        status: 'CARE_ESCALATION',
        reasonCode: 'ACTIVE_CARE_ESCALATION',
        items: const [],
        features: features,
        candidates: const [],
      );
    }
    final forceRetry =
        features['data_insufficient']! > 0 ||
        features['source_conflict']! > .5 ||
        features['measurement_stale']! > .5;
    final candidates = <Map<String, Object?>>[];
    for (final item in context.catalogItems) {
      final reasons = exclusions(item, context, request, now);
      if (forceRetry && item.intentCode != 'ADVICE.MEASUREMENT.RETRY')
        reasons.add('DATA_QUALITY_ABSTENTION');
      final contributions = <Map<String, Object?>>[];
      var score = 0.0;
      for (final featureId in phoneFeatureIds) {
        final contribution =
            features[featureId]! *
            (_affinity[featureId]?[item.intentCode] ?? 0);
        score += contribution;
        if (contribution != 0)
          contributions.add({
            'feature_id': featureId,
            'contribution': contribution,
          });
      }
      if (forceRetry &&
          item.intentCode == 'ADVICE.MEASUREMENT.RETRY' &&
          score < 1) {
        contributions.add({
          'feature_id': 'POLICY_DATA_QUALITY_OVERRIDE',
          'contribution': 1 - score,
        });
        score = 1;
      }
      candidates.add({
        'item': item,
        'intent_code': item.intentCode,
        'score': score,
        'eligible': reasons.isEmpty,
        'exclusion_reasons': reasons.toSet().toList()..sort(),
        'contributions': contributions,
      });
    }
    candidates.sort((left, right) {
      final score = (right['score'] as double).compareTo(
        left['score'] as double,
      );
      return score != 0
          ? score
          : left['intent_code'].toString().compareTo(
              right['intent_code'].toString(),
            );
    });
    final selected = <Map<String, Object?>>[];
    final kindCounts = <String, int>{};
    for (final candidate in candidates) {
      final item = candidate['item']! as PhoneCatalogItem;
      if (candidate['eligible'] != true ||
          (candidate['score'] as double) <= 0 ||
          selected.length >= 4)
        continue;
      final cap = item.itemKind == 'TASK' ? 2 : 1;
      if ((kindCounts[item.itemKind] ?? 0) >= cap) continue;
      selected.add(candidate);
      kindCounts[item.itemKind] = (kindCounts[item.itemKind] ?? 0) + 1;
    }
    final items = selected
        .map((candidate) {
          final item = candidate['item']! as PhoneCatalogItem;
          final positive =
              (candidate['contributions'] as List)
                  .whereType<Map>()
                  .where((entry) => (entry['contribution'] as num) > 0)
                  .toList()
                ..sort(
                  (left, right) => (right['contribution'] as num).compareTo(
                    left['contribution'] as num,
                  ),
                );
          final explanation = positive
              .take(3)
              .map((entry) => 'AFFINITY:${entry['feature_id']}')
              .toList();
          final goal = item.intentCode == 'TASK.APPROVED_VITAMIN_PLAN'
              ? {
                  'type': 'verified_plan_completion',
                  'target': 1,
                  'verified_plan_id': context.verifiedPlanId,
                }
              : <String, Object?>{'type': 'boolean', 'target': 1};
          return <String, Object?>{
            'catalog_item_id': item.id,
            'intent_code': item.intentCode,
            'item_kind': item.itemKind,
            'title': item.title,
            'description': item.description,
            'score': double.parse(
              (candidate['score'] as double).toStringAsFixed(6),
            ),
            'explanation_codes': explanation.isEmpty
                ? ['POLICY:APPROVED_CONTEXT']
                : explanation,
            'commercial_disclosure': item.commercialDisclosure,
            if (item.itemKind == 'TASK')
              'task': {
                'due_at': pythonIso(
                  now.add(
                    Duration(
                      hours: item.intentCode == 'TASK.SLEEP.BEFORE_23' ? 6 : 24,
                    ),
                  ),
                ),
                'client_task_id': 'task:${item.id}',
                'goal': goal,
              },
          };
        })
        .toList(growable: false);
    final publicCandidates = candidates
        .map(
          (candidate) => <String, Object?>{
            'intent_code': candidate['intent_code'],
            'score': double.parse(
              (candidate['score'] as double).toStringAsFixed(6),
            ),
            'eligible': candidate['eligible'],
            'exclusion_reasons': candidate['exclusion_reasons'],
            'contributions': candidate['contributions'],
          },
        )
        .toList(growable: false);
    return PhoneRecommendationExecution(
      status: items.isEmpty ? 'ABSTAINED' : 'READY',
      reasonCode: items.isEmpty
          ? (forceRetry
                ? 'DATA_QUALITY_FALLBACK_UNAVAILABLE'
                : 'NO_ELIGIBLE_POSITIVE_CANDIDATE')
          : null,
      items: items,
      features: features,
      candidates: publicCandidates,
    );
  }

  Map<String, double> encodeFeatures(
    PhoneRecommendationContext context,
    PhoneRecommendationRequestContext request,
    DateTime now,
  ) {
    final values = {for (final id in phoneFeatureIds) id: 0.0};
    for (final tag in context.tags) {
      final id = tag.tagKey == 'source_conflict_observed'
          ? 'source_conflict'
          : tag.tagKey == 'distribution_shift_observed'
          ? 'distribution_shift'
          : tag.tagKey;
      if (values.containsKey(id) && tag.tagValue['active'] != false)
        values[id] = _max(values[id]!, tag.weight * tag.confidence);
    }
    values['recovery_need'] = _max(
      values['relative_hrv_suppressed']!,
      _max(
        values['relative_hr_elevated']!,
        values['relative_resp_rate_elevated']!,
      ),
    );
    final localHour = now
        .toUtc()
        .add(Duration(minutes: request.timezoneOffsetMinutes))
        .hour;
    values['is_night'] = localHour >= 21 || localHour < 6 ? 1 : 0;
    values['before_23'] = localHour < 23 ? 1 : 0;
    values['can_walk'] = request.canWalk ? 1 : 0;
    values['alcohol_goal'] = request.alcoholGoal ? 1 : 0;
    final fresh = context.isFresh(now);
    values['verified_plan'] =
        fresh && context.verifiedPlan && context.verifiedPlanId != null ? 1 : 0;
    values['verified_diagnosis'] = fresh && context.verifiedDiagnosis ? 1 : 0;
    values['checkup_due'] = fresh && context.checkupDue ? 1 : 0;
    values['commercial_consent'] =
        fresh && context.consentScopes.contains('commercial_recommendation')
        ? 1
        : 0;
    values['medical_service_consent'] =
        fresh &&
            context.consentScopes.contains('medical_service_recommendation')
        ? 1
        : 0;
    values['insurance_consent'] =
        fresh && context.consentScopes.contains('insurance_recommendation')
        ? 1
        : 0;
    values['state_confidence'] =
        (1 - values['data_insufficient']! - .5 * values['source_conflict']!)
            .clamp(0, 1)
            .toDouble();
    values['data_coverage'] =
        (1 - values['data_insufficient']! - .6 * values['low_data_coverage']!)
            .clamp(0, 1)
            .toDouble();
    return values;
  }

  List<String> exclusions(
    PhoneCatalogItem item,
    PhoneRecommendationContext context,
    PhoneRecommendationRequestContext request,
    DateTime now,
  ) {
    final reasons = <String>[];
    PhoneRecommendationIntent? intent;
    for (final candidate in phoneRecommendationIntents) {
      if (candidate.code == item.intentCode) {
        intent = candidate;
        break;
      }
    }
    if (intent == null || intent.kind != item.itemKind)
      reasons.add('UNKNOWN_OR_MISMATCHED_INTENT');
    if (item.approvalStatus != 'APPROVED' || item.dataOrigin != 'REAL')
      reasons.add('CONTENT_NOT_APPROVED');
    final fresh = context.isFresh(now);
    for (final scope in {...?intent?.requiredScopes, ...item.consentScope}) {
      if (!fresh || !context.consentScopes.contains(scope))
        reasons.add('MISSING_CONSENT:$scope');
    }
    if (intent?.requiredFact == 'VERIFIED_PLAN' &&
        (!fresh || !context.verifiedPlan || context.verifiedPlanId == null))
      reasons.add('VERIFIED_PLAN_REQUIRED');
    if (intent?.requiredFact == 'VERIFIED_DIAGNOSIS' &&
        (!fresh || !context.verifiedDiagnosis))
      reasons.add('VERIFIED_DIAGNOSIS_REQUIRED');
    if (intent?.requiredFact == 'ALCOHOL_GOAL' && !request.alcoholGoal)
      reasons.add('EXPLICIT_ALCOHOL_GOAL_REQUIRED');
    if (intent?.requiredFact == 'ALCOHOL_GOAL' &&
        !request.alcoholWithdrawalRiskCleared)
      reasons.add('ALCOHOL_WITHDRAWAL_RISK_CLEARANCE_REQUIRED');
    if (item.intentCode == 'TASK.WALK.LIGHT' && !request.canWalk)
      reasons.add('WALKING_CONTEXT_REQUIRED');
    if ({'child', 'teen', 'minor'}.contains(context.ageGroup?.toLowerCase()) &&
        {'GOODS', 'SERVICE'}.contains(item.itemKind))
      reasons.add('MINOR_COMMERCIAL_RESTRICTION');
    return reasons;
  }
}

double _max(double left, double right) => left > right ? left : right;
