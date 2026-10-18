import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class RecommendationApi {
  RecommendationApi({http.Client? client, Uri? endpoint})
      : _client = client ?? http.Client(),
        _endpoint = endpoint ?? _defaultEndpoint();

  final http.Client _client;
  final Uri _endpoint;

  static Uri _defaultEndpoint() {
    const base = String.fromEnvironment('API_BASE_URL');
    if (base.isNotEmpty) return Uri.parse('$base/api/recommend');
    if (kIsWeb) return Uri.base.resolve('/api/recommend');
    throw StateError('Configure the backend using API_BASE_URL.');
  }

  Future<Map<String, dynamic>> recommend(Map<String, dynamic> form) async {
    try {
      final response = await _client.post(_endpoint,
          headers: {'Content-Type': 'application/json',
            'Authorization': 'Bearer ${Supabase.instance.client.auth.currentSession?.accessToken ?? ''}'}, body: jsonEncode(form))
          .timeout(const Duration(seconds: 90));
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is! Map<String, dynamic>) throw const FormatException();
      if (response.statusCode != 200) {
        throw RecommendationException(data['error'] is String
            ? data['error'] as String : 'Unable to get recommendations. Please try again.');
      }
      if (!const ['doctor_recommendation', 'department_fallback', 'emergency',
        'followup', 'no_department', 'no_results'].contains(data['type'])) {
        throw const FormatException();
      }
      return data;
    } on TimeoutException {
      throw const RecommendationException('The request timed out. Please try again.');
    } on http.ClientException {
      throw const RecommendationException('Unable to connect. Check your connection and try again.');
    } on FormatException {
      throw const RecommendationException('We could not read the server response. Please try again.');
    }
  }

  void close() => _client.close();
}

class RecommendationException implements Exception {
  const RecommendationException(this.message);
  final String message;
}
