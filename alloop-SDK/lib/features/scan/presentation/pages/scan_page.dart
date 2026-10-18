import 'package:alloop/features/aizoring/domain/models/smart_ring_device.dart';
import 'package:alloop/features/aizoring/domain/models/smart_ring_type.dart';
import 'package:alloop/foundations/navigation/al_routes.dart';
import 'package:alloop/foundations/ui/vvewell_theme.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/scan_controller.dart';

/// Branded scan surface. Discovery, filtering, connection routing, and all BLE
/// lifecycle calls deliberately remain owned by [ScanController].
class ScanPage extends GetView<ScanController> {
  const ScanPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Scan nearby devices"),
        actions: [
          Obx(
            () => IconButton(
              tooltip: "Scan again",
              onPressed: controller.isScanning.value
                  ? null
                  : () => controller.startScan(),
              icon: const Icon(Icons.refresh),
            ),
          ),
        ],
      ),
      body: Obx(
        () => Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 18),
                children: [
                  _scanHero(),
                  const SizedBox(height: 16),
                  _filterCard(),
                  const SizedBox(height: 16),
                  _scanStatus(),
                  if (controller.connectedDevices.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    const VvewellSectionTitle("Connected devices"),
                    const SizedBox(height: 10),
                    ...controller.connectedDevices.map(_connectedCard),
                  ],
                  const SizedBox(height: 20),
                  VvewellSectionTitle(
                    controller.devices.isEmpty
                        ? "Scan results"
                        : 'Found ${controller.devices.length} devices found',
                  ),
                  const SizedBox(height: 10),
                  ..._deviceResults(),
                ],
              ),
            ),
            _scanControl(),
          ],
        ),
      ),
    );
  }

  Widget _scanHero() {
    final isScanning = controller.isScanning.value;
    return VvewellCard(
      color: VvewellColors.softTeal,
      child: Row(
        children: [
          _ScanArtwork(active: isScanning),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                VvewellStatusPill(
                  label: isScanning ? "Scanning" : "Scan paused",
                  color: isScanning
                      ? VvewellColors.success
                      : VvewellColors.muted,
                  icon: isScanning
                      ? Icons.bluetooth_searching
                      : Icons.bluetooth_disabled,
                ),
                const SizedBox(height: 10),
                Text(
                  isScanning ? "Looking for nearby devices" : "Ready to scan again",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isScanning
                      ? 'Found ${controller.devices.length} matching devices found.'
                      : "Tap below to discover supported Bluetooth devices.",
                  style: const TextStyle(
                    color: VvewellColors.muted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterCard() {
    return VvewellCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.filter_alt_outlined, color: VvewellColors.primaryDark),
              SizedBox(width: 8),
              Text("Device filter", style: TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller.filterController,
            onChanged: controller.updateFilter,
            onSubmitted: (_) => controller.startScan(),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: "Name keywords, separated by spaces or commas",
              suffixIcon: controller.filterController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: "Clear filter",
                      onPressed: () {
                        controller.filterController.clear();
                        controller.updateFilter('');
                      },
                      icon: const Icon(Icons.close),
                    ),
            ),
          ),
          if (controller.filterTexts.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: controller.filterTexts
                  .map(
                    (filter) => InputChip(
                      label: Text(filter),
                      onDeleted: () {
                        final filters = List<String>.from(
                          controller.filterTexts,
                        )..remove(filter);
                        controller.filterController.text = filters.join(', ');
                        controller.updateFilter(
                          controller.filterController.text,
                        );
                      },
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _scanStatus() {
    final active = controller.isScanning.value;
    return VvewellCard(
      color: active ? VvewellColors.softBlue : VvewellColors.surface,
      child: Row(
        children: [
          Icon(
            active ? Icons.radar : Icons.info_outline,
            color: active ? VvewellColors.primaryDark : VvewellColors.muted,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              active ? "Scanning. Devices will appear below as they are found." : "Scan stopped. Scan again or open a connected device.",
              style: const TextStyle(color: VvewellColors.muted, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _connectedCard(SmartRingDevice device) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: VvewellCard(
        color: VvewellColors.softMint,
        onTap: () => _navigateToDetail(device),
        child: Row(
          children: [
            _DeviceAvatar(type: device.type),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _deviceName(device),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Connected · ${device.type.displayName}',
                    style: const TextStyle(
                      color: VvewellColors.success,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    device.id,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: VvewellColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: VvewellColors.muted),
          ],
        ),
      ),
    );
  }

  List<Widget> _deviceResults() {
    if (controller.devices.isEmpty) {
      return [
        VvewellCard(
          color: VvewellColors.surface,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
          child: Column(
            children: [
              Icon(
                controller.isScanning.value
                    ? Icons.bluetooth_searching
                    : Icons.bluetooth_disabled,
                size: 48,
                color: VvewellColors.muted,
              ),
              const SizedBox(height: 12),
              Text(
                controller.isScanning.value ? "Searching for supported devices…" : "No devices found yet",
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 5),
              const Text(
                "Turn on Bluetooth and make sure your device is available to connect.",
                textAlign: TextAlign.center,
                style: TextStyle(color: VvewellColors.muted),
              ),
            ],
          ),
        ),
      ];
    }

    final rings = controller.devices
        .where(
          (device) =>
              device.type == SmartRingType.alloop ||
              device.type == SmartRingType.aizoring,
        )
        .toList();
    final xiaozhi = controller.devices
        .where((device) => device.type == SmartRingType.xiaozhi)
        .toList();
    final radar = controller.devices
        .where((device) => device.type == SmartRingType.radar)
        .toList();
    final robots = controller.devices
        .where((device) => device.type == SmartRingType.robot)
        .toList();
    final result = <Widget>[];
    void addSection(
      String label,
      IconData icon,
      List<SmartRingDevice> devices,
    ) {
      if (devices.isEmpty) return;
      if (result.isNotEmpty) result.add(const SizedBox(height: 18));
      result.add(
        Row(
          children: [
            Icon(icon, color: VvewellColors.primaryDark, size: 19),
            const SizedBox(width: 7),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: VvewellColors.primaryDark,
              ),
            ),
          ],
        ),
      );
      result.add(const SizedBox(height: 8));
      result.addAll(
        devices.map(
          (device) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _deviceCard(device),
          ),
        ),
      );
    }

    addSection("Smart rings", Icons.ring_volume_outlined, rings);
    addSection("Health Assistant", Icons.smart_toy_outlined, xiaozhi);
    addSection("mmWave radar", Icons.radar, radar);
    addSection('vvewell Robot', Icons.smart_toy_outlined, robots);
    return result;
  }

  Widget _deviceCard(SmartRingDevice device) {
    final signalColor = _signalColor(device.rssi);
    return VvewellCard(
      onTap: () => _navigateToDetail(device),
      child: Row(
        children: [
          _DeviceAvatar(type: device.type),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _deviceName(device),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    _typePill(device.type),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  device.id,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: VvewellColors.muted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.signal_cellular_alt,
                      size: 16,
                      color: signalColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${device.rssi} dBm · ${_signalLabel(device.rssi)}',
                      style: TextStyle(
                        color: signalColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, color: VvewellColors.muted),
        ],
      ),
    );
  }

  Widget _typePill(SmartRingType type) {
    final color = _typeColor(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        type.displayName,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _scanControl() {
    final active = controller.isScanning.value;
    return Material(
      color: VvewellColors.surface,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(20, 10, 20, 14),
        child: SizedBox(
          width: double.infinity,
          child: active
              ? OutlinedButton.icon(
                  onPressed: () => controller.stopScan(),
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: const Text("Stop scan"),
                )
              : ElevatedButton.icon(
                  onPressed: () => controller.startScan(),
                  icon: const Icon(Icons.bluetooth_searching),
                  label: const Text("Start scan"),
                ),
        ),
      ),
    );
  }

  Future<void> _navigateToDetail(SmartRingDevice device) async {
    // The existing repositories own connection setup. Stop discovery first so
    // vendor BLE callbacks cannot contend with the detail page's pairing flow.
    await controller.stopScan();
    switch (device.type) {
      case SmartRingType.alloop:
        Get.toNamed(
          AlRoutes.deviceDetail,
          arguments: {'device': device, 'connectOnOpen': true},
        );
      case SmartRingType.aizoring:
        Get.toNamed(AlRoutes.aizoringDeviceDetail, arguments: device);
      case SmartRingType.xiaozhi:
        Get.toNamed(AlRoutes.xiaozhiDeviceDetail, arguments: device);
      case SmartRingType.radar:
        Get.toNamed(AlRoutes.radarDeviceDetail, arguments: device);
      case SmartRingType.robot:
        Get.toNamed(AlRoutes.robotDeviceDetail, arguments: device);
      case SmartRingType.glasses:
        Get.toNamed(AlRoutes.rokidGlasses);
    }
  }

  String _deviceName(SmartRingDevice device) =>
      device.name.isEmpty ? "Unnamed device" : device.name;

  Color _typeColor(SmartRingType type) {
    switch (type) {
      case SmartRingType.alloop:
      case SmartRingType.aizoring:
        return VvewellColors.primaryDark;
      case SmartRingType.xiaozhi:
        return const Color(0xFF6C57A9);
      case SmartRingType.radar:
        return const Color(0xFFBA7416);
      case SmartRingType.glasses:
        return const Color(0xFF39709C);
      case SmartRingType.robot:
        return const Color(0xFF6C57A9);
    }
  }

  Color _signalColor(int rssi) {
    if (rssi >= -50) return VvewellColors.success;
    if (rssi >= -70) return VvewellColors.warning;
    return VvewellColors.error;
  }

  String _signalLabel(int rssi) {
    if (rssi >= -50) return "Excellent signal";
    if (rssi >= -70) return "Good signal";
    return "Weak signal";
  }
}

class _DeviceAvatar extends StatelessWidget {
  const _DeviceAvatar({required this.type});
  final SmartRingType type;

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;
    switch (type) {
      case SmartRingType.alloop:
        icon = Icons.ring_volume_outlined;
        color = VvewellColors.softBlue;
      case SmartRingType.aizoring:
        icon = Icons.diamond_outlined;
        color = VvewellColors.softTeal;
      case SmartRingType.xiaozhi:
        icon = Icons.smart_toy_outlined;
        color = VvewellColors.softViolet;
      case SmartRingType.radar:
        icon = Icons.radar;
        color = VvewellColors.softOrange;
      case SmartRingType.glasses:
        icon = Icons.visibility_outlined;
        color = VvewellColors.softBlue;
      case SmartRingType.robot:
        icon = Icons.smart_toy_outlined;
        color = VvewellColors.softViolet;
    }
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Icon(icon, color: VvewellColors.primaryDark),
    );
  }
}

class _ScanArtwork extends StatelessWidget {
  const _ScanArtwork({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 70,
    height: 70,
    child: CustomPaint(painter: _ScanArtworkPainter(active)),
  );
}

class _ScanArtworkPainter extends CustomPainter {
  const _ScanArtworkPainter(this.active);
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final accent = active ? VvewellColors.primary : VvewellColors.muted;
    for (final radius in [
      size.width * .18,
      size.width * .31,
      size.width * .45,
    ]) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = accent.withValues(
            alpha: radius == size.width * .18 ? .16 : .10,
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    canvas.drawCircle(center, 8, Paint()..color = accent);
    canvas.drawCircle(center, 3, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _ScanArtworkPainter oldDelegate) =>
      oldDelegate.active != active;
}
