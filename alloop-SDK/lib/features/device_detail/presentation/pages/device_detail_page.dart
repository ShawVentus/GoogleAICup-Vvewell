import 'package:alloop/features/aizoring/domain/models/smart_ring_device.dart';
import 'package:alloop/foundations/ui/vvewell_theme.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../widgets/chart/realtime_line_chart.dart';
import '../../domain/alloop_ring_dashboard_models.dart';
import '../controllers/device_detail_controller.dart';

class DeviceDetailPage extends GetView<DeviceDetailController> {
  const DeviceDetailPage({super.key, required this.device});

  final SmartRingDevice device;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Obx(
          () => Text(
            controller.deviceName.value.isEmpty
                ? _fallbackDeviceName
                : controller.deviceName.value,
          ),
        ),
      ),
      body: ListView(
        key: const Key('alloop-ring-dashboard-scroll'),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 36),
        children: [
          Obx(_deviceHero),
          const SizedBox(height: 12),
          Obx(_temperatureCard),
          const SizedBox(height: 12),
          Obx(
            () => controller.isConnected.value
                ? _connectedContent(context)
                : _disconnectedContent(context),
          ),
        ],
      ),
    );
  }

  String get _fallbackDeviceName =>
      device.name.isEmpty ? 'Alloop 智能戒指' : device.name;

  Widget _connectedContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Obx(_connectedOverview),
        const SizedBox(height: 12),
        Obx(_measurementPanel),
        const SizedBox(height: 20),
        const VvewellSectionTitle('本次检测结果'),
        const SizedBox(height: 10),
        Obx(_metricOverview),
        const SizedBox(height: 20),
        VvewellSectionTitle(
          '实时波形',
          action: Obx(
            () => IconButton(
              key: const Key('export-alloop-waveforms'),
              tooltip: '导出当前波形',
              onPressed: controller.isExporting.value
                  ? null
                  : controller.exportWaveData,
              icon: controller.isExporting.value
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_outlined),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Obx(_waveforms),
        const SizedBox(height: 20),
        const VvewellSectionTitle('健康趋势'),
        const SizedBox(height: 10),
        Obx(_trendRangeControl),
        const SizedBox(height: 10),
        Obx(_trendCharts),
        const SizedBox(height: 20),
        const VvewellSectionTitle('数据操作'),
        const SizedBox(height: 10),
        Obx(_dataActions),
        const SizedBox(height: 20),
        const VvewellSectionTitle('设备管理'),
        const SizedBox(height: 10),
        _deviceManagement(context),
      ],
    );
  }

  Widget _deviceHero() {
    final connected = controller.isConnected.value;
    return VvewellCard(
      color: connected ? VvewellColors.softTeal : VvewellColors.softBlue,
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
                  Icons.ring_volume_outlined,
                  size: 30,
                  color: VvewellColors.primaryDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _fallbackDeviceName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      connected ? '设备已连接，SDK 数据通道已就绪' : '设备当前未连接',
                      style: const TextStyle(
                        color: VvewellColors.muted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              VvewellStatusPill(
                label: connected ? '已连接' : '未连接',
                color: connected ? VvewellColors.success : VvewellColors.muted,
                icon: connected
                    ? Icons.bluetooth_connected
                    : Icons.bluetooth_disabled,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _infoRow('设备地址', device.id),
          if (device.rssi != 0) _infoRow('蓝牙信号', '${device.rssi} dBm'),
        ],
      ),
    );
  }

  Widget _connectedOverview() {
    final info = controller.deviceInfo.value;
    final battery = info?.batteryPercent;
    return VvewellCard(
      child: Row(
        children: [
          Expanded(
            child: _overviewMetric(
              Icons.battery_std_rounded,
              '电量',
              battery == null ? '--' : '$battery%',
              _batteryColor(battery),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _overviewMetric(
              Icons.memory_outlined,
              '固件',
              info?.firmwareVersion.isNotEmpty == true
                  ? info!.firmwareVersion
                  : '--',
              VvewellColors.primaryDark,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _overviewMetric(
              Icons.sensors_outlined,
              '数据通道',
              '7 路',
              VvewellColors.success,
            ),
          ),
        ],
      ),
    );
  }

  Widget _temperatureCard() {
    final temperature = controller.latestTemperatureC.value;
    final recordedAt = controller.latestTemperatureAt.value?.toLocal();
    final loading = controller.isLoadingTemperature.value;
    return VvewellCard(
      color: VvewellColors.softMint,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.thermostat_outlined,
              color: VvewellColors.success,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '最近体温',
                  style: TextStyle(color: VvewellColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  loading
                      ? '读取中…'
                      : temperature == null
                      ? '--'
                      : '${temperature.toStringAsFixed(1)} °C',
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  recordedAt == null
                      ? '同步历史活动数据后显示'
                      : '历史活动数据 · ${_formatDateTime(recordedAt)}',
                  style: const TextStyle(
                    color: VvewellColors.muted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '刷新体温',
            onPressed: loading ? null : controller.refreshLatestTemperature,
            icon: const Icon(Icons.refresh_rounded),
            color: VvewellColors.primaryDark,
          ),
        ],
      ),
    );
  }

  Widget _measurementPanel() {
    final phase = controller.measurementPhase.value;
    final measuring = phase == AlloopMeasurementPhase.measuring;
    final busy = phase.isBusy;
    return VvewellCard(
      key: const Key('alloop-one-tap-measurement-panel'),
      color: busy ? VvewellColors.softBlue : VvewellColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: VvewellColors.softTeal,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  measuring
                      ? Icons.monitor_heart
                      : Icons.health_and_safety_outlined,
                  color: VvewellColors.primaryDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _phaseTitle(phase),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      controller.measurementStatus.value,
                      style: const TextStyle(
                        color: VvewellColors.muted,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (busy || phase == AlloopMeasurementPhase.completed) ...[
            const SizedBox(height: 14),
            LinearProgressIndicator(
              minHeight: 7,
              borderRadius: BorderRadius.circular(4),
              value: controller.measurementProgress.value,
              backgroundColor: VvewellColors.border,
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              key: const Key('alloop-one-tap-measurement-button'),
              onPressed:
                  phase == AlloopMeasurementPhase.stopping ||
                      phase == AlloopMeasurementPhase.syncingHistory
                  ? null
                  : measuring
                  ? controller.finishOneTapMeasurement
                  : controller.startOneTapMeasurement,
              icon: Icon(
                measuring ? Icons.stop_circle_outlined : Icons.play_arrow,
              ),
              label: Text(measuring ? '结束检测并生成结果' : '开始一键测量'),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '实时读取血氧、心率、4 路 PPG 与 3 轴运动波形；结束后同步 SDK 历史体温。检测结果不替代医疗诊断。',
            style: TextStyle(
              color: VvewellColors.muted,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricOverview() {
    return Row(
      children: [
        Expanded(
          child: _metricCard(
            icon: Icons.water_drop_outlined,
            label: '血氧',
            value: controller.displaySpo2.value?.toString() ?? '--',
            unit: '%',
            source: '实时 SDK',
            color: const Color(0xFF2878C8),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _metricCard(
            icon: Icons.favorite_outline,
            label: '心率',
            value: controller.displayHeartRate.value?.toString() ?? '--',
            unit: 'bpm',
            source: '实时 SDK',
            color: VvewellColors.error,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _metricCard(
            icon: Icons.thermostat_outlined,
            label: '体温',
            value:
                controller.displayTemperature.value?.toStringAsFixed(1) ?? '--',
            unit: '°C',
            source: '历史同步',
            color: VvewellColors.warning,
          ),
        ),
      ],
    );
  }

  Widget _waveforms() {
    final hasPpg = controller.ppgLedG.isNotEmpty;
    final hasAcc = controller.accX.isNotEmpty;
    if (!hasPpg && !hasAcc) {
      return const VvewellCard(
        color: VvewellColors.softBlue,
        child: _EmptyData(
          icon: Icons.show_chart,
          title: '等待波形数据',
          subtitle: '开始测量后，所有 SDK 可生成的波形会在这里实时显示。',
        ),
      );
    }
    return Column(
      children: [
        if (hasPpg)
          VvewellCard(
            key: const Key('alloop-ppg-waveform-card'),
            child: RealTimeLineChart(
              title: 'PPG · 4 路光学信号',
              height: 190,
              windowSeconds: DeviceDetailController.chartWindowSeconds,
              series: [
                ChartDataSeries(
                  data: controller.ppgLedG.toList(),
                  color: VvewellColors.success,
                  name: '绿光',
                ),
                ChartDataSeries(
                  data: controller.ppgLedGAmb.toList(),
                  color: VvewellColors.warning,
                  name: '绿光环境',
                ),
                ChartDataSeries(
                  data: controller.ppgLedRedAmb.toList(),
                  color: VvewellColors.error,
                  name: '红光环境',
                ),
                ChartDataSeries(
                  data: controller.ppgLedIr.toList(),
                  color: const Color(0xFF2878C8),
                  name: '红外',
                ),
              ],
            ),
          ),
        if (hasPpg && hasAcc) const SizedBox(height: 10),
        if (hasAcc)
          VvewellCard(
            key: const Key('alloop-acc-waveform-card'),
            child: RealTimeLineChart(
              title: 'ACC · 3 轴运动信号',
              height: 170,
              windowSeconds: DeviceDetailController.chartWindowSeconds,
              series: [
                ChartDataSeries(
                  data: controller.accX.toList(),
                  color: const Color(0xFF7A55C5),
                  name: 'X',
                ),
                ChartDataSeries(
                  data: controller.accY.toList(),
                  color: VvewellColors.primary,
                  name: 'Y',
                ),
                ChartDataSeries(
                  data: controller.accZ.toList(),
                  color: VvewellColors.warning,
                  name: 'Z',
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _trendRangeControl() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: VvewellColors.border,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: AlloopTrendRange.values.map((range) {
          final selected = controller.trendRange.value == range;
          return Expanded(
            child: Material(
              color: selected ? VvewellColors.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              child: InkWell(
                key: Key('alloop-trend-${range.name}'),
                onTap: () => controller.setTrendRange(range),
                borderRadius: BorderRadius.circular(9),
                child: SizedBox(
                  height: 44,
                  child: Center(
                    child: Text(
                      range.label,
                      style: TextStyle(
                        color: selected
                            ? VvewellColors.primaryDark
                            : VvewellColors.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _trendCharts() {
    if (controller.isLoadingTrends.value) {
      return const VvewellCard(
        child: SizedBox(
          height: 150,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    final points = controller.trendPoints.toList();
    return Column(
      children: [
        _trendCard(
          '血氧趋势',
          '%',
          const Color(0xFF2878C8),
          points,
          (point) => point.spo2,
        ),
        const SizedBox(height: 10),
        _trendCard(
          '心率趋势',
          'bpm',
          VvewellColors.error,
          points,
          (point) => point.heartRate,
        ),
        const SizedBox(height: 10),
        _trendCard(
          '体温趋势',
          '°C',
          VvewellColors.warning,
          points,
          (point) => point.temperature,
          sourceLabel: '来自 SDK 活动历史温度序列',
        ),
      ],
    );
  }

  Widget _dataActions() {
    return VvewellCard(
      child: Column(
        children: [
          _actionRow(
            icon: Icons.sync,
            title: '立即同步戒指历史',
            subtitle: '更新测量、活动、运动和体温记录',
            onTap: controller.measurementPhase.value.isBusy
                ? null
                : controller.syncHistoryNow,
          ),
          const Divider(height: 24),
          _actionRow(
            icon: Icons.download_outlined,
            title: '导出当前波形',
            subtitle: '将本次 PPG 与 ACC 保存为 CSV',
            onTap: controller.isExporting.value
                ? null
                : controller.exportWaveData,
          ),
        ],
      ),
    );
  }

  Widget _deviceManagement(BuildContext context) {
    return VvewellCard(
      child: Column(
        children: [
          _actionRow(
            key: const Key('disconnect-alloop-ring'),
            icon: Icons.bluetooth_disabled,
            title: '断开蓝牙连接',
            subtitle: '保留设备绑定与本机健康数据',
            onTap: () => _confirm(
              context,
              title: '断开 Alloop Ring？',
              message: '当前蓝牙连接将结束，历史数据不会被删除。',
              confirmLabel: '断开',
              action: controller.disconnect,
            ),
          ),
          const Divider(height: 24),
          _actionRow(
            key: const Key('clear-alloop-ring-data'),
            icon: Icons.delete_sweep_outlined,
            title: '清除本机戒指数据',
            subtitle: '删除该戒指的本机测量、趋势与活动记录',
            color: VvewellColors.warning,
            onTap: () => _confirm(
              context,
              title: '清除本机数据？',
              message: '此操作会删除该戒指保存在本机的测量与活动记录，无法撤销；不会删除云端数据。',
              confirmLabel: '清除数据',
              destructive: true,
              action: controller.clearLocalData,
            ),
          ),
          const Divider(height: 24),
          _actionRow(
            key: const Key('unbind-alloop-ring'),
            icon: Icons.link_off,
            title: '解绑戒指',
            subtitle: '断开连接并移除应用内设备绑定，保留历史健康数据',
            color: VvewellColors.error,
            onTap: () => _confirm(
              context,
              title: '解绑 Alloop Ring？',
              message: '将断开蓝牙并移除应用内绑定。已保存的历史健康数据仍会保留。',
              confirmLabel: '确认解绑',
              destructive: true,
              action: controller.unbindRing,
            ),
          ),
        ],
      ),
    );
  }

  Widget _disconnectedContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        VvewellCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '重新连接设备',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text(
                '连接后将直接回到一键检测、波形和趋势页面，无需重新扫描或筛选。',
                style: TextStyle(color: VvewellColors.muted, height: 1.4),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  key: const Key('reconnect-alloop-ring'),
                  onPressed: controller.isConnecting.value
                      ? null
                      : controller.connect,
                  icon: controller.isConnecting.value
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.bluetooth_connected),
                  label: Text(
                    controller.isConnecting.value ? '正在连接…' : '连接 Alloop Ring',
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const VvewellSectionTitle('设备管理'),
        const SizedBox(height: 10),
        _deviceManagement(context),
      ],
    );
  }

  Widget _overviewMetric(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Container(
      constraints: const BoxConstraints(minHeight: 76),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          Text(
            label,
            maxLines: 1,
            style: const TextStyle(color: VvewellColors.muted, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _metricCard({
    required IconData icon,
    required String label,
    required String value,
    required String unit,
    required String source,
    required Color color,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 126),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: VvewellColors.surface,
        border: Border.all(color: VvewellColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 21),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                text: value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
                children: [
                  TextSpan(
                    text: ' $unit',
                    style: const TextStyle(
                      color: VvewellColors.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            source,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: VvewellColors.muted, fontSize: 9),
          ),
        ],
      ),
    );
  }

  Widget _trendCard(
    String title,
    String unit,
    Color color,
    List<AlloopTrendPoint> points,
    double? Function(AlloopTrendPoint point) valueOf, {
    String? sourceLabel,
  }) {
    final values = points
        .map((point) => _TimedValue(point.recordedAt, valueOf(point)))
        .where((point) => point.value != null)
        .map((point) => _TimedValue(point.time, point.value!))
        .toList(growable: false);
    return VvewellCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              if (values.isNotEmpty)
                Text(
                  '${values.last.value!.toStringAsFixed(unit == '°C' ? 1 : 0)} $unit',
                  style: TextStyle(color: color, fontWeight: FontWeight.w800),
                ),
            ],
          ),
          if (sourceLabel != null) ...[
            const SizedBox(height: 2),
            Text(
              sourceLabel,
              style: const TextStyle(color: VvewellColors.muted, fontSize: 10),
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            height: 126,
            width: double.infinity,
            child: values.isEmpty
                ? const _EmptyData(
                    icon: Icons.timeline,
                    title: '暂无趋势数据',
                    subtitle: '完成检测或同步历史后生成',
                    compact: true,
                  )
                : CustomPaint(
                    painter: _TrendPainter(values: values, color: color),
                  ),
          ),
          if (values.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('MM/dd').format(values.first.time.toLocal()),
                  style: const TextStyle(
                    color: VvewellColors.muted,
                    fontSize: 10,
                  ),
                ),
                Text(
                  DateFormat('MM/dd').format(values.last.time.toLocal()),
                  style: const TextStyle(
                    color: VvewellColors.muted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _actionRow({
    Key? key,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    Color color = VvewellColors.primaryDark,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Row(
          children: [
            Icon(icon, color: onTap == null ? VvewellColors.muted : color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: VvewellColors.muted,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              color: onTap == null ? VvewellColors.border : VvewellColors.muted,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    required Future<void> Function() action,
    bool destructive = false,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(backgroundColor: VvewellColors.error)
                : null,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    if (confirmed == true) await action();
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: const TextStyle(color: VvewellColors.muted, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  String _phaseTitle(AlloopMeasurementPhase phase) => switch (phase) {
    AlloopMeasurementPhase.idle => '一键健康检测',
    AlloopMeasurementPhase.measuring => '正在采集实时数据',
    AlloopMeasurementPhase.stopping => '正在结束检测',
    AlloopMeasurementPhase.syncingHistory => '正在同步历史数据',
    AlloopMeasurementPhase.completed => '检测已完成',
    AlloopMeasurementPhase.error => '检测未完成',
  };

  Color _batteryColor(int? battery) {
    if (battery == null) return VvewellColors.muted;
    if (battery >= 50) return VvewellColors.success;
    if (battery >= 20) return VvewellColors.warning;
    return VvewellColors.error;
  }

  String _formatDateTime(DateTime value) {
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${twoDigits(value.month)}-${twoDigits(value.day)} '
        '${twoDigits(value.hour)}:${twoDigits(value.minute)}';
  }
}

class _EmptyData extends StatelessWidget {
  const _EmptyData({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: compact ? 28 : 36, color: VvewellColors.muted),
        const SizedBox(height: 7),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(color: VvewellColors.muted, fontSize: 11),
        ),
      ],
    );
  }
}

class _TimedValue {
  const _TimedValue(this.time, this.value);

  final DateTime time;
  final double? value;
}

class _TrendPainter extends CustomPainter {
  const _TrendPainter({required this.values, required this.color});

  final List<_TimedValue> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const top = 8.0;
    const bottom = 12.0;
    final chart = Rect.fromLTWH(0, top, size.width, size.height - top - bottom);
    final grid = Paint()
      ..color = VvewellColors.border
      ..strokeWidth = 1;
    for (var index = 0; index < 4; index++) {
      final y = chart.top + chart.height * index / 3;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), grid);
    }

    final minTime = values.first.time.millisecondsSinceEpoch.toDouble();
    final maxTime = values.last.time.millisecondsSinceEpoch.toDouble();
    final rawValues = values.map((item) => item.value!).toList();
    var minValue = rawValues.reduce((a, b) => a < b ? a : b);
    var maxValue = rawValues.reduce((a, b) => a > b ? a : b);
    if ((maxValue - minValue).abs() < .01) {
      minValue -= .5;
      maxValue += .5;
    }
    final path = Path();
    for (var index = 0; index < values.length; index++) {
      final point = values[index];
      final timeSpan = maxTime - minTime;
      final x = timeSpan == 0
          ? chart.center.dx
          : chart.left +
                (point.time.millisecondsSinceEpoch - minTime) /
                    timeSpan *
                    chart.width;
      final y =
          chart.bottom -
          (point.value! - minValue) / (maxValue - minValue) * chart.height;
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    if (values.length == 1) {
      canvas.drawCircle(
        Offset(chart.center.dx, chart.center.dy),
        4,
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.color != color;
}
