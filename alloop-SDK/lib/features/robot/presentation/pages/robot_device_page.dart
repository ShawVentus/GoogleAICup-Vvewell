import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../aizoring/domain/models/smart_ring_device.dart';
import '../../../../foundations/ui/vvewell_theme.dart';
import '../controllers/robot_device_controller.dart';

class RobotDevicePage extends GetView<RobotDeviceController> {
  const RobotDevicePage({super.key, required this.device});
  final SmartRingDevice device;

  static const _expressions = [
    ('blue_upper', "Blue · Look up", Icons.sentiment_satisfied_alt),
    ('blue_middle', "Blue · Look ahead", Icons.sentiment_neutral),
    ('blue_lower', "Blue · Look down", Icons.sentiment_dissatisfied),
    ('yellow_upper', "Yellow · Look up", Icons.wb_sunny_outlined),
    ('yellow_middle', "Yellow · Look ahead", Icons.light_mode_outlined),
    ('yellow_lower', "Yellow · Look down", Icons.nightlight_outlined),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(device.name.isEmpty ? 'vvewell Robot' : device.name),
          actions: [
            Obx(() => IconButton(
                  tooltip: controller.isConnected ? "Disconnect" : "Reconnect",
                  onPressed: controller.isBusy.value
                      ? null
                      : (controller.isConnected ? controller.disconnect : controller.connect),
                  icon: Icon(controller.isConnected
                      ? Icons.bluetooth_disabled
                      : Icons.bluetooth),
                )),
          ],
        ),
        body: Obx(() => ListView(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 32),
              children: [
                _connectionCard(),
                const SizedBox(height: 14),
                if (controller.isConnected) ...[
                  _expressionCard(),
                  const SizedBox(height: 14),
                  _servoCard(),
                  const SizedBox(height: 14),
                  _responseCard(),
                ] else
                  _connectHint(),
              ],
            )),
      );

  Widget _connectionCard() => VvewellCard(
        color: VvewellColors.softViolet,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: const Icon(Icons.smart_toy_outlined, size: 29, color: VvewellColors.primaryDark),
            ),
            const SizedBox(width: 13),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('vvewell Robot', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(controller.isConnected ? "Connected. Expressions and the SG90 servo are ready." : "Establishing GATT control connection.",
                  style: const TextStyle(color: VvewellColors.muted)),
            ])),
            VvewellStatusPill(
              label: controller.isConnected ? "Connected" : "Disconnected",
              color: controller.isConnected ? VvewellColors.success : VvewellColors.muted,
              icon: controller.isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
            ),
          ]),
          const SizedBox(height: 14),
          Text('Device address: ${device.id}', style: const TextStyle(color: VvewellColors.muted, fontSize: 13)),
          if (controller.isBusy.value) ...[const SizedBox(height: 12), const LinearProgressIndicator()],
          if (!controller.isConnected) ...[
            const SizedBox(height: 15),
            SizedBox(width: double.infinity, child: ElevatedButton.icon(
              onPressed: controller.isBusy.value ? null : controller.connect,
              icon: const Icon(Icons.bluetooth_connected), label: const Text("Connect Robot"),
            )),
          ],
        ]),
      );

  Widget _expressionCard() => VvewellCard(
        color: VvewellColors.softBlue,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const VvewellSectionTitle("Expressions"),
          const SizedBox(height: 5),
          const Text("Choose an expression. Turn expressions off to switch off the display.", style: TextStyle(color: VvewellColors.muted, fontSize: 13)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 2.7,
            children: _expressions.map((item) => _expressionButton(item.$1, item.$2, item.$3)).toList(),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: controller.isBusy.value ? null : () => controller.setExpression('off'),
            icon: const Icon(Icons.visibility_off_outlined), label: const Text("Turn expressions off"),
          ),
        ]),
      );

  Widget _expressionButton(String id, String label, IconData icon) {
    final selected = controller.selectedExpression.value == id;
    return OutlinedButton.icon(
      onPressed: controller.isBusy.value ? null : () => controller.setExpression(id),
      style: OutlinedButton.styleFrom(backgroundColor: selected ? Colors.white : null),
      icon: Icon(icon, size: 18), label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }

  Widget _servoCard() => VvewellCard(
        color: VvewellColors.softOrange,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const VvewellSectionTitle("SG90 servo angle"),
          const SizedBox(height: 5),
          Text('${controller.angle.value.round()}°', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: VvewellColors.primaryDark)),
          Slider(
            value: controller.angle.value, min: 0, max: 180, divisions: 180,
            label: '${controller.angle.value.round()}°',
            onChanged: controller.isBusy.value ? null : (value) => controller.angle.value = value,
            onChangeEnd: controller.isBusy.value ? null : controller.setServoAngle,
          ),
          Row(children: [
            Expanded(child: ElevatedButton.icon(
              onPressed: controller.isBusy.value ? null : () => controller.setServoAngle(controller.angle.value),
              icon: const Icon(Icons.rotate_right), label: const Text("Set angle"),
            )),
            const SizedBox(width: 9),
            OutlinedButton.icon(
              onPressed: controller.isBusy.value ? null : controller.turnServoOff,
              icon: const Icon(Icons.power_settings_new), label: const Text("Power off servo"),
            ),
          ]),
        ]),
      );

  Widget _responseCard() => VvewellCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Expanded(child: VvewellSectionTitle("Device response")), IconButton(onPressed: controller.isBusy.value ? null : controller.requestStatus, icon: const Icon(Icons.refresh), tooltip: "Read status")]),
        Text(controller.latestResponse.value.isEmpty ? "No response received yet." : controller.latestResponse.value,
            style: const TextStyle(color: VvewellColors.muted, fontFamily: 'monospace', fontSize: 12)),
      ]));

  Widget _connectHint() => const VvewellCard(
        child: Text("Keep Robot powered on and advertising. Connect to control expressions and the servo.", style: TextStyle(color: VvewellColors.muted)),
      );
}
