import 'package:alloop/features/common/presentation/widgets/common_title_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../controllers/aizoring_sleep_controller.dart';

/// AIZORING sleep data page.
class AizoringSleepPage extends GetView<AizoringSleepController> {
  final String deviceId;

  const AizoringSleepPage({super.key, required this.deviceId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: CommonTitleText(title: 'Sleep Data'),
      ),
      body: Column(
        children: [
          _buildDateSelector(),
          Expanded(child: _buildSleepList()),
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
              controller.selectedDate.value = controller.selectedDate.value
                  .subtract(const Duration(days: 1));
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
                if (date != null) {
                  controller.selectedDate.value = date;
                }
              },
              child: Obx(
                () => Text(
                  DateFormat('yyyy-MM-dd').format(controller.selectedDate.value),
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
                controller.selectedDate.value = next;
              }
            },
          ),
          SizedBox(width: 8.w),
          Obx(
            () => ElevatedButton(
              onPressed:
                  controller.isLoading.value ? null : controller.fetchSleepData,
              child: Text(controller.isLoading.value ? 'Loading...' : 'Fetch'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSleepList() {
    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }
      if (controller.records.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.bedtime, size: 64, color: Colors.grey),
              SizedBox(height: 16.h),
              Text('No sleep data for this date',
                  style: TextStyle(fontSize: 16.sp, color: Colors.grey)),
              SizedBox(height: 8.h),
              Text('Select a date and tap Fetch',
                  style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade500)),
            ],
          ),
        );
      }

      return ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        itemCount: controller.records.length,
        itemBuilder: (context, index) {
          final record = controller.records[index];
          final startTime = DateTime.fromMillisecondsSinceEpoch(
              record.startTime * 1000);
          final endTime = DateTime.fromMillisecondsSinceEpoch(
              record.endTime * 1000);

          return Card(
            margin: EdgeInsets.only(bottom: 12.h),
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bedtime, color: Colors.indigo),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${DateFormat('HH:mm').format(startTime)} — ${DateFormat('HH:mm').format(endTime)}',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14.sp),
                            ),
                            Text(
                              'Total: ${_formatMinutes(record.totalDuration)}',
                              style: TextStyle(
                                  fontSize: 12.sp, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  // Sleep stage bars
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4.r),
                    child: SizedBox(
                      height: 20.h,
                      child: Row(
                        children: [
                          _stageBar(
                              record.deepDuration, record.totalDuration,
                              Colors.indigo, 'Deep'),
                          _stageBar(
                              record.lightDuration, record.totalDuration,
                              Colors.blue.shade300, 'Light'),
                          _stageBar(
                              record.remDuration, record.totalDuration,
                              Colors.purple.shade300, 'REM'),
                          _stageBar(
                              record.awakeDuration, record.totalDuration,
                              Colors.orange.shade300, 'Awake'),
                        ].where((w) => w != null).cast<Widget>().toList(),
                      ),
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Row(
                    children: [
                      _legendChip(Colors.indigo, 'Deep'),
                      _legendChip(Colors.blue.shade300, 'Light'),
                      _legendChip(Colors.purple.shade300, 'REM'),
                      _legendChip(Colors.orange.shade300, 'Awake'),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    });
  }

  Widget? _stageBar(int duration, int total, Color color, String label) {
    if (duration <= 0 || total <= 0) return null;
    return Expanded(
      flex: duration,
      child: Container(
        color: color,
        child: Center(
          child: Text(
            _formatMinutes(duration),
            style: TextStyle(
                color: Colors.white,
                fontSize: 9.sp,
                fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _legendChip(Color color, String label) {
    return Padding(
      padding: EdgeInsets.only(right: 12.w),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10.w,
            height: 10.w,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          SizedBox(width: 4.w),
          Text(label, style: TextStyle(fontSize: 10.sp, color: Colors.grey)),
        ],
      ),
    );
  }

  String _formatMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0) return '${h}h${m}m';
    return '${m}m';
  }
}
