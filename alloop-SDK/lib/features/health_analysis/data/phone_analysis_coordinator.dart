import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import '../../../core/database/local_health_database.dart';
import '../../../foundations/log/al_logger.dart';
import '../../cloud_sync/domain/l0_fusion_engine.dart';
import '../../recommendations/domain/phone_recommendation_policy.dart';
import '../domain/canonical_contract.dart';
import '../domain/phone_health_analyzer.dart';

class PhoneAnalysisRunSummary {
  const PhoneAnalysisRunSummary({
    required this.analysisId,
    required this.decisionId,
    required this.status,
    required this.itemCount,
  });

  final String analysisId;
  final String decisionId;
  final String status;
  final int itemCount;
}

class PhoneAnalysisCoordinator {
  PhoneAnalysisCoordinator._();

  static final instance = PhoneAnalysisCoordinator._();
  static const _logTag = 'PHONE_ANALYSIS';
  static const _measurementSettleDelay = Duration(milliseconds: 750);
  static const _maximumMeasurementDelay = Duration(seconds: 5);

  String Function()? _memberIdProvider;
  bool _running = false;
  bool _rerunRequested = false;
  Future<void>? _activeRun;
  Timer? _measurementTimer;
  DateTime? _measurementQueueStartedAt;

  void install({String Function()? memberIdProvider}) {
    _memberIdProvider = memberIdProvider;
    LocalHealthDatabase.onRealVitalReadingSaved = notifyReadingSaved;
    LocalHealthDatabase.onMeasurementBlockCompleted = flushMeasurementBlock;
  }

  /// Coalesces bursty history imports and continuous sensor packets into one
  /// analysis run, while guaranteeing that live streams cannot defer forever.
  Future<void> notifyReadingSaved() {
    final now = DateTime.now();
    _measurementQueueStartedAt ??= now;
    _measurementTimer?.cancel();
    if (now.difference(_measurementQueueStartedAt!) >=
        _maximumMeasurementDelay) {
      _measurementQueueStartedAt = null;
      AlLogger.debug(
        'Measurement stream reached analysis deadline',
        tag: _logTag,
      );
      return schedule();
    }
    _measurementTimer = Timer(_measurementSettleDelay, () {
      _measurementTimer = null;
      _measurementQueueStartedAt = null;
      AlLogger.debug(
        'Measurement block settled; scheduling analysis',
        tag: _logTag,
      );
      unawaited(schedule());
    });
    return Future.value();
  }

  Future<void> flushMeasurementBlock() {
    final hadQueuedReadings = _measurementQueueStartedAt != null;
    _measurementTimer?.cancel();
    _measurementTimer = null;
    _measurementQueueStartedAt = null;
    if (!hadQueuedReadings) return Future.value();
    AlLogger.debug(
      'Measurement block completed; scheduling analysis',
      tag: _logTag,
    );
    return schedule();
  }

  Future<void> schedule() {
    if (_running) {
      _rerunRequested = true;
      return _activeRun ?? Future.value();
    }
    _activeRun = _drain();
    return _activeRun!;
  }

  Future<void> _drain() async {
    _running = true;
    try {
      do {
        _rerunRequested = false;
        try {
          await runNow();
        } on Object catch (error, stackTrace) {
          AlLogger.error(
            'Local phone analysis failed: $error',
            tag: _logTag,
            error: error,
            stackTrace: stackTrace,
          );
        }
      } while (_rerunRequested);
    } finally {
      _running = false;
      _activeRun = null;
    }
  }

  Future<PhoneAnalysisRunSummary> runNow({DateTime? asOf}) async {
    final localNow = asOf ?? DateTime.now();
    final timezoneOffsetMinutes = localNow.timeZoneOffset.inMinutes;
    final now = localNow.toUtc();
    final database = LocalHealthDatabase.instance;
    final readings = await database.loadVitalReadings(
      start: now.subtract(const Duration(days: 7)),
      end: now,
      limit: 5000,
    );
    final previous = await database.loadAnalysisInputs(
      start: now.subtract(const Duration(days: 7)),
      end: now,
    );
    final catalog = await _loadCatalog(previous['context']);
    final memberId =
        _memberIdProvider?.call() ?? LocalHealthDatabase.defaultUserId;
    final context = _contextFromCache(
      memberId: memberId,
      cache: previous['context'],
      catalog: catalog,
      tags: const [],
    );
    final existingFused = (previous['fusedMetrics'] as List? ?? const [])
        .whereType<Map>()
        .map((row) => Map<String, Object?>.from(row))
        .toList(growable: false);

    final computed = await Isolate.run(
      () => _computePhoneAnalysis(
        readings: readings,
        existingFused: existingFused,
        memberId: memberId,
        asOf: now,
        timezoneOffsetMinutes: timezoneOffsetMinutes,
        context: context,
      ),
    );
    final previousRun = (previous['analysisRun'] as Map?)?.map(
      (key, value) => MapEntry(key.toString(), value),
    );
    final computedRun = (computed.bundle['analysisRun'] as Map?)?.map(
      (key, value) => MapEntry(key.toString(), value),
    );
    if (previousRun?['input_fingerprint'] ==
        computedRun?['input_fingerprint']) {
      AlLogger.debug(
        'Local analysis skipped: measurement input is unchanged',
        tag: _logTag,
      );
      return computed.summary;
    }
    await database.saveAnalysisBundle(computed.bundle);
    AlLogger.info(
      'Local phone analysis committed: analysis=${computed.summary.analysisId}, '
      'decision=${computed.summary.decisionId}, items=${computed.summary.itemCount}',
      tag: _logTag,
    );
    return computed.summary;
  }

  Future<List<PhoneCatalogItem>> _loadCatalog(Object? rawCache) async {
    if (rawCache is Map) {
      final encoded = rawCache['catalog_json'];
      if (encoded is String && encoded.isNotEmpty) {
        final decoded = jsonDecode(encoded);
        if (decoded is List) {
          return decoded
              .whereType<Map>()
              .map(
                (item) =>
                    PhoneCatalogItem.fromJson(Map<String, Object?>.from(item)),
              )
              .toList(growable: false);
        }
      }
    }
    return PhoneCatalogLoader.load();
  }
}

class _ComputedPhoneAnalysis {
  const _ComputedPhoneAnalysis(this.bundle, this.summary);
  final Map<String, Object?> bundle;
  final PhoneAnalysisRunSummary summary;
}

_ComputedPhoneAnalysis _computePhoneAnalysis({
  required List<Map<String, Object?>> readings,
  required List<Map<String, Object?>> existingFused,
  required String memberId,
  required DateTime asOf,
  required int timezoneOffsetMinutes,
  required PhoneRecommendationContext context,
}) {
  final l0 = const L0FusionEngine().process(readings);
  final freshFused = l0.outputs.map(PhoneFusedMetric.fromL0).toList();
  final allById = <String, PhoneFusedMetric>{
    for (final row in existingFused)
      PhoneFusedMetric.fromMap(row).id: PhoneFusedMetric.fromMap(row),
    for (final row in freshFused) row.id: row,
  };
  final analysis = const PhoneHealthAnalyzer().analyze(
    memberId,
    asOf,
    allById.values.toList(),
  );
  final recommendationContext = PhoneRecommendationContext(
    memberId: context.memberId,
    ageGroup: context.ageGroup,
    tags: analysis.tags,
    consentScopes: context.consentScopes,
    verifiedDiagnosis: context.verifiedDiagnosis,
    verifiedPlan: context.verifiedPlan,
    verifiedPlanId: context.verifiedPlanId,
    checkupDue: context.checkupDue,
    careEscalation: context.careEscalation,
    catalogItems: context.catalogItems,
    contextExpiresAt: context.contextExpiresAt,
  );
  final execution = const PhoneRecommendationPolicy().execute(
    recommendationContext,
    PhoneRecommendationRequestContext(
      timezoneOffsetMinutes: timezoneOffsetMinutes,
    ),
    asOf,
  );
  final clientRequestId = deterministicUuid(
    'request:$memberId:${pythonIso(asOf)}:${analysis.inputFingerprint}:$phoneRecommendationPolicyVersion',
  );
  final decisionId = deterministicUuid('decision:$clientRequestId');
  final taskRows = <Map<String, Object?>>[];
  final planItems = <Map<String, Object?>>[];
  for (final original in execution.items) {
    final item = Map<String, Object?>.from(original);
    final task = item['task'];
    if (task is Map) {
      final catalogId = item['catalog_item_id'].toString();
      final taskId = deterministicUuid('task:$decisionId:$catalogId');
      final taskJson = Map<String, Object?>.from(task);
      taskJson['task_id'] = taskId;
      taskJson['client_task_id'] = 'task:$decisionId:$catalogId';
      item['task'] = taskJson;
      final dueAt = DateTime.parse(taskJson['due_at'].toString()).toUtc();
      final payload = <String, Object?>{
        'id': taskId,
        'decision_id': decisionId,
        'member_id': memberId,
        'catalog_item_id': catalogId,
        'title_snapshot': item['title'],
        'goal_snapshot': taskJson['goal'] ?? const {},
        'due_at': pythonIso(dueAt),
        'status': 'pending',
        'progress': 0,
        'client_task_id': taskJson['client_task_id'],
        'data_origin': analysis.dataOrigin,
      };
      taskRows.add({
        'id': taskId,
        'decision_id': decisionId,
        'catalog_item_id': catalogId,
        'title_snapshot': item['title'],
        'goal_snapshot_json': canonicalJson(taskJson['goal'] ?? const {}),
        'due_at': dueAt.millisecondsSinceEpoch,
        'status': 'pending',
        'progress': 0.0,
        'client_task_id': taskJson['client_task_id'],
        'payload_json': canonicalJson(payload),
      });
    }
    planItems.add(item);
  }
  final finalPlan = <String, Object?>{
    ...execution.toJson(),
    'decision_id': decisionId,
    'items': planItems,
  };
  final contextSnapshot = <String, Object?>{
    'age_group': context.ageGroup,
    'consent_scopes': context.consentScopes,
    'verified_diagnosis': context.verifiedDiagnosis,
    'verified_plan': context.verifiedPlan,
    'verified_plan_id': context.verifiedPlanId,
    'checkup_due': context.checkupDue,
    'care_escalation': context.careEscalation,
    'context_expires_at': context.contextExpiresAt == null
        ? null
        : pythonIso(context.contextExpiresAt!),
  };
  final decisionPayload = <String, Object?>{
    'id': decisionId,
    'member_id': memberId,
    'client_request_id': clientRequestId,
    'decided_at': pythonIso(asOf),
    'expires_at': pythonIso(asOf.add(const Duration(hours: 24))),
    'surface': 'health_home',
    'status': execution.status,
    'context_snapshot': contextSnapshot,
    'health_tag_snapshot': analysis.tags.map((tag) => tag.toPayload()).toList(),
    'candidate_snapshot': execution.candidates,
    'final_plan': finalPlan,
    'feature_schema_version': phoneFeatureSchemaVersion,
    'matrix_version': phoneMatrixVersion,
    'registry_version': phoneRegistryVersion,
    'policy_version': phoneRecommendationPolicyVersion,
    'safety_version': phoneRecommendationSafetyVersion,
    'data_origin': analysis.dataOrigin,
  };
  final decisionRow = <String, Object?>{
    'id': decisionId,
    'client_request_id': clientRequestId,
    'decided_at': asOf.millisecondsSinceEpoch,
    'expires_at': asOf.add(const Duration(hours: 24)).millisecondsSinceEpoch,
    'surface': 'health_home',
    'status': execution.status,
    'context_snapshot_json': canonicalJson(contextSnapshot),
    'health_tag_snapshot_json': canonicalJson(
      decisionPayload['health_tag_snapshot'],
    ),
    'candidate_snapshot_json': canonicalJson(execution.candidates),
    'final_plan_json': canonicalJson(finalPlan),
    'feature_schema_version': phoneFeatureSchemaVersion,
    'matrix_version': phoneMatrixVersion,
    'registry_version': phoneRegistryVersion,
    'policy_version': phoneRecommendationPolicyVersion,
    'safety_version': phoneRecommendationSafetyVersion,
    'data_origin': analysis.dataOrigin,
    'payload_json': canonicalJson(decisionPayload),
  };
  final tagRows = analysis.tags
      .map((tag) => tag.toLocalMap(analysis.analysisId))
      .toList();
  final outbox = <Map<String, Object?>>[];
  void enqueue(String type, String id, Object payload) {
    final encoded = canonicalJson(payload);
    outbox.add({
      'entity_type': type,
      'local_id': id,
      'operation': 'UPSERT',
      'payload_hash': sha256Hex(jsonDecode(encoded)),
      'payload_json': encoded,
    });
  }

  if (analysis.dataOrigin == 'REAL') {
    for (final row in freshFused) enqueue('FUSED_METRIC', row.id, row.payload);
    enqueue('ANALYSIS_RUN', analysis.analysisId, analysis.toPayload());
    for (var i = 0; i < analysis.tags.length; i++) {
      enqueue('HEALTH_TAG', tagRows[i]['id'].toString(), {
        ...analysis.tags[i].toPayload(),
        'analysis_id': analysis.analysisId,
      });
    }
    enqueue('DECISION', decisionId, decisionPayload);
    for (final row in taskRows) {
      enqueue(
        'TASK',
        row['id'].toString(),
        jsonDecode(row['payload_json'].toString()),
      );
    }
  }

  return _ComputedPhoneAnalysis(
    {
      'fusedMetrics': freshFused.map((row) => row.toLocalMap()).toList(),
      'analysisRun': analysis.toLocalRun(),
      'metricStates': analysis.states
          .map((state) => state.toLocalMap(analysis.analysisId))
          .toList(),
      'healthTags': tagRows,
      'decision': decisionRow,
      'tasks': taskRows,
      'outbox': outbox,
    },
    PhoneAnalysisRunSummary(
      analysisId: analysis.analysisId,
      decisionId: decisionId,
      status: execution.status,
      itemCount: planItems.length,
    ),
  );
}

PhoneRecommendationContext _contextFromCache({
  required String memberId,
  required Object? cache,
  required List<PhoneCatalogItem> catalog,
  required List<PhoneHealthTag> tags,
}) {
  Map<String, Object?> values = const {};
  DateTime? expiresAt;
  if (cache is Map) {
    final encoded = cache['context_json'];
    if (encoded is String && encoded.isNotEmpty) {
      final decoded = jsonDecode(encoded);
      if (decoded is Map) values = Map<String, Object?>.from(decoded);
    }
    final rawExpiry = cache['expires_at'];
    if (rawExpiry is num) {
      expiresAt = DateTime.fromMillisecondsSinceEpoch(
        rawExpiry.toInt(),
        isUtc: true,
      );
    }
  }
  return PhoneRecommendationContext(
    memberId: memberId,
    ageGroup: values['age_group']?.toString(),
    tags: tags,
    consentScopes: (values['consent_scopes'] as List? ?? const [])
        .map((item) => item.toString())
        .toList(),
    verifiedDiagnosis: values['verified_diagnosis'] == true,
    verifiedPlan: values['verified_plan'] == true,
    verifiedPlanId: values['verified_plan_id']?.toString(),
    checkupDue: values['checkup_due'] == true,
    careEscalation: values['care_escalation'] == true,
    catalogItems: catalog,
    contextExpiresAt: expiresAt,
  );
}
