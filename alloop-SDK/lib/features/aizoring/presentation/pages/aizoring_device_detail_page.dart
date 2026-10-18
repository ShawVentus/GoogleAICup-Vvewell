import 'package:alloop/features/aizoring/domain/models/smart_ring_device.dart';
import 'package:alloop/foundations/navigation/al_routes.dart';
import 'package:alloop/foundations/ui/vvewell_theme.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/aizoring_device_detail_controller.dart';

/// AIZORING connection screen using the vvewell device-card language while
/// keeping the original controller and feature routes intact.
class AizoringDeviceDetailPage extends GetView<AizoringDeviceDetailController> {
  const AizoringDeviceDetailPage({super.key, required this.device});

  final SmartRingDevice device;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(device.name.isEmpty ? 'AIZORING' : device.name),
        actions: [
          Obx(
            () => controller.isConnected.value
                ? IconButton(
                    tooltip: "Disconnect",
                    onPressed: controller.disconnect,
                    icon: const Icon(Icons.bluetooth_disabled),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
      body: Obx(
        () => ListView(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 32),
          children: [
            _deviceHero(),
            const SizedBox(height: 16),
            if (controller.isConnected.value) ...[
              _batteryCard(),
              const SizedBox(height: 16),
              _capabilitiesCard(),
              const SizedBox(height: 20),
              const VvewellSectionTitle("Measurements and data"),
              const SizedBox(height: 10),
              _featureEntry(
                icon: Icons.monitor_heart_outlined,
                title: "Measure now",
                subtitle: "Heart rate, oxygen, temperature, stress and UV",
                color: VvewellColors.softTeal,
                onTap: () => Get.toNamed(
                  AlRoutes.aizoringMeasurement,
                  arguments: device.id,
                ),
              ),
              const SizedBox(height: 10),
              _featureEntry(
                icon: Icons.multiline_chart_outlined,
                title: "Continuous data",
                subtitle: "Live PPI and raw sensor data",
                color: VvewellColors.softBlue,
                onTap: () => Get.toNamed(
                  AlRoutes.aizoringMeasurement,
                  arguments: device.id,
                ),
              ),
              const SizedBox(height: 10),
              _featureEntry(
                icon: Icons.health_and_safety_outlined,
                title: "Health history",
                subtitle: "Daily heart rate, oxygen, steps and temperature",
                color: VvewellColors.softMint,
                onTap: () => Get.toNamed(
                  AlRoutes.aizoringHealthData,
                  arguments: device.id,
                ),
              ),
              const SizedBox(height: 10),
              _featureEntry(
                icon: Icons.bedtime_outlined,
                title: "Sleep data",
                subtitle: "Sleep stages and duration",
                color: VvewellColors.softViolet,
                onTap: () =>
                    Get.toNamed(AlRoutes.aizoringSleep, arguments: device.id),
              ),
            ] else ...[
              _connectCard(),
              const SizedBox(height: 14),
              const VvewellCard(
                color: VvewellColors.softBlue,
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: VvewellColors.primaryDark),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Connect your device to view measurements, live data and sleep records.",
                        style: TextStyle(
                          color: VvewellColors.muted,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _deviceHero() {
    final connected = controller.isConnected.value;
    return VvewellCard(
      color: VvewellColors.softTeal,
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
                  Icons.diamond_outlined,
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
                      device.name.isEmpty ? "AIZORING smart ring" : device.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      connected ? "Connected; syncing data" : "Nearby and available to connect",
                      style: const TextStyle(color: VvewellColors.muted),
                    ),
                  ],
                ),
              ),
              VvewellStatusPill(
                label: connected ? "Connected" : "Disconnected",
                color: connected ? VvewellColors.success : VvewellColors.muted,
                icon: connected
                    ? Icons.bluetooth_connected
                    : Icons.bluetooth_disabled,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _infoRow("Device address", device.id),
          _infoRow("Bluetooth signal", '${device.rssi} dBm'),
          if (controller.deviceInfo.value != null) ...[
            _infoRow("Firmware version", controller.deviceInfo.value!.firmwareVersion),
            _infoRow("Device model", controller.deviceInfo.value!.modelName),
          ],
        ],
      ),
    );
  }

  Widget _batteryCard() {
    final percent = controller.batteryPercent.value;
    final color = percent >= 60
        ? VvewellColors.success
        : percent >= 30
        ? VvewellColors.warning
        : VvewellColors.error;
    return VvewellCard(
      color: color.withValues(alpha: .10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(
              controller.isCharging.value
                  ? Icons.battery_charging_full
                  : Icons.battery_std,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$percent%',
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  controller.isCharging.value ? "Charging" : "Battery level",
                  style: const TextStyle(color: VvewellColors.muted),
                ),
              ],
            ),
          ),
          Text(
            percent >= 60
                ? "Battery level is good"
                : percent >= 30
                ? "Charging recommended"
                : "Low battery",
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _capabilitiesCard() {
    final config = controller.deviceConfig.value;
    if (config == null) return const SizedBox.shrink();
    return VvewellCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const VvewellSectionTitle("Device features"),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _capability("Heart rate", config.supportsHeartRate),
              _capability("Blood oxygen", config.supportsBloodOxygen),
              _capability("Temperature", config.supportsTemperature),
              _capability("Sleep", config.supportsSleep),
            ],
          ),
        ],
      ),
    );
  }

  Widget _capability(String label, bool supported) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: supported ? VvewellColors.softMint : VvewellColors.background,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          supported ? Icons.check_circle_outline : Icons.remove_circle_outline,
          color: supported ? VvewellColors.success : VvewellColors.muted,
          size: 16,
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );

  Widget _featureEntry({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) => VvewellCard(
    color: color,
    onTap: onTap,
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(11),
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: VvewellColors.primaryDark),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: VvewellColors.muted,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right, color: VvewellColors.muted),
      ],
    ),
  );

  Widget _connectCard() => VvewellCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.bluetooth_outlined, color: VvewellColors.primaryDark),
            SizedBox(width: 8),
            Text(
              "Connect device",
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          "Confirm the Bluetooth pairing request in the system dialog when connecting for the first time.",
          style: TextStyle(color: VvewellColors.muted),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: controller.isConnecting.value
                ? null
                : controller.connect,
            icon: controller.isConnecting.value
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.bluetooth_connected),
            label: Text(
              controller.isConnecting.value ? "Connecting…" : "Connect AIZORING",
            ),
          ),
        ),
      ],
    ),
  );

  Widget _infoRow(String label, String value) => Padding(
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
}
