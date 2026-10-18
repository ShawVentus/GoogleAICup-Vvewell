import 'dart:math' as math;

import 'package:alloop/features/common/presentation/widgets/common_title_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../controllers/aizoring_ecg_controller.dart';

/// AIZORING ECG measurement page with real-time waveform display.
class AizoringEcgPage extends GetView<AizoringEcgController> {
  final String deviceId;

  const AizoringEcgPage({super.key, required this.deviceId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: CommonTitleText(title: 'ECG Measurement'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildWearTypeSelector(),
            SizedBox(height: 16.h),
            _buildControlButtons(),
            SizedBox(height: 16.h),
            _buildEcgChart(),
            SizedBox(height: 16.h),
            _buildEcgResult(),
          ],
        ),
      ),
    );
  }

  Widget _buildWearTypeSelector() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(12.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Wear Position',
                style:
                    TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
            SizedBox(height: 8.h),
            Obx(
              () => Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('🫲 Left Hand'),
                      selected: controller.wearType.value == 0x01,
                      selectedColor: Colors.deepOrange.withValues(alpha: 0.3),
                      onSelected: controller.isMeasuring.value
                          ? null
                          : (_) => controller.setWearType(0x01),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('🫱 Right Hand'),
                      selected: controller.wearType.value == 0x02,
                      selectedColor: Colors.deepOrange.withValues(alpha: 0.3),
                      onSelected: controller.isMeasuring.value
                          ? null
                          : (_) => controller.setWearType(0x02),
                    ),
                  ),
                ],
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
              onPressed:
                  controller.isMeasuring.value ? null : controller.startEcg,
              icon: const Icon(Icons.favorite),
              label: const Text('Start ECG'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.all(14.h),
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: OutlinedButton.icon(
              onPressed:
                  controller.isMeasuring.value ? controller.stopEcg : null,
              icon: const Icon(Icons.stop),
              label: const Text('Stop'),
              style: OutlinedButton.styleFrom(padding: EdgeInsets.all(14.h)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEcgChart() {
    return Obx(() {
      final samples = controller.ecgSamples;

      return Card(
        child: Padding(
          padding: EdgeInsets.all(12.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('ECG Waveform',
                      style: TextStyle(
                          fontSize: 14.sp, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  if (controller.isMeasuring.value)
                    Row(
                      children: [
                        Container(
                          width: 8.w,
                          height: 8.w,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 4.w),
                        Text('Recording',
                            style: TextStyle(
                                fontSize: 11.sp, color: Colors.red)),
                      ],
                    ),
                  Text(' ${samples.length} pts',
                      style:
                          TextStyle(fontSize: 11.sp, color: Colors.grey)),
                ],
              ),
              SizedBox(height: 8.h),
              Container(
                height: 200.h,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: samples.isEmpty
                    ? const Center(
                        child: Text('No ECG data yet',
                            style: TextStyle(color: Colors.grey)))
                    : CustomPaint(
                        size: Size(double.infinity, 200.h),
                        painter: _EcgWavePainter(
                          samples: samples,
                          lineColor: Colors.red,
                          gridColor: Colors.grey.shade300,
                        ),
                      ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildEcgResult() {
    return Obx(() {
      final result = controller.ecgResult.value;
      if (result == null) return const SizedBox.shrink();

      return Card(
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ECG Result',
                  style:
                      TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
              SizedBox(height: 12.h),
              _resultRow('Avg HR', '${result.avgHr}', 'bpm'),
              _resultRow('Duration', '${result.duration}', 'sec'),
              _resultRow('Frequency', '${result.frequency}', 'Hz'),
              _resultRow('Analysis', result.resultLabel, ''),
              Divider(color: Colors.grey.shade300),
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: result.ecgResult == 0
                      ? Colors.green.shade50
                      : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Row(
                  children: [
                    Icon(
                      result.ecgResult == 0
                          ? Icons.check_circle
                          : Icons.warning,
                      color: result.ecgResult == 0
                          ? Colors.green
                          : Colors.red,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        result.resultLabel,
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: result.ecgResult == 0
                              ? Colors.green.shade800
                              : Colors.red.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _resultRow(String label, String value, String unit) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(fontSize: 14.sp, color: Colors.grey[700])),
          ),
          Text(value,
              style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepOrange)),
          if (unit.isNotEmpty) ...[
            SizedBox(width: 4.w),
            Text(unit,
                style: TextStyle(fontSize: 12.sp, color: Colors.grey)),
          ],
        ],
      ),
    );
  }
}

/// A simple Canvas-based ECG waveform painter.
class _EcgWavePainter extends CustomPainter {
  final List<double> samples;
  final Color lineColor;
  final Color gridColor;

  _EcgWavePainter({
    required this.samples,
    required this.lineColor,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty) return;

    // Draw grid lines
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5;
    for (var i = 0; i < size.width; i += 50) {
      canvas.drawLine(
          Offset(i.toDouble(), 0), Offset(i.toDouble(), size.height), gridPaint);
    }
    for (var i = 0; i < size.height; i += 50) {
      canvas.drawLine(
          Offset(0, i.toDouble()), Offset(size.width, i.toDouble()), gridPaint);
    }

    // Calculate the data range
    final maxVal = samples.reduce(math.max);
    final minVal = samples.reduce(math.min);
    final range = (maxVal - minVal).clamp(0.001, double.infinity);

    // Compute how many samples fit in the view
    final visibleCount = samples.length.clamp(0, size.width.toInt());
    final start = (samples.length - visibleCount).clamp(0, samples.length);

    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path();
    for (var i = start; i < samples.length; i++) {
      final x = ((i - start) / visibleCount) * size.width;
      final y = size.height -
          ((samples[i] - minVal) / range) * (size.height * 0.8) -
          size.height * 0.1;
      if (i == start) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _EcgWavePainter oldDelegate) {
    return samples != oldDelegate.samples;
  }
}
