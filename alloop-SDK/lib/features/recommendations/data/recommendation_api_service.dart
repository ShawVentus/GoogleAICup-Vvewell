import 'dart:convert';
import 'dart:io';

import '../../cloud_sync/data/cloud_measurement_sync_service.dart';
import '../domain/recommendation_models.dart';

export '../domain/recommendation_models.dart';

class RecommendationApiService {
  RecommendationApiService({HttpClient? client})
    : _client = client ?? HttpClient();

  static const _baseUrl = String.fromEnvironment('RECOMMENDATION_API_URL');
  final HttpClient _client;

  Future<RecommendationPlan> load() async {
    if (_baseUrl.isEmpty) {
      throw const CloudSyncConfigurationException(
        'Recommendation API is not configured for this build.',
      );
    }
    final cloud = CloudMeasurementSyncService.instance;
    if (cloud.currentAccessToken == null) await cloud.ensureDemoSession();
    final memberId = cloud.configuredMemberId;
    if (memberId == null) {
      throw const CloudSyncConfigurationException(
        'Cloud member is not configured.',
      );
    }
    final payload = await _request(
      'POST',
      '/v1/recommendations',
      body: {
        'member_id': memberId,
        'surface': 'health_home',
        'limit': 3,
        'allowed_item_kinds': ['ADVICE', 'TASK', 'GOODS', 'SERVICE'],
        'context': {
          'timezoneOffsetMinutes': DateTime.now().timeZoneOffset.inMinutes,
        },
      },
    );
    final decisionId = payload['decision_id']?.toString() ?? '';
    final items = (payload['items'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (item) =>
              RecommendationItem.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
    if (decisionId.isEmpty)
      throw const FormatException(
        'Recommendation response has no decision ID.',
      );
    return RecommendationPlan(
      decisionId: decisionId,
      status: payload['status']?.toString() ?? 'ABSTAINED',
      reasonCode: payload['reason_code']?.toString(),
      items: items,
    );
  }

  Future<void> recordImpression(
    String decisionId,
    RecommendationItem item, {
    required String sessionId,
    required int displayedRank,
  }) async {
    final memberId = CloudMeasurementSyncService.instance.configuredMemberId;
    if (memberId == null) return;
    await _request(
      'POST',
      '/v1/recommendations/$decisionId/events',
      body: {
        'member_id': memberId,
        'catalog_item_id': item.catalogItemId,
        'event_type': 'IMPRESSION',
        'occurred_at': DateTime.now().toUtc().toIso8601String(),
        'client_event_id':
            'impression:$sessionId:$decisionId:${item.catalogItemId}',
        'source': 'panda_home',
        'metadata': {
          'surface': 'home_panda',
          'session_id': sessionId,
          'displayed_rank': displayedRank,
          'intent_code': item.intentCode,
          'item_kind': item.itemKind,
        },
      },
    );
  }

  Future<void> updateTask(
    RecommendationItem item,
    String status, {
    required String sessionId,
    required int displayedRank,
  }) async {
    final taskId = item.taskId;
    if (taskId == null || taskId.isEmpty)
      throw const FormatException('Task instance was not persisted.');
    await _request(
      'PATCH',
      '/v1/health-tasks/$taskId',
      body: {
        'status': status,
        'progress': status == 'completed' ? 1 : 0,
        'clientEventId': '$status:$taskId',
        'occurredAt': DateTime.now().toUtc().toIso8601String(),
        'metadata': {
          'surface': 'home_panda',
          'session_id': sessionId,
          'displayed_rank': displayedRank,
          'intent_code': item.intentCode,
        },
      },
    );
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    required Map<String, dynamic> body,
  }) async {
    final token = CloudMeasurementSyncService.instance.currentAccessToken;
    if (token == null) throw const CloudSyncAuthRequiredException();
    final request = await _client.openUrl(
      method,
      Uri.parse('${_baseUrl.replaceAll(RegExp(r'/$'), '')}$path'),
    );
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    request.write(jsonEncode(body));
    final response = await request.close().timeout(const Duration(seconds: 12));
    final text = await utf8.decoder.bind(response).join();
    final decoded = text.isEmpty ? <String, dynamic>{} : jsonDecode(text);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map ? decoded['message']?.toString() : null;
      throw HttpException(
        message ?? 'Recommendation request failed (${response.statusCode}).',
      );
    }
    if (decoded is! Map)
      throw const FormatException('Recommendation API returned invalid JSON.');
    return Map<String, dynamic>.from(decoded);
  }
}
