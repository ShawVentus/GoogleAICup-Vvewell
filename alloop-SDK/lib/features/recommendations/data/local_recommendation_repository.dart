import 'dart:convert';

import '../../../core/database/local_health_database.dart';
import '../../health_analysis/domain/canonical_contract.dart';
import '../domain/recommendation_models.dart';

class LocalRecommendationRepository implements RecommendationRepository {
  const LocalRecommendationRepository({LocalHealthDatabase? database})
    : _database = database;

  final LocalHealthDatabase? _database;
  LocalHealthDatabase get _db => _database ?? LocalHealthDatabase.instance;

  @override
  Future<RecommendationPlan?> load() async {
    final stored = await _db.loadLatestRecommendation();
    final decisionRaw = stored['decision'];
    if (decisionRaw is! Map) return null;
    final decision = Map<String, Object?>.from(decisionRaw);
    final encoded = decision['final_plan_json']?.toString();
    if (encoded == null || encoded.isEmpty) return null;
    final decoded = jsonDecode(encoded);
    if (decoded is! Map)
      throw const FormatException('Invalid local recommendation plan.');
    final plan = Map<String, dynamic>.from(decoded);
    final taskRows = <String, Map<String, Object?>>{
      for (final raw in (stored['tasks'] as List? ?? const []))
        if (raw is Map) raw['id'].toString(): Map<String, Object?>.from(raw),
    };
    final items = (plan['items'] as List? ?? const [])
        .whereType<Map>()
        .map((raw) {
          final json = Map<String, dynamic>.from(raw);
          final item = RecommendationItem.fromJson(json);
          item.dataOrigin = decision['data_origin']?.toString() ?? 'REAL';
          final row = item.taskId == null ? null : taskRows[item.taskId];
          if (row != null)
            item.taskStatus = row['status']?.toString() ?? item.taskStatus;
          return item;
        })
        .toList(growable: false);
    return RecommendationPlan(
      decisionId: decision['id'].toString(),
      status:
          plan['status']?.toString() ??
          decision['status']?.toString() ??
          'ABSTAINED',
      reasonCode: plan['reason_code']?.toString(),
      items: items,
      analyzedAt: _time(decision['decided_at']),
      cloudSyncedAt: _time(decision['cloud_synced_at']),
    );
  }

  @override
  Future<void> recordImpression(
    String decisionId,
    RecommendationItem item, {
    required String sessionId,
    required int displayedRank,
  }) async {
    final occurredAt = DateTime.now().toUtc();
    final clientEventId =
        'impression:$sessionId:$decisionId:${item.catalogItemId}';
    final id = deterministicUuid('feedback:$clientEventId');
    final payload = _feedbackPayload(
      id: id,
      decisionId: decisionId,
      item: item,
      eventType: 'IMPRESSION',
      clientEventId: clientEventId,
      occurredAt: occurredAt,
      sessionId: sessionId,
      displayedRank: displayedRank,
    );
    await _db.appendLocalFeedback({
      ...payload,
      'occurred_at': occurredAt.millisecondsSinceEpoch,
      'metadata_json': canonicalJson(payload['metadata']),
      'payload_json': canonicalJson(payload),
      'outbox': _outbox('FEEDBACK', id, payload),
    }, createdAt: occurredAt);
  }

  @override
  Future<void> updateTask(
    RecommendationItem item,
    String status, {
    required String sessionId,
    required int displayedRank,
  }) async {
    final taskId = item.taskId;
    if (taskId == null || taskId.isEmpty)
      throw const FormatException('Local task identity is missing.');
    final latest = await load();
    if (latest == null) throw StateError('Local decision is missing.');
    final occurredAt = DateTime.now().toUtc();
    final eventType = status == 'completed' ? 'COMPLETE' : 'START';
    final clientEventId = '${status.toLowerCase()}:$taskId';
    final feedbackId = deterministicUuid('feedback:$clientEventId');
    final feedback = _feedbackPayload(
      id: feedbackId,
      decisionId: latest.decisionId,
      item: item,
      eventType: eventType,
      clientEventId: clientEventId,
      occurredAt: occurredAt,
      sessionId: sessionId,
      displayedRank: displayedRank,
    );
    final taskPayload = <String, Object?>{
      'id': taskId,
      'decision_id': latest.decisionId,
      'catalog_item_id': item.catalogItemId,
      'status': status,
      'progress': status == 'completed' ? 1.0 : 0.0,
      'updated_at': pythonIso(occurredAt),
      'data_origin': item.dataOrigin,
    };
    await _db.updateLocalTask(
      taskId: taskId,
      status: status,
      progress: status == 'completed' ? 1 : 0,
      occurredAt: occurredAt,
      payloadJson: canonicalJson(taskPayload),
      taskOutbox: _outbox('TASK', taskId, taskPayload),
      feedback: {
        ...feedback,
        'occurred_at': occurredAt.millisecondsSinceEpoch,
        'metadata_json': canonicalJson(feedback['metadata']),
        'payload_json': canonicalJson(feedback),
        'outbox': _outbox('FEEDBACK', feedbackId, feedback),
      },
    );
  }

  static Map<String, Object?> _feedbackPayload({
    required String id,
    required String decisionId,
    required RecommendationItem item,
    required String eventType,
    required String clientEventId,
    required DateTime occurredAt,
    required String sessionId,
    required int displayedRank,
  }) => {
    'id': id,
    'decision_id': decisionId,
    'catalog_item_id': item.catalogItemId,
    'event_type': eventType,
    'occurred_at': pythonIso(occurredAt),
    'client_event_id': clientEventId,
    'source': 'panda_home',
    'data_origin': item.dataOrigin,
    'metadata': {
      'surface': 'home_panda',
      'session_id': sessionId,
      'displayed_rank': displayedRank,
      'intent_code': item.intentCode,
      'item_kind': item.itemKind,
      'task_id': item.taskId,
    },
  };

  static Map<String, Object?> _outbox(String type, String id, Object payload) =>
      {
        'entity_type': type,
        'local_id': id,
        'operation': 'UPSERT',
        'payload_hash': sha256Hex(payload),
        'payload_json': canonicalJson(payload),
      };

  static DateTime? _time(Object? value) => value is num
      ? DateTime.fromMillisecondsSinceEpoch(value.toInt(), isUtc: true)
      : null;
}
