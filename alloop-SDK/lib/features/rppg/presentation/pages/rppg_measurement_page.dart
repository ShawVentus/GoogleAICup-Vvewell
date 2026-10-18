import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/database/local_health_database.dart';
import '../../../../foundations/ui/vvewell_theme.dart';
import '../../data/rppg_platform_client.dart';
import '../../domain/models/rppg_session_result.dart';

class RppgMeasurementPage extends StatefulWidget {
  const RppgMeasurementPage({super.key, RppgPlatformClient? client})
    : client = client ?? const _DefaultRppgPlatformClient();

  final RppgPlatformClient client;

  @override
  State<RppgMeasurementPage> createState() => _RppgMeasurementPageState();
}

class _DefaultRppgPlatformClient extends RppgPlatformClient {
  const _DefaultRppgPlatformClient();
}

class _RppgMeasurementPageState extends State<RppgMeasurementPage> {
  RppgSessionResult? _result;
  String _status = '准备开始手机 rPPG 测量';
  String? _error;
  bool _running = false;

  Future<void> _start() async {
    if (_running) return;

    setState(() {
      _running = true;
      _error = null;
      _status = '正在打开摄像头测量页';
    });
    try {
      final available = await widget.client.isAvailable();
      if (!available) {
        throw StateError('当前设备缺少前置摄像头或 rPPG 模型资源'.tr);
      }
      final result = await widget.client.startMeasurement();
      if (result.completed) await _saveResult(result);
      if (!mounted) return;
      setState(() {
        _result = result;
        _status = _statusFor(result);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _status = '测量失败';
      });
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Future<void> _cancel() async {
    await widget.client.cancelMeasurement();
    if (!mounted) return;
    setState(() => _status = '已请求取消测量');
  }

  Future<void> _saveResult(RppgSessionResult result) async {
    final db = LocalHealthDatabase.instance;
    await db.upsertDevice(
      deviceId: result.deviceId,
      name: 'Phone rPPG',
      type: RppgSessionResult.expectedSource,
      connected: false,
      lastSyncAt: result.completedAt,
    );
    await db.saveVitalReading(
      source: RppgSessionResult.expectedSource,
      deviceId: result.deviceId,
      recordedAt: result.completedAt,
      heartRate: result.summary.heartRate,
      respiratoryRate: result.summary.respiratoryRate,
      signalQuality: result.summary.aggregateQuality,
      confidence: _summaryConfidence(result.summary),
      rawData: {'rppgSession': result.toJson(), 'isMock': false},
      provenance: VitalReadingProvenance(
        sessionId: result.sessionId,
        source: RppgSessionResult.expectedSource,
        deviceId: result.deviceId,
        recordedAt: result.completedAt,
        schemaVersion: result.schemaVersion,
        origin: HealthDataOrigin.realDevice,
        hrConfidence: result.summary.heartRateConfidence,
        rrConfidence: result.summary.respiratoryRateConfidence,
        aggregateQuality: result.summary.aggregateQuality,
      ),
    );
    await LocalHealthDatabase.notifyMeasurementBlockCompleted();
  }

  double _summaryConfidence(RppgEstimateSummary summary) {
    final values = <double>[
      if (summary.heartRate != null) summary.heartRateConfidence,
      if (summary.respiratoryRate != null) summary.respiratoryRateConfidence,
    ];
    if (values.isEmpty) return summary.aggregateQuality;
    return values.reduce((a, b) => a < b ? a : b);
  }

  String _statusFor(RppgSessionResult result) {
    switch (result.completionReason) {
      case 'completed':
        return '测量完成，结果已保存';
      case 'cancelled':
        return '测量已取消';
      case 'low_quality':
        return '信号质量不足';
      case 'error':
        return '测量失败';
      default:
        return '测量结束：@reason'.trParams({'reason': result.completionReason});
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Scaffold(
      appBar: AppBar(title: Text('手机 rPPG 测量'.tr)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
        children: [
          VvewellCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                VvewellStatusPill(
                  label: _status.tr,
                  icon: _running ? Icons.hourglass_top : Icons.monitor_heart,
                  color: _error == null
                      ? VvewellColors.primary
                      : VvewellColors.error,
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _running ? null : _start,
                        icon: const Icon(Icons.play_arrow),
                        label: Text('开始测量'.tr),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton.filledTonal(
                      onPressed: _running ? _cancel : null,
                      icon: const Icon(Icons.close),
                      tooltip: '取消测量'.tr,
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _error!,
                    style: const TextStyle(color: VvewellColors.error),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (result != null) _ResultCard(result: result),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final RppgSessionResult result;

  @override
  Widget build(BuildContext context) {
    return VvewellCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '最终结果'.tr,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          _MetricRow(
            label: '心率'.tr,
            value: result.summary.heartRate?.toStringAsFixed(0) ?? '--',
            unit: 'BPM',
            confidence: result.summary.heartRateConfidence,
          ),
          _MetricRow(
            label: '呼吸率'.tr,
            value: result.summary.respiratoryRate?.toStringAsFixed(1) ?? '--',
            unit: '次/分'.tr,
            confidence: result.summary.respiratoryRateConfidence,
          ),
          _MetricRow(
            label: 'Aggregate quality',
            value: (result.summary.aggregateQuality * 100).toStringAsFixed(0),
            unit: '%',
            confidence: result.summary.aggregateQuality,
          ),
          const SizedBox(height: 8),
          Text(
            '样本数：@count  来源：@source'.trParams({
              'count': '${result.estimateSamples.length}',
              'source': result.source,
            }),
            style: const TextStyle(color: VvewellColors.muted),
          ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.label,
    required this.value,
    required this.unit,
    required this.confidence,
  });

  final String label;
  final String value;
  final String unit;
  final double confidence;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$value $unit'),
              Text(
                'conf ${(confidence * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: VvewellColors.muted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
