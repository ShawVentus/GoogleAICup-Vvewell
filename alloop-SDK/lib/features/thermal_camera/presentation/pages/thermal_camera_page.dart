import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../foundations/ui/vvewell_theme.dart';
import '../controllers/thermal_camera_controller.dart';

class ThermalCameraPage extends GetView<ThermalCameraController> {
  const ThermalCameraPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('USB 红外摄像头'),
        actions: [
          IconButton(
            tooltip: '重新连接 USB 摄像头',
            onPressed: controller.isBusy.value ? null : controller.connect,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Obx(
        () => ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [_previewCard()],
        ),
      ),
    );
  }

  Widget _previewCard() {
    return VvewellCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: ColoredBox(
                color: Colors.black,
                child: defaultTargetPlatform == TargetPlatform.android
                    ? const AndroidView(viewType: 'alloop/thermal_camera_view')
                    : const Center(
                        child: Text(
                          'USB 红外摄像头仅支持 Android',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(
                    controller.isPreviewing
                        ? Icons.videocam
                        : Icons.videocam_off_outlined,
                    color: controller.isPreviewing
                        ? VvewellColors.success
                        : VvewellColors.muted,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      _stateLabel(controller.connectionState.value),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            if (controller.errorMessage.value.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Text(
                  controller.errorMessage.value,
                  style: const TextStyle(color: VvewellColors.error),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: controller.isConnected
                  ? OutlinedButton.icon(
                      onPressed: controller.isBusy.value
                          ? null
                          : controller.disconnect,
                      icon: const Icon(Icons.link_off),
                      label: const Text('断开 USB 摄像头'),
                    )
                  : ElevatedButton.icon(
                      onPressed: controller.isBusy.value
                          ? null
                          : controller.connect,
                      icon: const Icon(Icons.play_circle_outline),
                      label: Text(
                        controller.isBusy.value ? '正在连接…' : '连接 USB 摄像头',
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _stateLabel(String state) => switch (state) {
    'connecting' => '正在连接 USB 红外摄像头…',
    'previewing' => '正在读取 USB 红外实时画面',
    'error' => 'USB 摄像头连接失败',
    _ => '等待 USB 红外摄像头',
  };
}
