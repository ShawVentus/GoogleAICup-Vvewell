import 'dart:async';

import 'package:aizoring_blue_lite/aizoring_blue_lite.dart';
import 'package:get/get.dart';

import '../../../../core/database/local_health_database.dart';
import '../../data/repositories/measurement_history_repository.dart';
import '../../domain/models/measurement_record.dart';

/// Controller for AIZORING historical health data — both from the ring
/// and from local measurement history.
class AizoringHealthDataController extends GetxController {
  final String deviceId;
  final AizoringBlueLite _aizoring = AizoringBlueLite.instance;
  final MeasurementHistoryRepository _historyRepo =
      MeasurementHistoryRepository();

  final RxList<AizoHealthData> ringRecords = <AizoHealthData>[].obs;
  final RxList<MeasurementRecord> localRecords = <MeasurementRecord>[].obs;
  final RxBool isLoading = false.obs;
  final Rx<DateTime> selectedDate = DateTime.now().obs;

  StreamSubscription<List<AizoHealthData>>? _healthSub;
  StreamSubscription<Map<dynamic, dynamic>>? _stateSub;

  AizoringHealthDataController({required this.deviceId});

  @override
  void onInit() {
    super.onInit();
    _healthSub = _aizoring.healthDataStream.listen((list) {
      ringRecords.addAll(list);
      unawaited(_persistRingHealthData(list));
    });
    _stateSub = _aizoring.healthDataStateStream.listen((_) {
      isLoading.value = false;
    });
    // Load local records immediately
    _loadLocalRecords();
  }

  @override
  void onClose() {
    _healthSub?.cancel();
    _stateSub?.cancel();
    super.onClose();
  }

  /// Total record count (local + ring).
  int get totalCount => localRecords.length + ringRecords.length;

  Future<void> fetchRingData() async {
    isLoading.value = true;
    ringRecords.clear();
    final dayStart = DateTime(
      selectedDate.value.year,
      selectedDate.value.month,
      selectedDate.value.day,
    );
    final timestamp = dayStart.millisecondsSinceEpoch ~/ 1000;
    await _aizoring.getHealthData(timestamp);
  }

  Future<void> _loadLocalRecords() async {
    localRecords.value = await _historyRepo.loadForDate(
      selectedDate.value,
      deviceId: deviceId,
    );
  }

  Future<void> _persistRingHealthData(List<AizoHealthData> records) async {
    for (final record in records) {
      await LocalHealthDatabase.instance.saveVitalReading(
        source: 'aizo_ring',
        deviceId: deviceId,
        recordedAt: LocalHealthDatabase.fromUnixSeconds(record.timestamp),
        heartRate: record.heartRate?.toDouble(),
        spo2: record.bloodOxygen?.toDouble(),
        temperature: record.bodyTemp,
        steps: record.steps,
        rawData: {
          'recordKind': 'health_history',
          'timestamp': record.timestamp,
          'heartRate': record.heartRate,
          'bloodOxygen': record.bloodOxygen,
          'steps': record.steps,
          'bodyTemp': record.bodyTemp,
          'envTemp': record.envTemp,
          'calories': record.calories,
          'distance': record.distance,
        },
      );
    }
    await LocalHealthDatabase.notifyMeasurementBlockCompleted();
  }

  /// Refresh when date changes.
  void onDateChanged(DateTime date) {
    selectedDate.value = date;
    _loadLocalRecords();
  }
}
