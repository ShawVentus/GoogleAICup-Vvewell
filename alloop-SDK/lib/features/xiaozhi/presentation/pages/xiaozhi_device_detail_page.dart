import 'package:alloop/features/aizoring/domain/models/smart_ring_device.dart';
import 'package:alloop/foundations/ui/vvewell_theme.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../domain/proactive_voice_config.dart';
import '../controllers/xiaozhi_device_controller.dart';

/// vvewell-styled control surface for XiaoZhi BLE hardware.
class XiaoZhiDeviceDetailPage extends GetView<XiaoZhiDeviceController> {
  const XiaoZhiDeviceDetailPage({super.key, required this.device});

  final SmartRingDevice device;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(device.name.isEmpty ? '健康小助手' : device.name),
      actions: [
        Obx(
          () => IconButton(
            tooltip: controller.isConnected ? '断开连接' : '重新连接',
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
            _statusCard(),
            const SizedBox(height: 14),
            _wifiCard(context),
            const SizedBox(height: 14),
            _quickControls(),
            const SizedBox(height: 14),
            _proactiveVoiceCard(context),
            const SizedBox(height: 14),
            _customCommandCard(context),
            const SizedBox(height: 14),
            _mcpCard(context),
          ] else
            _connectHint(),
        ],
      ),
    ),
  );

  Widget _connectionCard() {
    final connected = controller.isConnected;
    return VvewellCard(
      color: VvewellColors.softViolet,
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
                  Icons.smart_toy_outlined,
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
                      device.name.isEmpty ? '健康小助手' : device.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      connected ? '设备已连接，可使用控制服务' : '发现于附近，可安全连接',
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
          _row('设备地址', device.id),
          _row('蓝牙信号', '${device.rssi} dBm'),
          if (controller.isConnecting || controller.isBusy.value) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
          if (!connected) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: controller.isBusy.value ? null : controller.connect,
                icon: const Icon(Icons.bluetooth_connected),
                label: const Text('连接健康小助手'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusCard() => VvewellCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: VvewellSectionTitle('设备状态与系统信息')),
            IconButton(
              onPressed: controller.isBusy.value ? null : controller.refreshAll,
              tooltip: '刷新',
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        _jsonBlock('设备状态', controller.deviceStatus.value),
        _jsonBlock('系统信息', controller.systemInfo.value),
        _jsonBlock('Wi-Fi 状态', controller.wifiStatus.value),
      ],
    ),
  );

  Widget _wifiCard(BuildContext context) => VvewellCard(
    color: VvewellColors.softBlue,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const VvewellSectionTitle('Wi-Fi 配网'),
        const SizedBox(height: 5),
        const Text(
          '扫描附近网络或将网络凭据安全发送到设备。',
          style: TextStyle(color: VvewellColors.muted, fontSize: 13),
        ),
        const SizedBox(height: 13),
        Wrap(
          spacing: 9,
          runSpacing: 9,
          children: [
            OutlinedButton.icon(
              onPressed: controller.isBusy.value ? null : controller.scanWifi,
              icon: const Icon(Icons.wifi_find),
              label: const Text('扫描 Wi-Fi'),
            ),
            ElevatedButton.icon(
              onPressed: controller.isBusy.value
                  ? null
                  : () => _showWifiDialog(context),
              icon: const Icon(Icons.wifi),
              label: const Text('配置网络'),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _quickControls() => VvewellCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const VvewellSectionTitle('快捷控制'),
        const SizedBox(height: 6),
        _slider(
          '音量',
          controller.volume.value,
          (value) => controller.volume.value = value,
          controller.setVolume,
        ),
        _slider(
          '亮度',
          controller.brightness.value,
          (value) => controller.brightness.value = value,
          controller.setBrightness,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 9,
          runSpacing: 9,
          children: [
            ElevatedButton.icon(
              onPressed: controller.isBusy.value
                  ? null
                  : controller.startListening,
              icon: const Icon(Icons.mic_none),
              label: const Text('开始聆听'),
            ),
            OutlinedButton.icon(
              onPressed: controller.isBusy.value
                  ? null
                  : controller.stopListening,
              icon: const Icon(Icons.mic_off_outlined),
              label: const Text('停止聆听'),
            ),
          ],
        ),
        _jsonBlock('最近命令响应', controller.latestResponse.value),
      ],
    ),
  );

  Widget _proactiveVoiceCard(BuildContext context) {
    final status = controller.proactiveVoiceStatus.value;
    final config = status.config;
    final schedule = ProactiveVoiceConfig.formatScheduledGreetingTimes(
      config.normalizedScheduledGreetingMinutes,
    );
    return VvewellCard(
      color: VvewellColors.softViolet,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: VvewellSectionTitle('主动语音关怀'),
              ),
              Switch.adaptive(
                value: config.enabled,
                onChanged: controller.isBusy.value
                    ? null
                    : (enabled) => controller.updateProactiveVoiceConfig(
                        config.copyWith(enabled: enabled),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            '心率或血氧异常时，小智会通过 BLE 发起对话并语音提醒；普通问候会避开夜间免打扰。',
            style: const TextStyle(color: VvewellColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 10),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('每个整点主动问候'),
            subtitle: const Text('默认开启；不替代异常健康提醒'),
            value: config.hourlyGreetingEnabled,
            onChanged: config.enabled
                ? (enabled) => controller.updateProactiveVoiceConfig(
                    config.copyWith(hourlyGreetingEnabled: enabled),
                  )
                : null,
          ),
          Text(
            schedule.isEmpty ? '定时问候：未设置' : '定时问候：$schedule',
            style: const TextStyle(color: VvewellColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              ElevatedButton.icon(
                onPressed: !config.enabled ||
                        !status.isXiaoZhiConnected ||
                        controller.isBusy.value
                    ? null
                    : controller.speakNow,
                icon: const Icon(Icons.record_voice_over_outlined),
                label: const Text('现在问候'),
              ),
              OutlinedButton.icon(
                onPressed: () => _showProactiveVoiceDialog(context, config),
                icon: const Icon(Icons.tune),
                label: const Text('提醒设置'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            status.isXiaoZhiConnected
                ? '已连接 · 待完成对话 ${status.pendingConversationCount}/4'
                : '小智未连接，连接成功后会自动开始主动语音',
            style: const TextStyle(color: VvewellColors.muted, fontSize: 12),
          ),
          if (status.lastError != null) ...[
            const SizedBox(height: 4),
            Text(
              status.lastError!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _customCommandCard(BuildContext context) => VvewellCard(
    color: VvewellColors.softOrange,
    child: Row(
      children: [
        const Icon(Icons.terminal, color: VvewellColors.primaryDark),
        const SizedBox(width: 11),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('兼容命令', style: TextStyle(fontWeight: FontWeight.w800)),
              SizedBox(height: 3),
              Text(
                '发送固件支持的命令与 JSON 参数。',
                style: TextStyle(color: VvewellColors.muted, fontSize: 13),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => _showCommandDialog(context),
          tooltip: '发送命令',
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    ),
  );

  Widget _mcpCard(BuildContext context) => VvewellCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const VvewellSectionTitle('MCP 工具'),
        const SizedBox(height: 5),
        const Text(
          '先初始化并获取设备实际支持的工具，再调用对应能力。',
          style: TextStyle(color: VvewellColors.muted, fontSize: 13),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: controller.isBusy.value
                  ? null
                  : controller.initializeMcp,
              child: const Text('初始化 MCP'),
            ),
            ElevatedButton(
              onPressed: controller.isBusy.value
                  ? null
                  : controller.listMcpTools,
              child: const Text('获取工具列表'),
            ),
            OutlinedButton(
              onPressed: () => _showMcpDialog(context, raw: false),
              child: const Text('调用 MCP 工具'),
            ),
            TextButton(
              onPressed: () => _showMcpDialog(context, raw: true),
              child: const Text('原始请求'),
            ),
          ],
        ),
        _jsonBlock('最近 MCP 响应', controller.latestMcpResponse.value),
      ],
    ),
  );

  Widget _slider(
    String title,
    int value,
    ValueChanged<int> onChanged,
    Future<void> Function(int) onDone,
  ) => Row(
    children: [
      SizedBox(
        width: 40,
        child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      Expanded(
        child: Slider(
          value: value.toDouble(),
          min: 0,
          max: 100,
          divisions: 20,
          label: '$value%',
          onChanged: controller.isBusy.value
              ? null
              : (v) => onChanged(v.round()),
          onChangeEnd: controller.isBusy.value
              ? null
              : (v) => onDone(v.round()),
        ),
      ),
      SizedBox(
        width: 40,
        child: Text(
          '$value%',
          textAlign: TextAlign.right,
          style: const TextStyle(color: VvewellColors.muted),
        ),
      ),
    ],
  );

  Widget _jsonBlock(String title, String value) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        const SizedBox(height: 5),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: VvewellColors.background,
            borderRadius: BorderRadius.circular(12),
          ),
          child: SelectableText(
            value.isEmpty ? '暂无数据' : value,
            style: const TextStyle(fontSize: 12, color: VvewellColors.muted),
          ),
        ),
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
            '连接过程中请在系统弹窗中确认蓝牙配对。首次连接会完成配对、服务发现和通知订阅。',
            style: TextStyle(color: VvewellColors.muted, height: 1.4),
          ),
        ),
      ],
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
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ),
      ],
    ),
  );

  String _stateText(String state) =>
      {
        'ready': '已连接',
        'connecting': '连接中',
        'pairing': '配对中',
        'failed': '连接失败',
        'disconnected': '未连接',
      }[state] ??
      state;

  Future<void> _showProactiveVoiceDialog(
    BuildContext context,
    ProactiveVoiceConfig config,
  ) async {
    final heartRateLow = TextEditingController(text: '${config.heartRateLow}');
    final heartRateHigh = TextEditingController(text: '${config.heartRateHigh}');
    final spo2Low = TextEditingController(text: '${config.spo2Low}');
    final cooldown = TextEditingController(
      text: '${config.healthAlertCooldown.inMinutes}',
    );
    final schedule = TextEditingController(
      text: ProactiveVoiceConfig.formatScheduledGreetingTimes(
        config.normalizedScheduledGreetingMinutes,
      ),
    );
    try {
      await Get.dialog(
        AlertDialog(
          title: const Text('主动语音提醒设置'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: heartRateLow,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '心率偏低阈值（bpm）'),
                ),
                TextField(
                  controller: heartRateHigh,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '心率偏高阈值（bpm）'),
                ),
                TextField(
                  controller: spo2Low,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '血氧偏低阈值（%）'),
                ),
                TextField(
                  controller: cooldown,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '同类健康提醒间隔（分钟）'),
                ),
                TextField(
                  controller: schedule,
                  decoration: const InputDecoration(
                    labelText: '额外定时问候（如 08:30, 12:00）',
                    helperText: '24 小时制，留空则只按整点问候',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: Get.back, child: const Text('取消')),
            ElevatedButton(
              onPressed: () {
                final low = int.tryParse(heartRateLow.text.trim());
                final high = int.tryParse(heartRateHigh.text.trim());
                final oxygen = int.tryParse(spo2Low.text.trim());
                final minutes = int.tryParse(cooldown.text.trim());
                if (low == null ||
                    high == null ||
                    oxygen == null ||
                    minutes == null ||
                    low < 30 ||
                    high > 220 ||
                    low >= high ||
                    oxygen < 70 ||
                    oxygen > 100 ||
                    minutes <= 0) {
                  Get.snackbar('设置无效', '请检查心率、血氧阈值和提醒间隔');
                  return;
                }
                controller.updateProactiveVoiceConfig(
                  config.copyWith(
                    heartRateLow: low,
                    heartRateHigh: high,
                    spo2Low: oxygen,
                    healthAlertCooldown: Duration(minutes: minutes),
                    scheduledGreetingMinutes:
                        ProactiveVoiceConfig.parseScheduledGreetingTimes(
                      schedule.text,
                    ),
                  ),
                );
                Get.back();
              },
              child: const Text('保存'),
            ),
          ],
        ),
      );
    } finally {
      heartRateLow.dispose();
      heartRateHigh.dispose();
      spo2Low.dispose();
      cooldown.dispose();
      schedule.dispose();
    }
  }

  Future<void> _showWifiDialog(BuildContext context) async {
    final ssid = TextEditingController();
    final password = TextEditingController();
    await Get.dialog(
      AlertDialog(
        title: const Text('配置 Wi-Fi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ssid,
              decoration: const InputDecoration(labelText: '网络名称 (SSID)'),
            ),
            TextField(
              controller: password,
              obscureText: true,
              decoration: const InputDecoration(labelText: '密码'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: Get.back, child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              Get.back();
              controller.configureWifi(ssid.text, password.text);
            },
            child: const Text('发送'),
          ),
        ],
      ),
    );
    ssid.dispose();
    password.dispose();
  }

  Future<void> _showCommandDialog(BuildContext context) async {
    final command = TextEditingController();
    final params = TextEditingController(text: '{}');
    await Get.dialog(
      AlertDialog(
        title: const Text('发送兼容命令'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: command,
              decoration: const InputDecoration(labelText: '命令'),
            ),
            TextField(
              controller: params,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'JSON 参数'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: Get.back, child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              Get.back();
              controller.sendCustomCommand(command.text, params.text);
            },
            child: const Text('发送'),
          ),
        ],
      ),
    );
    command.dispose();
    params.dispose();
  }

  Future<void> _showMcpDialog(BuildContext context, {required bool raw}) async {
    final name = TextEditingController();
    final body = TextEditingController(
      text: raw
          ? '{"jsonrpc":"2.0","id":10,"method":"tools/list","params":{}}'
          : '{}',
    );
    await Get.dialog(
      AlertDialog(
        title: Text(raw ? '发送原始 MCP 请求' : '调用 MCP 工具'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!raw)
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: '工具名称'),
              ),
            TextField(
              controller: body,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: raw ? 'JSON-RPC 请求' : '工具参数 JSON',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: Get.back, child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              Get.back();
              raw
                  ? controller.sendRawMcpRequest(body.text)
                  : controller.callMcpTool(name.text, body.text);
            },
            child: const Text('发送'),
          ),
        ],
      ),
    );
    name.dispose();
    body.dispose();
  }
}
