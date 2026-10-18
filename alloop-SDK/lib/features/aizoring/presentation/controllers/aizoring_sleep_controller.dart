import 'dart:async';

import 'package:aizoring_blue_lite/aizoring_blue_lite.dart';
import 'package:get/get.dart';

/// Controller for AIZORING sleep data.
class AizoringSleepController extends GetxController {
  final String deviceId;
  final AizoringBlueLite _aizoring = AizoringBlueLite.instance;

  final RxList<AizoSleepRecord> records = <AizoSleepRecord>[].obs;
  final RxBool isLoading = false.obs;
  final Rx<DateTime> selectedDate = DateTime.now().obs;

  StreamSubscription<List<AizoSleepRecord>>? _sleepSub;

  AizoringSleepController({required this.deviceId});

  @override
  void onInit() {
    super.onInit();
    _sleepSub = _aizoring.sleepDataStream.listen((list) {
      records.value = list;
      isLoading.value = false;
    });
  }

  @override
  void onClose() {
    _sleepSub?.cancel();
    super.onClose();
  }

  Future<void> fetchSleepData() async {
    isLoading.value = true;
    records.clear();
    final dayStart = DateTime(
      selectedDate.value.year,
      selectedDate.value.month,
      selectedDate.value.day,
    );
    final timestamp = dayStart.millisecondsSinceEpoch ~/ 1000;
    await _aizoring.getSleepData(timestamp);
  }
}
