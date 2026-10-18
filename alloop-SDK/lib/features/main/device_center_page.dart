import 'dart:async';

import 'package:alloop_blue_lite/alloop_blue_lite.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/utils/al_permission_utils.dart';
import '../scan/data/connected_device_registry.dart';
import '../aizoring/domain/models/smart_ring_device.dart';
import '../aizoring/domain/models/smart_ring_type.dart';
import '../../foundations/navigation/al_routes.dart';
import '../../foundations/ui/vvewell_theme.dart';

/// Entry point for Bluetooth, CXRLink and directly attached USB hardware.
class DeviceCenterPage extends StatefulWidget {
  const DeviceCenterPage({super.key, this.connectedDevicesStream});

  /// Test/preview seam. Production uses the SDK's replaying connection stream.
  final Stream<List<LiteDevice>>? connectedDevicesStream;

  @override
  State<DeviceCenterPage> createState() => _DeviceCenterPageState();
}

class _DeviceCenterPageState extends State<DeviceCenterPage> {
  bool _myDevices = true;
  int _cartCount = 0;
  LiteDevice? _connectedAlloopRing;
  StreamSubscription<List<LiteDevice>>? _connectedDevicesSubscription;

  @override
  void initState() {
    super.initState();
    _connectedDevicesSubscription =
        (widget.connectedDevicesStream ??
                AlloopBlueLite.instance.connectedDevicesStream)
            .listen((devices) {
              if (!mounted) return;
              setState(() {
                _connectedAlloopRing = devices.isEmpty ? null : devices.first;
              });
            }, onError: (_) {});
  }

  @override
  void dispose() {
    _connectedDevicesSubscription?.cancel();
    super.dispose();
  }

  Future<void> _openScanner() async {
    final granted =
        await AlPermissionUtils.checkAndRequestBluetoothPermissions();
    if (granted && mounted) {
      Get.toNamed(AlRoutes.scan);
    }
  }

  void _openConnectedRing({required bool autoStart}) {
    final connected = _connectedAlloopRing;
    if (connected == null) return;
    final device = SmartRingDevice(
      id: connected.id,
      name: connected.name.isEmpty ? 'Alloop 智能戒指'.tr : connected.name,
      rssi: connected.rssi,
      type: SmartRingType.alloop,
    );
    Get.toNamed(
      AlRoutes.deviceDetail,
      arguments: {'device': device, 'autoStart': autoStart},
    );
  }

  void _openGlasses() => Get.toNamed(AlRoutes.rokidGlasses);

  void _openThermalCamera() => Get.toNamed(AlRoutes.thermalCamera);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('设备中心'.tr)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 32),
        children: [
          Text(
            '统一管理硬件、数据来源与同步状态。'.tr,
            style: TextStyle(color: VvewellColors.muted),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: VvewellColors.border,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                _Segment(
                  label: '我的设备'.tr,
                  selected: _myDevices,
                  onTap: () => setState(() => _myDevices = true),
                ),
                _Segment(
                  label: '硬件购买'.tr,
                  selected: !_myDevices,
                  onTap: () => setState(() => _myDevices = false),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (_myDevices)
            StreamBuilder<List<SmartRingDevice>>(
              stream: ConnectedDeviceRegistry.instance.stream,
              initialData: ConnectedDeviceRegistry.instance.devices,
              builder: (context, snapshot) =>
                  Column(children: _myDevicesContent()),
            )
          else
            ..._hardwareContent(),
        ],
      ),
    );
  }

  List<Widget> _myDevicesContent() {
    final otherDevices = ConnectedDeviceRegistry.instance.devices
        .where((device) => device.type != SmartRingType.alloop)
        .toList(growable: false);
    final connectedCount =
        otherDevices.length + (_connectedAlloopRing == null ? 0 : 1);
    if (connectedCount == 0) return _disconnectedDevicesContent();

    return [
      Row(
        children: [
          Expanded(child: VvewellSectionTitle('已连接设备'.tr)),
          Text(
            '@count 台在线'.trParams({'count': '$connectedCount'}),
            style: const TextStyle(
              color: VvewellColors.success,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      if (_connectedAlloopRing != null) ..._connectedAlloopContent(),
      ...otherDevices.map(_connectedHardwareCard),
      const SizedBox(height: 10),
      ..._disconnectedDevicesContent(addingAnother: true),
    ];
  }

  List<Widget> _connectedAlloopContent() {
    final device = _connectedAlloopRing!;
    final name = device.name.isEmpty ? 'Alloop 智能戒指'.tr : device.name;
    return [
      VvewellCard(
        key: const Key('connected-alloop-ring-card'),
        color: VvewellColors.softTeal,
        onTap: () => _openConnectedRing(autoStart: false),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const _RingArtwork(size: 72),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      VvewellStatusPill(
                        label: '已连接'.tr,
                        color: VvewellColors.success,
                        icon: Icons.bluetooth_connected,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'SDK 数据服务已就绪 · 点击查看完整设备页'.tr,
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
            const SizedBox(height: 14),
            Text(
              device.id,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: VvewellColors.muted, fontSize: 12),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          key: const Key('device-center-one-tap-measurement'),
          onPressed: () => _openConnectedRing(autoStart: true),
          icon: const Icon(Icons.play_circle_outline),
          label: Text('一键检测'.tr),
        ),
      ),
      const SizedBox(height: 10),
      Text(
        '将自动检测血氧与心率，采集 PPG/运动波形，并同步戒指历史体温。'.tr,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: VvewellColors.muted,
          fontSize: 12,
          height: 1.4,
        ),
      ),
      const SizedBox(height: 14),
    ];
  }

  Widget _connectedHardwareCard(SmartRingDevice device) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: VvewellCard(
      key: Key('connected-${device.type.name}-${device.id}'),
      color: VvewellColors.softMint,
      onTap: () => _openConnectedHardware(device),
      child: Row(
        children: [
          _ConnectedHardwareIcon(type: device.type),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                VvewellStatusPill(
                  label: '已连接'.tr,
                  color: VvewellColors.success,
                  icon: Icons.bluetooth_connected,
                ),
                const SizedBox(height: 8),
                Text(
                  device.name.isEmpty
                      ? device.type.displayName.tr
                      : device.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${device.type.displayName.tr} · ${device.id}',
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

  void _openConnectedHardware(SmartRingDevice device) {
    final route = switch (device.type) {
      SmartRingType.alloop => AlRoutes.deviceDetail,
      SmartRingType.aizoring => AlRoutes.aizoringDeviceDetail,
      SmartRingType.xiaozhi => AlRoutes.xiaozhiDeviceDetail,
      SmartRingType.radar => AlRoutes.radarDeviceDetail,
      SmartRingType.robot => AlRoutes.robotDeviceDetail,
      SmartRingType.glasses => AlRoutes.rokidGlasses,
    };
    Get.toNamed(route, arguments: {'device': device});
  }

  List<Widget> _disconnectedDevicesContent({bool addingAnother = false}) => [
    VvewellCard(
      key: Key(
        addingAnother ? 'add-another-device-card' : 'connect-first-device-card',
      ),
      color: VvewellColors.softTeal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _RingArtwork(size: 72),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (addingAnother ? '连接其他设备' : '连接你的健康设备').tr,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      addingAnother
                          ? '当前设备保持连接，可继续添加戒指、健康小助手或毫米波雷达。'.tr
                          : '一次扫描即可发现 Alloop、AIZORING、健康小助手和 JDY-23。'.tr,
                      style: const TextStyle(
                        color: VvewellColors.muted,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 9),
                    VvewellStatusPill(label: '蓝牙扫描已就绪'.tr),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              key: const Key('scan-and-add-device'),
              onPressed: _openScanner,
              icon: const Icon(Icons.bluetooth_searching),
              label: Text(addingAnother ? '扫描并添加设备'.tr : '开始扫描与连接'.tr),
            ),
          ),
        ],
      ),
    ),
    const SizedBox(height: 18),
    VvewellCard(
      color: VvewellColors.softOrange,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.thermostat_outlined,
                size: 46,
                color: VvewellColors.primaryDark,
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "USB thermal camera",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "Read thermal images directly over USB, without Bluetooth or a network login.",
                      style: TextStyle(color: VvewellColors.muted, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _openThermalCamera,
              icon: const Icon(Icons.videocam_outlined),
              label: const Text("Read camera"),
            ),
          ),
        ],
      ),
    ),
    const SizedBox(height: 18),
    VvewellSectionTitle('支持的设备'.tr),
    const SizedBox(height: 12),
    _SupportedDevice(
      icon: Icons.ring_volume_outlined,
      title: 'Alloop 智能戒指',
      subtitle: '血氧验证与历史数据同步',
      color: VvewellColors.softBlue,
      onTap: _openScanner,
    ),
    const SizedBox(height: 10),
    _SupportedDevice(
      icon: Icons.diamond_outlined,
      title: 'AIZORING',
      subtitle: '心率、血氧、体温、压力与睡眠',
      color: VvewellColors.softTeal,
      onTap: _openScanner,
    ),
    const SizedBox(height: 10),
    _SupportedDevice(
      icon: Icons.smart_toy_outlined,
      title: '健康小助手',
      subtitle: '设备控制、Wi-Fi 配网与 MCP 工具',
      color: VvewellColors.softViolet,
      onTap: _openScanner,
    ),
    const SizedBox(height: 10),
    _SupportedDevice(
      icon: Icons.smart_toy_outlined,
      title: 'vvewell Robot',
      subtitle: "Expression display and SG90 servo control",
      color: VvewellColors.softViolet,
      onTap: _openScanner,
    ),
    const SizedBox(height: 10),
    _SupportedDevice(
      icon: Icons.radar,
      title: 'JDY-23 毫米波雷达',
      subtitle: '点云与生命体征工程数据',
      color: VvewellColors.softOrange,
      onTap: _openScanner,
    ),
    const SizedBox(height: 10),
    _SupportedDevice(
      icon: Icons.visibility_outlined,
      title: "Rokid AI glasses",
      subtitle: "Companion app authorization, CXRLink status and device information",
      color: VvewellColors.softBlue,
      onTap: _openGlasses,
    ),
  ];

  List<Widget> _hardwareContent() {
    final products = <_HardwareProduct>[
      const _HardwareProduct(
        title: 'Alloop Ring',
        subtitle: '血氧、心率与体温趋势',
        price: '¥1,299',
        badge: '推荐',
        icon: Icons.ring_volume_outlined,
        color: VvewellColors.softBlue,
      ),
      const _HardwareProduct(
        title: '健康小助手',
        subtitle: '语音交互与家庭健康提醒',
        price: '¥699',
        badge: '智能家居',
        icon: Icons.smart_toy_outlined,
        color: VvewellColors.softViolet,
      ),
      const _HardwareProduct(
        title: '红外健康检测仪',
        subtitle: '非接触体温与环境温度检测',
        price: '¥399',
        badge: '新品',
        icon: Icons.device_thermostat_outlined,
        color: VvewellColors.softOrange,
      ),
      const _HardwareProduct(
        title: '毫米波雷达',
        subtitle: '睡眠、呼吸与离床感知',
        price: '¥899',
        badge: '免佩戴',
        icon: Icons.radar,
        color: VvewellColors.softTeal,
      ),
    ];
    return [
      Row(
        children: [
          Expanded(
            child: Text(
              '硬件购买'.tr,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton.filledTonal(
            tooltip: '购物车'.tr,
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '购物车内有 @count 件商品'.trParams({'count': '$_cartCount'}),
                ),
              ),
            ),
            icon: Badge(
              isLabelVisible: _cartCount > 0,
              label: Text('$_cartCount'),
              child: const Icon(Icons.shopping_cart_outlined),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: products.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisExtent: 310,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemBuilder: (context, index) => _ProductCard(
          product: products[index],
          onAdd: () => setState(() => _cartCount++),
          onBuy: () => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '@item 已进入结算流程'.trParams({'item': products[index].title.tr}),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 18),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _openScanner,
          icon: const Icon(Icons.bluetooth_searching),
          label: Text('扫描已支持的设备'.tr),
        ),
      ),
    ];
  }
}

class _ConnectedHardwareIcon extends StatelessWidget {
  const _ConnectedHardwareIcon({required this.type});

  final SmartRingType type;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (type) {
      SmartRingType.alloop => (
        Icons.ring_volume_outlined,
        VvewellColors.softBlue,
      ),
      SmartRingType.aizoring => (
        Icons.diamond_outlined,
        VvewellColors.softTeal,
      ),
      SmartRingType.xiaozhi => (
        Icons.smart_toy_outlined,
        VvewellColors.softViolet,
      ),
      SmartRingType.radar => (Icons.radar, VvewellColors.softOrange),
      SmartRingType.robot => (Icons.smart_toy_outlined, VvewellColors.softViolet),
      SmartRingType.glasses => (Icons.visibility_outlined, VvewellColors.softBlue),
    };
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Icon(icon, color: VvewellColors.primaryDark),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Material(
      color: selected ? VvewellColors.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: selected ? VvewellColors.primaryDark : VvewellColors.muted,
            ),
          ),
        ),
      ),
    ),
  );
}

class _SupportedDevice extends StatelessWidget {
  const _SupportedDevice({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => VvewellCard(
    color: color,
    onTap: onTap,
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: VvewellColors.primaryDark),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.tr,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle.tr,
                style: const TextStyle(
                  color: VvewellColors.muted,
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right, color: VvewellColors.muted),
      ],
    ),
  );
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.onAdd,
    required this.onBuy,
  });
  final _HardwareProduct product;
  final VoidCallback onAdd;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) => VvewellCard(
    padding: const EdgeInsets.all(10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 96,
          width: double.infinity,
          decoration: BoxDecoration(
            color: product.color,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Stack(
            children: [
              Center(
                child: Icon(
                  product.icon,
                  size: 44,
                  color: VvewellColors.primaryDark,
                ),
              ),
              Positioned(
                top: 7,
                right: 7,
                child: VvewellStatusPill(label: product.badge.tr),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          product.title.tr,
          maxLines: 2,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 3),
        Text(
          product.subtitle.tr,
          maxLines: 3,
          style: const TextStyle(color: VvewellColors.muted, fontSize: 11),
        ),
        const Spacer(),
        Text(
          product.price,
          style: const TextStyle(
            color: VvewellColors.primary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton.outlined(
              tooltip: '加入购物车'.tr,
              onPressed: onAdd,
              icon: const Icon(Icons.add_shopping_cart, size: 18),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: FilledButton(
                onPressed: onBuy,
                child: Text(
                  '立即购买'.tr,
                  maxLines: 1,
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _HardwareProduct {
  const _HardwareProduct({
    required this.title,
    required this.subtitle,
    required this.price,
    required this.badge,
    required this.icon,
    required this.color,
  });
  final String title;
  final String subtitle;
  final String price;
  final String badge;
  final IconData icon;
  final Color color;
}

class _RingArtwork extends StatelessWidget {
  const _RingArtwork({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _RingPainter());
}

class _RingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * .27;
    canvas.drawCircle(
      center,
      radius * 1.55,
      Paint()..color = const Color(0xFFDCE9E7),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = VvewellColors.primaryDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * .42
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      3.6,
      1.25,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: .82)
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * .09
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
