import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../foundations/ui/vvewell_theme.dart';
import '../controllers/rokid_glasses_controller.dart';

class RokidGlassesPage extends GetView<RokidGlassesController> {
  const RokidGlassesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 智能眼镜'),
        actions: [
          IconButton(
            tooltip: '刷新状态',
            onPressed: controller.refreshStatus,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Obx(
        () => ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            VvewellCard(
              color: controller.ready.value
                  ? VvewellColors.softMint
                  : VvewellColors.softBlue,
              child: Row(
                children: [
                  const Icon(
                    Icons.visibility_outlined,
                    size: 52,
                    color: VvewellColors.primaryDark,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          controller.deviceInfo['deviceName']?.toString() ??
                              'Rokid AI 眼镜',
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 7),
                        VvewellStatusPill(
                          label: controller.ready.value
                              ? 'CXRLink 已就绪'
                              : controller.companionConnected.value
                              ? '眼镜已连接，等待授权'
                              : '尚未连接',
                          color: controller.ready.value
                              ? VvewellColors.success
                              : VvewellColors.muted,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            VvewellCard(
              child: Column(
                children: [
                  _StatusRow(
                    label: 'Rokid 配套应用',
                    ok: controller.companionInstalled.value,
                  ),
                  const Divider(height: 24),
                  _StatusRow(
                    label: '眼镜蓝牙',
                    ok:
                        controller.bluetoothConnected.value ||
                        controller.companionConnected.value,
                  ),
                  const Divider(height: 24),
                  _StatusRow(label: '应用授权', ok: controller.authorized.value),
                  const Divider(height: 24),
                  _StatusRow(
                    label: 'CXRLink 会话',
                    ok: controller.cxrlConnected.value,
                  ),
                ],
              ),
            ),
            if (controller.deviceInfo.isNotEmpty) ...[
              const SizedBox(height: 16),
              VvewellCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '设备信息',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '序列号：${controller.deviceInfo['serialNumber'] ?? '--'}',
                    ),
                    Text(
                      '系统版本：${controller.deviceInfo['systemVersion'] ?? '--'}',
                    ),
                    Text(
                      '电量：${controller.deviceInfo['batteryLevel'] ?? '--'}%',
                    ),
                  ],
                ),
              ),
            ],
            if (controller.errorMessage.value.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                controller.errorMessage.value,
                style: const TextStyle(color: VvewellColors.error),
              ),
            ],
            const SizedBox(height: 18),
            if (!controller.companionInstalled.value)
              OutlinedButton.icon(
                onPressed: controller.isBusy.value
                    ? null
                    : controller.openCompanionMarket,
                icon: const Icon(Icons.download_outlined),
                label: const Text('安装 Rokid 配套应用'),
              )
            else if (!controller.ready.value)
              ElevatedButton.icon(
                onPressed: controller.isBusy.value
                    ? null
                    : controller.authorizeAndConnect,
                icon: const Icon(Icons.link),
                label: Text(controller.isBusy.value ? '连接中…' : '授权并连接眼镜'),
              )
            else
              OutlinedButton.icon(
                onPressed: controller.isBusy.value
                    ? null
                    : controller.disconnect,
                icon: const Icon(Icons.link_off),
                label: const Text('断开 CXRLink 会话'),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.ok});

  final String label;
  final bool ok;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(
        ok ? Icons.check_circle : Icons.radio_button_unchecked,
        color: ok ? VvewellColors.success : VvewellColors.muted,
      ),
      const SizedBox(width: 10),
      Expanded(child: Text(label)),
      Text(
        ok ? '已就绪' : '未就绪',
        style: TextStyle(
          color: ok ? VvewellColors.success : VvewellColors.muted,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}
