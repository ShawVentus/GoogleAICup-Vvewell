import 'dart:async';

import 'package:aizoring_blue_lite/aizoring_blue_lite.dart';
import 'package:get/get.dart';

/// Controller for AIZORING ECG measurement.
class AizoringEcgController extends GetxController {
  final String deviceId;
  final AizoringBlueLite _aizoring = AizoringBlueLite.instance;

  final RxBool isMeasuring = false.obs;
  final RxInt wearType = 0x01.obs; // 0x01=left, 0x02=right
  final RxList<double> ecgSamples = <double>[].obs;
  final Rx<AizoEcgResult?> ecgResult = Rx<AizoEcgResult?>(null);

  StreamSubscription<Map<dynamic, dynamic>>? _ecgSub;

  AizoringEcgController({required this.deviceId});

  @override
  void onInit() {
    super.onInit();
    _ecgSub = _aizoring.ecgStream.listen((map) {
      switch (map['kind']) {
        case 'ecgStart':
          isMeasuring.value = true;
          ecgSamples.clear();
          ecgResult.value = null;
        case 'ecgData':
          final samples = (map['samples'] as List<dynamic>?)
                  ?.map((e) => (e as num).toDouble())
                  .toList() ??
              [];
          ecgSamples.addAll(samples);
        case 'ecgError':
          isMeasuring.value = false;
        case 'ecgFinish':
          isMeasuring.value = false;
          ecgResult.value = AizoEcgResult.fromMap(map);
      }
    });
  }

  @override
  void onClose() {
    _ecgSub?.cancel();
    super.onClose();
  }

  Future<void> startEcg() async {
    if (isMeasuring.value) return;
    await _aizoring.startEcgMeasure(wearType: wearType.value);
  }

  Future<void> stopEcg() async {
    if (!isMeasuring.value) return;
    await _aizoring.stopEcgMeasure();
  }

  void setWearType(int type) {
    if (isMeasuring.value) return;
    wearType.value = type;
  }
}
