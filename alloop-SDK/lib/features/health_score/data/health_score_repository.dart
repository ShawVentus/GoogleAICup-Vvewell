import '../../../core/database/local_health_database.dart';

class HealthScoreRepository {
  HealthScoreRepository({LocalHealthDatabase? database})
    : _database = database ?? LocalHealthDatabase.instance;

  final LocalHealthDatabase _database;

  Future<List<Map<String, Object?>>> loadRecentReadings() =>
      _database.loadVitalReadings(
        start: DateTime.now().subtract(const Duration(days: 90)),
      );

  Future<Set<String>> loadCompletedInterventions() =>
      _database.loadHealthInterventions(day: DateTime.now());

  Future<void> setInterventionCompleted(
    String interventionId,
    bool completed,
  ) => _database.saveHealthIntervention(
    actionId: interventionId,
    completed: completed,
    day: DateTime.now(),
  );
}
