import 'package:alloop/features/aizoring/domain/models/smart_ring_device.dart';
import 'package:alloop/foundations/ui/vvewell_theme.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/radar_device_controller.dart';

/// vvewell-styled engineering dashboard for the JDY-23 radar bridge.
class RadarDevicePage extends GetView<RadarDeviceController> {
  const RadarDevicePage({super.key, required this.device});

  final SmartRingDevice device;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(device.name.isEmpty ? "JDY-23 radar" : device.name),
      actions: [
        Obx(
          () => IconButton(
            tooltip: controller.isConnected ? "Disconnect" : "Reconnect",
            icon: Icon(
              controller.isConnected
                  ? Icons.bluetooth_disabled
                  : Icons.bluetooth,
            ),
            onPressed: controller.isBusy.value
                ? null
                : (controller.isConnected
                      ? controller.disconnect
                      : controller.connect),
          ),
        ),
      ],
    ),
    body: Obx(
      () => ListView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 32),
        children: [
          _connectionCard(),
          const SizedBox(height: 14),
          if (controller.isConnected) ...[
            _runControls(),
            const SizedBox(height: 14),
            _pointCloudCard(),
            const SizedBox(height: 14),
            _vitalCard(),
            const SizedBox(height: 14),
            _configCard(),
            const SizedBox(height: 14),
            _advancedCard(context),
          ] else
            _connectHint(),
        ],
      ),
    ),
  );

  Widget _connectionCard() {
    final connected = controller.isConnected;
    return VvewellCard(
      color: VvewellColors.softOrange,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.radar,
                  size: 29,
                  color: VvewellColors.primaryDark,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name.isEmpty ? "JDY-23 mmWave radar" : device.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      connected ? "Radar connected. Ready to capture" : "Nearby and available to connect",
                      style: const TextStyle(color: VvewellColors.muted),
                    ),
                  ],
                ),
              ),
              VvewellStatusPill(
                label: _stateText(controller.connectionState.value),
                color: connected ? VvewellColors.success : VvewellColors.muted,
                icon: connected
                    ? Icons.bluetooth_connected
                    : Icons.bluetooth_disabled,
              ),
            ],
          ),
          const SizedBox(height: 15),
          _row("Device type", 'JDY-23 / MRS6130'),
          _row("Device address", device.id),
          _row("Bluetooth signal", '${device.rssi} dBm'),
          if (controller.isConnecting || controller.isBusy.value) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
          if (controller.latestResponse.value.isNotEmpty)
            _responseBlock(controller.latestResponse.value),
          if (!connected) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: controller.isBusy.value ? null : controller.connect,
                icon: const Icon(Icons.bluetooth_connected),
                label: const Text("Connect JDY-23 radar"),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _runControls() => VvewellCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const VvewellSectionTitle("Capture controls"),
        const SizedBox(height: 5),
        Text(
          controller.isRunning.value ? "Receiving point cloud and experimental vital signs data." : "Start radar capture after connecting.",
          style: const TextStyle(color: VvewellColors.muted, fontSize: 13),
        ),
        const SizedBox(height: 13),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: controller.isBusy.value ? null : controller.wakeup,
              icon: const Icon(Icons.wb_twilight_outlined),
              label: const Text("Wake"),
            ),
            ElevatedButton.icon(
              onPressed: controller.isBusy.value || controller.isRunning.value
                  ? null
                  : controller.start,
              icon: const Icon(Icons.play_arrow),
              label: const Text("Start radar"),
            ),
            OutlinedButton.icon(
              onPressed: controller.isBusy.value || !controller.isRunning.value
                  ? null
                  : controller.stop,
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text("Stop radar"),
            ),
            OutlinedButton.icon(
              onPressed: controller.isBusy.value ||
                      controller.isRunning.value ||
                      controller.isExportingPointCloud.value ||
                      !controller.hasPointCloudExport
                  ? null
                  : controller.exportPointCloudCsv,
              icon: const Icon(Icons.file_download_outlined),
              label: Text(
                controller.isExportingPointCloud.value
                    ? "Exporting…"
                    : "Export point cloud CSV",
              ),
            ),
            OutlinedButton.icon(
              onPressed: controller.isBusy.value ||
                      controller.isRunning.value ||
                      controller.isExportingPointCloud.value ||
                      !controller.hasPointCloudExport
                  ? null
                  : controller.sharePointCloudCsv,
              icon: const Icon(Icons.ios_share_outlined),
              label: const Text("Share point cloud CSV"),
            ),
            OutlinedButton.icon(
              onPressed: controller.isBusy.value ||
                      controller.isRunning.value ||
                      controller.isExportingVitalMetrics.value ||
                      !controller.hasVitalMetricsExport
                  ? null
                  : controller.exportVitalMetricsCsv,
              icon: const Icon(Icons.monitor_heart_outlined),
              label: Text(
                controller.isExportingVitalMetrics.value
                    ? "Exporting…"
                    : "Export vital signs CSV",
              ),
            ),
            OutlinedButton.icon(
              onPressed: controller.isBusy.value ||
                      controller.isRunning.value ||
                      controller.isExportingVitalMetrics.value ||
                      !controller.hasVitalMetricsExport
                  ? null
                  : controller.shareVitalMetricsCsv,
              icon: const Icon(Icons.ios_share_outlined),
              label: const Text("Share vital signs CSV"),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _pointCloudCard() => VvewellCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.scatter_plot, color: VvewellColors.primaryDark),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                "Live point cloud",
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
              ),
            ),
            Text(
              'Frame ${controller.pointFrameIndex.value}',
              style: const TextStyle(color: VvewellColors.muted, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          'Total: ${controller.pointCount.value} targets · Showing ${controller.points.length}',
          style: const TextStyle(color: VvewellColors.muted, fontSize: 12),
        ),
        if (controller.pointCloudCaptureState.value != 'idle') ...[
          const SizedBox(height: 4),
          Text(
            'Current capture: ${controller.capturedPointCloudFrames.value} frames, '
            '${controller.capturedPointCloudPoints.value} points'
            '（${controller.pointCloudCaptureState.value}）',
            style: const TextStyle(color: VvewellColors.muted, fontSize: 12),
          ),
        ],
        if (controller.hasPointCloudExport) ...[
          const SizedBox(height: 4),
          SelectableText(
            controller.pointCloudCsvPath.value,
            style: const TextStyle(color: VvewellColors.muted, fontSize: 11),
          ),
        ],
        const SizedBox(height: 12),
        AspectRatio(
          aspectRatio: 1.35,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: CustomPaint(
              painter: _PointCloudPainter(controller.points),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _vitalCard() {
    final metrics = controller.vitalMetrics;
    final sample = controller.vitalSample;
    return VvewellCard(
      color: VvewellColors.softBlue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const VvewellSectionTitle("Vital signs (experimental)"),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _metric("Respiratory rate", _bpm(metrics['breathingBpm']), Icons.air),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _metric(
                  "Heart rate",
                  _bpm(metrics['heartBpm']),
                  Icons.favorite_border,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _metric(
                  "Distance",
                  _meters(metrics['distanceMeters']),
                  Icons.straighten,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Breathing confidence ${_percent(metrics['breathingConfidence'])} · Heart rate confidence ${_percent(metrics['heartConfidence'])}',
            style: const TextStyle(color: VvewellColors.muted, fontSize: 12),
          ),
          if (controller.vitalMetricsCaptureState.value != 'idle') ...[
            const SizedBox(height: 4),
            Text(
              'Current measurements: ${controller.capturedVitalMetricRows.value} records'
              '（${controller.vitalMetricsCaptureState.value}）',
              style: const TextStyle(color: VvewellColors.muted, fontSize: 12),
            ),
          ],
          if (controller.hasVitalMetricsExport) ...[
            const SizedBox(height: 4),
            SelectableText(
              controller.vitalMetricsCsvPath.value,
              style: const TextStyle(color: VvewellColors.muted, fontSize: 11),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            'I/Q bin: ${sample['rangeBin'] ?? '-'} · Resolution: ${sample['rangeResolutionMm'] ?? '-'} mm · Frame: ${sample['frameIndex'] ?? '-'}',
            style: const TextStyle(color: VvewellColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 11),
          const Text(
            "For interaction, research and engineering validation only. Not for diagnosis or patient monitoring.",
            style: TextStyle(
              color: VvewellColors.error,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value, IconData icon) => Container(
    padding: const EdgeInsets.all(9),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .75),
      borderRadius: BorderRadius.circular(13),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: VvewellColors.primaryDark),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(color: VvewellColors.muted, fontSize: 11),
        ),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        ),
      ],
    ),
  );

  Widget _configCard() => VvewellCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const VvewellSectionTitle("VitalBridge output settings"),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text("I/Q vital signs data"),
          value: controller.phaseEnabled.value,
          onChanged: controller.isBusy.value
              ? null
              : (value) => controller.phaseEnabled.value = value,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text("Point cloud data"),
          value: controller.pointCloudEnabled.value,
          onChanged: controller.isBusy.value
              ? null
              : (value) => controller.pointCloudEnabled.value = value,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text("Select distance bin manually"),
          value: controller.manualBin.value,
          onChanged: controller.isBusy.value
              ? null
              : (value) => controller.manualBin.value = value,
        ),
        if (controller.manualBin.value)
          Row(
            children: [
              const Text('bin'),
              Expanded(
                child: Slider(
                  value: controller.selectedBin.value.toDouble(),
                  min: 0,
                  max: 200,
                  divisions: 200,
                  label: '${controller.selectedBin.value}',
                  onChanged: controller.isBusy.value
                      ? null
                      : (value) => controller.selectedBin.value = value.round(),
                ),
              ),
              Text('${controller.selectedBin.value}'),
            ],
          ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ElevatedButton(
              onPressed: controller.isBusy.value
                  ? null
                  : controller.applyVitalConfig,
              child: const Text("Apply settings"),
            ),
            OutlinedButton(
              onPressed: controller.isBusy.value
                  ? null
                  : controller.selectAutomaticBin,
              child: const Text("Select bin automatically"),
            ),
            OutlinedButton(
              onPressed: controller.isBusy.value
                  ? null
                  : controller.lockNearestPointBin,
              child: const Text("Lock to nearest point"),
            ),
            TextButton(
              onPressed: controller.isBusy.value
                  ? null
                  : controller.queryVitalConfig,
              child: const Text("Read settings"),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _advancedCard(BuildContext context) => VvewellCard(
    color: VvewellColors.softViolet,
    onTap: () => _showHifDialog(context),
    child: const Row(
      children: [
        Icon(Icons.terminal, color: VvewellColors.primaryDark),
        SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Advanced HIF commands", style: TextStyle(fontWeight: FontWeight.w800)),
              SizedBox(height: 3),
              Text(
                "Send HIF messages supported by future firmware.",
                style: TextStyle(color: VvewellColors.muted, fontSize: 13),
              ),
            ],
          ),
        ),
        Icon(Icons.chevron_right, color: VvewellColors.muted),
      ],
    ),
  );

  Widget _connectHint() => const VvewellCard(
    color: VvewellColors.softBlue,
    child: Row(
      children: [
        Icon(Icons.info_outline, color: VvewellColors.primaryDark),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            "Connect to subscribe to UART notifications and view live point cloud and experimental vital signs data.",
            style: TextStyle(color: VvewellColors.muted, height: 1.4),
          ),
        ),
      ],
    ),
  );

  Widget _responseBlock(String value) => Padding(
    padding: const EdgeInsets.only(top: 11),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SelectableText(
        value,
        style: const TextStyle(fontSize: 12, color: VvewellColors.muted),
      ),
    ),
  );

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(
      children: [
        SizedBox(
          width: 68,
          child: Text(
            label,
            style: const TextStyle(color: VvewellColors.muted, fontSize: 12),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value.isEmpty ? '--' : value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );

  String _stateText(String state) =>
      {
        'ready': "Connected",
        'connecting': "Connecting",
        'discovering': "Discovering services",
        'enabling_notifications': "Subscribing to notifications",
        'error': "Connection error",
        'disconnected': "Disconnected",
      }[state] ??
      state;

  String _bpm(dynamic value) =>
      value is num ? '${value.toStringAsFixed(1)} BPM' : '--';
  String _meters(dynamic value) =>
      value is num ? '${value.toStringAsFixed(2)} m' : '--';
  String _percent(dynamic value) =>
      value is num ? '${(value * 100).toStringAsFixed(0)}%' : '--';

  Future<void> _showHifDialog(BuildContext context) async {
    final id = TextEditingController(text: '90');
    final payload = TextEditingController();
    await Get.dialog(
      AlertDialog(
        title: const Text("HIF command"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: id,
              decoration: const InputDecoration(labelText: "Message ID (hex)"),
            ),
            TextField(
              controller: payload,
              decoration: const InputDecoration(labelText: "Payload hex (optional)"),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: Get.back, child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              final value = int.tryParse(id.text.trim(), radix: 16);
              if (value != null) {
                Get.back();
                controller.sendHif(value, payload.text);
              }
            },
            child: const Text("Send"),
          ),
        ],
      ),
    );
    id.dispose();
    payload.dispose();
  }
}

class _PointCloudPainter extends CustomPainter {
  const _PointCloudPainter(this.points);
  final List<Map<String, dynamic>> points;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF17312E),
    );
    final grid = Paint()
      ..color = const Color(0x2248D4C3)
      ..strokeWidth = 1;
    for (var i = 1; i < 6; i++) {
      canvas.drawLine(
        Offset(size.width * i / 6, 0),
        Offset(size.width * i / 6, size.height),
        grid,
      );
      canvas.drawLine(
        Offset(0, size.height * i / 6),
        Offset(size.width, size.height * i / 6),
        grid,
      );
    }
    final axis = Paint()
      ..color = const Color(0xFF7BE0D5)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      axis,
    );
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      axis,
    );
    for (final point in points) {
      final x = (point['x'] as num?)?.toDouble() ?? 0;
      final y = (point['y'] as num?)?.toDouble() ?? 0;
      final snr = (point['snr'] as num?)?.toDouble() ?? 0;
      final px = size.width / 2 + x * size.width / 12;
      final py = size.height / 2 - y * size.height / 12;
      if (px < 0 || px > size.width || py < 0 || py > size.height) continue;
      canvas.drawCircle(
        Offset(px, py),
        (2 + (snr.clamp(0, 30) / 15)).toDouble(),
        Paint()
          ..color = snr >= 15
              ? const Color(0xFF96F0C0)
              : const Color(0xFF83DED8),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PointCloudPainter oldDelegate) =>
      oldDelegate.points != points;
}
