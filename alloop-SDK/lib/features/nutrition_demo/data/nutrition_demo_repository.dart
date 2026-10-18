import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class NutritionDemoRepository {
  static const _channel = MethodChannel('alloop/local_health_database');
  static const retention = Duration(days: 30);

  Future<String> copyPhoto(File source) async {
    final base = await getApplicationDocumentsDirectory();
    final folder = Directory(path.join(base.path, 'meal_photos'));
    await folder.create(recursive: true);
    final target = File(
      path.join(
        folder.path,
        'meal_${DateTime.now().millisecondsSinceEpoch}${path.extension(source.path)}',
      ),
    );
    return (await source.copy(target.path)).path;
  }

  Future<void> saveMeal(String photoPath, Map<String, dynamic> analysis) =>
      _channel.invokeMethod<void>('saveMealRecord', {
        'recordedAt': DateTime.now().millisecondsSinceEpoch,
        'photoPath': photoPath,
        'payload': jsonEncode(analysis),
        'isDemo': true,
      });

  Future<List<Map<String, dynamic>>> loadTodayMeals() async {
    final today = DateTime.now();
    final start = DateTime(
      today.year,
      today.month,
      today.day,
    ).millisecondsSinceEpoch;
    final rows =
        await _channel.invokeMethod<List<dynamic>>(
          'loadMealRecords',
          <String, dynamic>{'start': start},
        ) ??
        const <dynamic>[];
    return rows.whereType<Map>().map((row) {
      final payload = jsonDecode('${row['payload']}');
      return <String, dynamic>{
        'recordedAt': row['recorded_at'] ?? row['recordedAt'],
        'photoPath': row['photo_path'] ?? row['photoPath'],
        'analysis': payload,
      };
    }).toList();
  }

  Future<int> todayCalories() async {
    final today = DateTime.now();
    final start = DateTime(
      today.year,
      today.month,
      today.day,
    ).millisecondsSinceEpoch;
    final rows =
        await _channel.invokeMethod<List<dynamic>>('loadMealRecords', {
          'start': start,
        }) ??
        const [];
    return rows.whereType<Map>().fold<int>(0, (total, row) {
      final decoded = jsonDecode('${row['payload']}');
      final totals = decoded is Map ? decoded['totals'] : null;
      final value = totals is Map ? totals['kcal'] : null;
      return total + (value is num ? value.round() : 0);
    });
  }

  Future<void> cleanup() async {
    final before = DateTime.now().subtract(retention).millisecondsSinceEpoch;
    final paths =
        await _channel.invokeMethod<List<dynamic>>(
          'cleanupExpiredMealRecords',
          {'before': before},
        ) ??
        const [];
    for (final item in paths) {
      final file = File('$item');
      if (await file.exists()) await file.delete();
    }
  }
}
