import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../aizoring/domain/models/smart_ring_device.dart';
import '../../../../foundations/ui/vvewell_theme.dart';
import '../controllers/robot_device_controller.dart';

class RobotDevicePage extends GetView<RobotDeviceController> {
  const RobotDevicePage({super.key, required this.device});
  final SmartRingDevice device;

  static const _expressions = [
    ('blue_upper', '蓝色 · 上弦', Icons.sentiment_satisfied_alt),
    ('blue_middle', '蓝色 · 平视', Icons.sentiment_neutral),
    ('blue_lower', '蓝色 · 低头', Icons.sentiment_dissatisfied),
    ('yellow_upper', '黄色 · 上弦', Icons.wb_sunny_outlined),
    ('yellow_middle', '黄色 · 平视', Icons.light_mode_outlined),
    ('yellow_lower', '黄色 · 低头', Icons.nightlight_outlined),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(device.name.isEmpty ? 'vvewell Robot' : device.name),
          actions: [
            Obx(() => IconButton(
                  tooltip: controller.isConnected ? '断开连接' : '重新连接',
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
              Text(controller.isConnected ? '已连接，可控制表情与 SG90 舵机。' : '正在建立 GATT 控制连接。',
                  style: const TextStyle(color: VvewellColors.muted)),
            ])),
            VvewellStatusPill(
              label: controller.isConnected ? '已连接' : '未连接',
              color: controller.isConnected ? VvewellColors.success : VvewellColors.muted,
              icon: controller.isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
            ),
          ]),
          const SizedBox(height: 14),
          Text('设备地址  ${device.id}', style: const TextStyle(color: VvewellColors.muted, fontSize: 13)),
          if (controller.isBusy.value) ...[const SizedBox(height: 12), const LinearProgressIndicator()],
          if (!controller.isConnected) ...[
            const SizedBox(height: 15),
            SizedBox(width: double.infinity, child: ElevatedButton.icon(
              onPressed: controller.isBusy.value ? null : controller.connect,
              icon: const Icon(Icons.bluetooth_connected), label: const Text('连接 Robot'),
            )),
          ],
        ]),
      );

  Widget _expressionCard() => VvewellCard(
        color: VvewellColors.softBlue,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const VvewellSectionTitle('表情控制'),
          const SizedBox(height: 5),
          const Text('选择显示表情；“关闭表情”会让面板熄灭。', style: TextStyle(color: VvewellColors.muted, fontSize: 13)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 2.7,
            children: _expressions.map((item) => _expressionButton(item.$1, item.$2, item.$3)).toList(),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: controller.isBusy.value ? null : () => controller.setExpression('off'),
            icon: const Icon(Icons.visibility_off_outlined), label: const Text('关闭表情'),
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
          const VvewellSectionTitle('SG90 舵机角度'),
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
              icon: const Icon(Icons.rotate_right), label: const Text('设置角度'),
            )),
            const SizedBox(width: 9),
            OutlinedButton.icon(
              onPressed: controller.isBusy.value ? null : controller.turnServoOff,
              icon: const Icon(Icons.power_settings_new), label: const Text('舵机断电'),
            ),
          ]),
        ]),
      );

  Widget _responseCard() => VvewellCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Expanded(child: VvewellSectionTitle('设备响应')), IconButton(onPressed: controller.isBusy.value ? null : controller.requestStatus, icon: const Icon(Icons.refresh), tooltip: '读取状态')]),
        Text(controller.latestResponse.value.isEmpty ? '尚未收到设备响应。' : controller.latestResponse.value,
            style: const TextStyle(color: VvewellColors.muted, fontFamily: 'monospace', fontSize: 12)),
      ]));

  Widget _connectHint() => const VvewellCard(
        child: Text('请保持 robot 开机并处于广播状态。连接成功后即可发送表情和舵机控制命令。', style: TextStyle(color: VvewellColors.muted)),
      );
}
