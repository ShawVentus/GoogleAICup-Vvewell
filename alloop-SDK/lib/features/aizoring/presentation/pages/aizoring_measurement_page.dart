import 'package:aizoring_blue_lite/aizoring_blue_lite.dart';
import 'package:alloop/features/common/presentation/widgets/common_title_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../controllers/aizoring_measurement_controller.dart';

/// AIZORING instant measurement page.
class AizoringMeasurementPage extends GetView<AizoringMeasurementController> {
  final String deviceId;

  const AizoringMeasurementPage({super.key, required this.deviceId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: CommonTitleText(title: 'Instant Measurement'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTypeSelector(),
            SizedBox(height: 16.h),
            _buildControlButtons(),
            SizedBox(height: 16.h),
            _buildResultCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(12.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Measurement Type',
                style:
                    TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
            SizedBox(height: 8.h),
            Obx(
              () => Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                children: controller.supportedTypes
                    .map((t) => ChoiceChip(
                          label: Text(
                            '${t['icon']} ${t['label']}',
                            style: TextStyle(fontSize: 12.sp),
                          ),
                          selected:
                              controller.selectedType.value == (t['type'] as int),
                          selectedColor: Colors.deepOrange.withValues(alpha: 0.3),
                          onSelected: controller.isMeasuring.value
                              ? null
                              : (_) => controller.selectType(t['type'] as int),
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButtons() {
    return Obx(
      () => Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: controller.isMeasuring.value
                  ? null
                  : controller.startMeasurement,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Measurement'),
              style: ElevatedButton.styleFrom(padding: EdgeInsets.all(14.h)),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: controller.isMeasuring.value
                  ? controller.stopMeasurement
                  : null,
              icon: const Icon(Icons.stop),
              label: const Text('Stop'),
              style: OutlinedButton.styleFrom(padding: EdgeInsets.all(14.h)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    return Obx(() {
      final result = controller.latestResult.value;
      final isMeasuring = controller.isMeasuring.value;

      return Card(
        child: Padding(
          padding: EdgeInsets.all(20.w),
          child: Column(
            children: [
              Text(
                controller.typeLabel,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              SizedBox(height: 16.h),
              if (isMeasuring)
                Column(
                  children: [
                    SizedBox(
                      width: 48.w,
                      height: 48.h,
                      child: const CircularProgressIndicator(strokeWidth: 3),
                    ),
                    SizedBox(height: 12.h),
                    Text('Measuring...',
                        style: TextStyle(
                            fontSize: 14.sp, color: Colors.grey.shade600)),
                  ],
                )
              else if (result != null)
                _buildSingleResult(result)
              else if (controller.isTimedOut.value)
                Column(
                  children: [
                    Icon(Icons.warning_amber, size: 48, color: Colors.orange),
                    SizedBox(height: 12.h),
                    Text('No response from device.\nThis measurement type may not be supported.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade600)),
                  ],
                )
              else
                Text(
                  'No measurement yet.\nSelect a type and tap Start.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 14.sp, color: Colors.grey.shade500),
                ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildSingleResult(AizoMeasureResult result) {
    final type = result.type; // actual measurement type from ring (1/2/6)
    String value;
    String unit;
    String icon;
    switch (type) {
      case AizoInstantMeasurementType.heartRate:
        value = '${result.heartRate ?? '--'}';
        unit = 'bpm';
        icon = '❤️';
      case AizoInstantMeasurementType.bloodOxygen:
        value = '${result.bloodOxygen ?? '--'}';
        unit = '%';
        icon = '🩸';
      case AizoInstantMeasurementType.temperature:
        value = result.bodyTemp?.toStringAsFixed(1) ?? '--';
        unit = '°C';
        icon = '🌡️';
      default:
        value = '--';
        unit = '';
        icon = '📊';
    }
    return Column(
      children: [
        Text(result.typeLabel,
            style: TextStyle(
                fontSize: 14.sp, color: Colors.grey.shade600)),
        SizedBox(height: 16.h),
        _bigValue(value, unit, icon),
      ],
    );
  }

  Widget _bigValue(String value, String unit, String icon) {
    return Column(
      children: [
        Text(icon, style: TextStyle(fontSize: 48.sp)),
        SizedBox(height: 8.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 48.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepOrange)),
            if (unit.isNotEmpty) ...[
              SizedBox(width: 4.w),
              Text(unit,
                  style: TextStyle(
                      fontSize: 18.sp, color: Colors.grey.shade600)),
            ],
          ],
        ),
      ],
    );
  }
}
