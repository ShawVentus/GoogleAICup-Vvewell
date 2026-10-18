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
        title: const Text("AI glasses"),
        actions: [
          IconButton(
            tooltip: "Refresh status",
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
                              "Rokid AI glasses",
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 7),
                        VvewellStatusPill(
                          label: controller.ready.value
                              ? "CXRLink ready"
                              : controller.companionConnected.value
                              ? "Glasses connected; authorization required"
                              : "Not connected",
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
                    label: "Rokid companion app",
                    ok: controller.companionInstalled.value,
                  ),
                  const Divider(height: 24),
                  _StatusRow(
                    label: "Glasses Bluetooth",
                    ok:
                        controller.bluetoothConnected.value ||
                        controller.companionConnected.value,
                  ),
                  const Divider(height: 24),
                  _StatusRow(label: "App authorization", ok: controller.authorized.value),
                  const Divider(height: 24),
                  _StatusRow(
                    label: "CXRLink session",
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
                      "Device information",
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Serial number: ${controller.deviceInfo['serialNumber'] ?? '--'}',
                    ),
                    Text(
                      'System version: ${controller.deviceInfo['systemVersion'] ?? '--'}',
                    ),
                    Text(
                      'Battery: ${controller.deviceInfo['batteryLevel'] ?? '--'}%',
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
                label: const Text("Install Rokid companion app"),
              )
            else if (!controller.ready.value)
              ElevatedButton.icon(
                onPressed: controller.isBusy.value
                    ? null
                    : controller.authorizeAndConnect,
                icon: const Icon(Icons.link),
                label: Text(controller.isBusy.value ? "Connecting…" : "Authorize and connect glasses"),
              )
            else
              OutlinedButton.icon(
                onPressed: controller.isBusy.value
                    ? null
                    : controller.disconnect,
                icon: const Icon(Icons.link_off),
                label: const Text("Disconnect CXRLink"),
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
        ok ? "Ready" : "Not ready",
        style: TextStyle(
          color: ok ? VvewellColors.success : VvewellColors.muted,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}
