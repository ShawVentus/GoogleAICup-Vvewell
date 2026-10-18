import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class WebCloud extends ChangeNotifier {
  WebCloud._();
  static final instance = WebCloud._();
  List<Map<String, dynamic>> profiles = [];
  List<Map<String, dynamic>> readings = [];
  String? memberId;
  String? error;

  Future<dynamic> request(String path, {Map<String, dynamic>? body}) async {
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    if (token == null &&
        !['/api/consult', '/api/ocr', '/api/recommend'].contains(path)) {
      throw StateError('Sign in to view your records.');
    }
    final uri = Uri.base.resolve(path);
    final headers = {
      if (token != null) 'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
    final response = body == null
        ? await http
              .get(uri, headers: headers)
              .timeout(const Duration(seconds: 30))
        : await http
              .post(uri, headers: headers, body: jsonEncode(body))
              .timeout(const Duration(seconds: 30));
    final payload = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode != 200) {
      throw StateError(
        payload is Map
            ? '${payload['error'] ?? 'Unable to load records.'}'
            : 'Unable to load records.',
      );
    }
    return payload;
  }

  Future<void> refresh() async {
    error = null;
    try {
      final payload = await request('/api/cloud/profiles');
      profiles = List<Map<String, dynamic>>.from(payload['profiles']);
      if (!profiles.any((p) => p['id'] == memberId))
        memberId = profiles.firstOrNull?['id'];
      readings = memberId == null
          ? []
          : List<Map<String, dynamic>>.from(
              (await request(
                '/api/cloud/readings?member_id=$memberId',
              ))['readings'],
            );
    } catch (e) {
      error = 'Unable to load cloud records. Please try again.';
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<void> selectMember(String id) async {
    if (!profiles.any((p) => p['id'] == id))
      throw ArgumentError('Unknown member');
    memberId = id;
    readings = [];
    notifyListeners();
    await refresh();
  }

  void clear() {
    profiles = [];
    readings = [];
    memberId = null;
    error = null;
    notifyListeners();
  }

  List<Map<String, Object?>> localReadings(Map<String, Object?> arguments) {
    const keys = {
      'heart_rate': 'heart_rate',
      'blood_oxygen': 'spo2',
      'spo2': 'spo2',
      'body_temperature': 'temperature_c',
      'skin_temp': 'temperature_c',
      'hrv': 'hrv',
      'stress': 'stress',
      'steps': 'steps',
      'sleep_duration': 'sleep_duration',
    };
    return readings
        .where((r) {
          final timestamp = DateTime.parse(
            r['recorded_at'],
          ).millisecondsSinceEpoch;
          final start = arguments['start'] as int?;
          final end = arguments['end'] as int?;
          final source = arguments['source'];
          return (start == null || timestamp >= start) &&
              (end == null || timestamp <= end) &&
              (source == null || r['source'] == source);
        })
        .map(
          (r) => <String, Object?>{
            'id': r['id'],
            'source': r['source'],
            'recorded_at': DateTime.parse(
              r['recorded_at'],
            ).millisecondsSinceEpoch,
            'is_valid': r['is_valid'] == true ? 1 : 0,
            'is_abnormal': r['is_abnormal'] == true ? 1 : 0,
            'is_mock': 0,
            'synced': 1,
            if (keys[r['metric_type']] != null)
              keys[r['metric_type']]!: r['value'],
          },
        )
        .toList();
  }
}
