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
      title: Text(device.name.isEmpty ? "Health Assistant" : device.name),
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
                      device.name.isEmpty ? "Health Assistant" : device.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      connected ? "Connected. Device controls are ready" : "Nearby and available to connect",
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
          _row("Device address", device.id),
          _row("Bluetooth signal", '${device.rssi} dBm'),
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
                label: const Text("Connect health assistant"),
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
            const Expanded(child: VvewellSectionTitle("Device status and system information")),
            IconButton(
              onPressed: controller.isBusy.value ? null : controller.refreshAll,
              tooltip: "Refresh",
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        _jsonBlock("Device status", controller.deviceStatus.value),
        _jsonBlock("System information", controller.systemInfo.value),
        _jsonBlock("Wi-Fi status", controller.wifiStatus.value),
      ],
    ),
  );

  Widget _wifiCard(BuildContext context) => VvewellCard(
    color: VvewellColors.softBlue,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const VvewellSectionTitle("Wi-Fi setup"),
        const SizedBox(height: 5),
        const Text(
          "Scan nearby networks or securely send network credentials to the device.",
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
              label: const Text("Scan Wi-Fi"),
            ),
            ElevatedButton.icon(
              onPressed: controller.isBusy.value
                  ? null
                  : () => _showWifiDialog(context),
              icon: const Icon(Icons.wifi),
              label: const Text("Set up network"),
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
        const VvewellSectionTitle("Quick controls"),
        const SizedBox(height: 6),
        _slider(
          "Volume",
          controller.volume.value,
          (value) => controller.volume.value = value,
          controller.setVolume,
        ),
        _slider(
          "Brightness",
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
              label: const Text("Start listening"),
            ),
            OutlinedButton.icon(
              onPressed: controller.isBusy.value
                  ? null
                  : controller.stopListening,
              icon: const Icon(Icons.mic_off_outlined),
              label: const Text("Stop listening"),
            ),
          ],
        ),
        _jsonBlock("Latest command response", controller.latestResponse.value),
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
                child: VvewellSectionTitle("Proactive voice care"),
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
            "XiaoZhi starts a BLE conversation for heart rate or oxygen alerts. Routine greetings respect nighttime quiet hours.",
            style: const TextStyle(color: VvewellColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 10),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text("Greet at the start of each hour"),
            subtitle: const Text("On by default. Does not replace health alerts"),
            value: config.hourlyGreetingEnabled,
            onChanged: config.enabled
                ? (enabled) => controller.updateProactiveVoiceConfig(
                    config.copyWith(hourlyGreetingEnabled: enabled),
                  )
                : null,
          ),
          Text(
            schedule.isEmpty ? "Scheduled greetings: not set" : 'Scheduled greetings: $schedule',
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
                label: const Text("Greet now"),
              ),
              OutlinedButton.icon(
                onPressed: () => _showProactiveVoiceDialog(context, config),
                icon: const Icon(Icons.tune),
                label: const Text("Reminder settings"),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            status.isXiaoZhiConnected
                ? 'Connected · Pending conversations ${status.pendingConversationCount}/4'
                : "XiaoZhi is disconnected. Proactive voice starts when connected",
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
              Text("Firmware commands", style: TextStyle(fontWeight: FontWeight.w800)),
              SizedBox(height: 3),
              Text(
                "Send commands and JSON arguments supported by the firmware.",
                style: TextStyle(color: VvewellColors.muted, fontSize: 13),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => _showCommandDialog(context),
          tooltip: "Send command",
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    ),
  );

  Widget _mcpCard(BuildContext context) => VvewellCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const VvewellSectionTitle("MCP tools"),
        const SizedBox(height: 5),
        const Text(
          "Initialize MCP and fetch supported tools before calling a device capability.",
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
              child: const Text("Initialize MCP"),
            ),
            ElevatedButton(
              onPressed: controller.isBusy.value
                  ? null
                  : controller.listMcpTools,
              child: const Text("Get tools"),
            ),
            OutlinedButton(
              onPressed: () => _showMcpDialog(context, raw: false),
              child: const Text("Call MCP tool"),
            ),
            TextButton(
              onPressed: () => _showMcpDialog(context, raw: true),
              child: const Text("Raw request"),
            ),
          ],
        ),
        _jsonBlock("Latest MCP response", controller.latestMcpResponse.value),
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
            value.isEmpty ? "No data yet" : value,
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
            "Confirm Bluetooth pairing in the system dialog. The first connection pairs the device, discovers services and subscribes to notifications.",
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
        'ready': "Connected",
        'connecting': "Connecting",
        'pairing': "Pairing",
        'failed': "Connection failed",
        'disconnected': "Disconnected",
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
          title: const Text("Proactive voice settings"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: heartRateLow,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Low heart rate threshold (bpm)"),
                ),
                TextField(
                  controller: heartRateHigh,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "High heart rate threshold (bpm)"),
                ),
                TextField(
                  controller: spo2Low,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Low oxygen threshold (%)"),
                ),
                TextField(
                  controller: cooldown,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Repeat alert interval (minutes)"),
                ),
                TextField(
                  controller: schedule,
                  decoration: const InputDecoration(
                    labelText: "Additional greetings (e.g. 08:30, 12:00)",
                    helperText: "24-hour time. Leave blank for hourly greetings only",
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: Get.back, child: const Text("Cancel")),
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
                  Get.snackbar("Invalid settings", "Check heart rate and oxygen thresholds and the reminder interval");
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
              child: const Text("Save"),
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
        title: const Text("Configure Wi-Fi"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ssid,
              decoration: const InputDecoration(labelText: "Network name (SSID)"),
            ),
            TextField(
              controller: password,
              obscureText: true,
              decoration: const InputDecoration(labelText: "Password"),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: Get.back, child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              Get.back();
              controller.configureWifi(ssid.text, password.text);
            },
            child: const Text("Send"),
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
        title: const Text("Send firmware command"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: command,
              decoration: const InputDecoration(labelText: "Command"),
            ),
            TextField(
              controller: params,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: "JSON arguments"),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: Get.back, child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              Get.back();
              controller.sendCustomCommand(command.text, params.text);
            },
            child: const Text("Send"),
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
        title: Text(raw ? "Send raw MCP request" : "Call MCP tool"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!raw)
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: "Tool name"),
              ),
            TextField(
              controller: body,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: raw ? "JSON-RPC request" : "Tool arguments (JSON)",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: Get.back, child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              Get.back();
              raw
                  ? controller.sendRawMcpRequest(body.text)
                  : controller.callMcpTool(name.text, body.text);
            },
            child: const Text("Send"),
          ),
        ],
      ),
    );
    name.dispose();
    body.dispose();
  }
}
