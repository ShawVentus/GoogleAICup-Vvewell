import 'package:aizoring_blue_lite/aizoring_blue_lite.dart';
import 'package:alloop/features/common/presentation/widgets/common_title_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../domain/models/measurement_record.dart';
import '../controllers/aizoring_health_data_controller.dart';

/// AIZORING health data history page — shows local measurement records
/// and optionally ring-synced data.
class AizoringHealthDataPage extends GetView<AizoringHealthDataController> {
  final String deviceId;

  const AizoringHealthDataPage({super.key, required this.deviceId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: CommonTitleText(title: 'Health Data History'),
        actions: [
          Obx(() => controller.totalCount > 0
              ? Padding(
                  padding: EdgeInsets.only(right: 12.w),
                  child: Chip(
                    label: Text('${controller.totalCount} records',
                        style: TextStyle(fontSize: 11.sp)),
                    backgroundColor: Colors.deepOrange.withAlpha(30),
                  ),
                )
              : const SizedBox.shrink()),
        ],
      ),
      body: Column(
        children: [
          _buildDateSelector(),
          Expanded(child: _buildRecordsList()),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    return Padding(
      padding: EdgeInsets.all(16.w),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              controller.onDateChanged(controller.selectedDate.value
                  .subtract(const Duration(days: 1)));
            },
          ),
          Expanded(
            child: InkWell(
              onTap: () async {
                final date = await showDatePicker(
                  context: Get.context!,
                  initialDate: controller.selectedDate.value,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (date != null) controller.onDateChanged(date);
              },
              child: Obx(
                () => Text(
                  DateFormat('yyyy-MM-dd')
                      .format(controller.selectedDate.value),
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              final next = controller.selectedDate.value
                  .add(const Duration(days: 1));
              if (!next.isAfter(DateTime.now())) {
                controller.onDateChanged(next);
              }
            },
          ),
          SizedBox(width: 8.w),
          ElevatedButton(
            onPressed:
                controller.isLoading.value ? null : controller.fetchRingData,
            child:
                Text(controller.isLoading.value ? 'Syncing...' : 'Sync Ring'),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordsList() {
    return Obx(() {
      if (controller.isLoading.value &&
          controller.localRecords.isEmpty &&
          controller.ringRecords.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }

      final localRecords = controller.localRecords;
      final ringRecords = controller.ringRecords;

      if (localRecords.isEmpty && ringRecords.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.health_and_safety, size: 64, color: Colors.grey),
              SizedBox(height: 16.h),
              Text('No records for this date',
                  style: TextStyle(fontSize: 16.sp, color: Colors.grey)),
              SizedBox(height: 8.h),
              Text('Complete a measurement to see it here.\nTap "Sync Ring" to fetch ring-stored data.',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(fontSize: 13.sp, color: Colors.grey.shade500)),
            ],
          ),
        );
      }

      return ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        itemCount: localRecords.length + ringRecords.length,
        itemBuilder: (context, index) {
          // Local records first, then ring records
          if (index < localRecords.length) {
            return _buildLocalRecordCard(localRecords[index]);
          }
          return _buildRingRecordCard(
              ringRecords[index - localRecords.length]);
        },
      );
    });
  }

  Widget _buildLocalRecordCard(MeasurementRecord record) {
    final time =
        DateTime.fromMillisecondsSinceEpoch(record.savedAt);
    return Card(
      margin: EdgeInsets.only(bottom: 8.h),
      color: Colors.deepOrange.withAlpha(12),
      child: Padding(
        padding: EdgeInsets.all(12.w),
        child: Row(
          children: [
            Container(
              width: 40.w,
              height: 40.w,
              decoration: BoxDecoration(
                color: Colors.deepOrange.withAlpha(25),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Center(
                child: Text(_typeIcon(record.result.type),
                    style: TextStyle(fontSize: 20.sp)),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(record.typeLabel,
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14.sp)),
                      SizedBox(width: 8.w),
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        child: Text('Local',
                            style: TextStyle(
                                fontSize: 9.sp, color: Colors.green.shade700)),
                      ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Text(DateFormat('HH:mm:ss').format(time),
                      style: TextStyle(
                          fontSize: 11.sp, color: Colors.grey.shade600)),
                ],
              ),
            ),
            Text(record.displayValue,
                style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepOrange)),
          ],
        ),
      ),
    );
  }

  Widget _buildRingRecordCard(AizoHealthData record) {
    final time = DateTime.fromMillisecondsSinceEpoch(record.timestamp * 1000);
    return Card(
      margin: EdgeInsets.only(bottom: 8.h),
      child: Padding(
        padding: EdgeInsets.all(12.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(DateFormat('HH:mm:ss').format(time),
                    style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500)),
                SizedBox(width: 8.w),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Text('Ring',
                      style: TextStyle(
                          fontSize: 9.sp, color: Colors.blue.shade700)),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Row(
              children: [
                _miniMetric('HR', '${record.heartRate ?? '--'}', 'bpm'),
                _miniMetric('SpO2', '${record.bloodOxygen ?? '--'}', '%'),
                _miniMetric('Steps', '${record.steps ?? '--'}', ''),
                _miniMetric(
                    'Temp', record.bodyTemp?.toStringAsFixed(1) ?? '--', '°C'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniMetric(String label, String value, String unit) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepOrange)),
          Text(label,
              style: TextStyle(fontSize: 10.sp, color: Colors.grey.shade600)),
          if (unit.isNotEmpty)
            Text(unit,
                style: TextStyle(fontSize: 9.sp, color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  String _typeIcon(int type) {
    switch (type) {
      case AizoInstantMeasurementType.heartRate:
        return '❤️';
      case AizoInstantMeasurementType.bloodOxygen:
        return '🩸';
      case AizoInstantMeasurementType.temperature:
        return '🌡️';
      default:
        return '📊';
    }
  }
}
