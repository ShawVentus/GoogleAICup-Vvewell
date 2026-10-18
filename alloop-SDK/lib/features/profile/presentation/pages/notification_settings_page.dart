import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../foundations/ui/vvewell_theme.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  bool allEnabled = true;
  bool health = true;
  bool device = true;
  bool family = true;
  bool orders = true;
  bool community = false;
  bool quietHours = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('通知设置'.tr)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          _SettingsGroup(
            title: '通知总开关'.tr,
            children: [
              _NotificationSwitch(
                icon: Icons.notifications_active_outlined,
                title: '通知总开关'.tr,
                subtitle: '控制所有推送、提醒与服务进度通知'.tr,
                value: allEnabled,
                onChanged: (value) => setState(() => allEnabled = value),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Opacity(
            opacity: allEnabled ? 1 : .48,
            child: IgnorePointer(
              ignoring: !allEnabled,
              child: _SettingsGroup(
                title: '通知类型'.tr,
                children: [
                  _NotificationSwitch(
                    icon: Icons.monitor_heart_outlined,
                    title: '健康提醒'.tr,
                    subtitle: '异常趋势、用药和复查提醒'.tr,
                    value: health,
                    onChanged: (value) => setState(() => health = value),
                  ),
                  _NotificationSwitch(
                    icon: Icons.watch_outlined,
                    title: '设备与测量'.tr,
                    subtitle: '电量、佩戴、同步和检测结果'.tr,
                    value: device,
                    onChanged: (value) => setState(() => device = value),
                  ),
                  _NotificationSwitch(
                    icon: Icons.family_restroom_outlined,
                    title: '家庭成员动态'.tr,
                    subtitle: '共享成员的授权健康动态'.tr,
                    value: family,
                    onChanged: (value) => setState(() => family = value),
                  ),
                  _NotificationSwitch(
                    icon: Icons.receipt_long_outlined,
                    title: '订单与服务'.tr,
                    subtitle: '物流、预约与保险服务进度'.tr,
                    value: orders,
                    onChanged: (value) => setState(() => orders = value),
                  ),
                  _NotificationSwitch(
                    icon: Icons.forum_outlined,
                    title: '社区互动'.tr,
                    subtitle: '回复、关注和社区活动'.tr,
                    value: community,
                    onChanged: (value) => setState(() => community = value),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _SettingsGroup(
            title: '免打扰'.tr,
            children: [
              _NotificationSwitch(
                icon: Icons.bedtime_outlined,
                title: '免打扰时段'.tr,
                subtitle: '22:30 - 07:30 · 紧急健康提醒仍可送达'.tr,
                value: quietHours,
                onChanged: (value) => setState(() => quietHours = value),
              ),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                leading: const Icon(
                  Icons.schedule,
                  color: VvewellColors.primary,
                ),
                title: Text('设置时间'.tr, style: const TextStyle(fontSize: 13)),
                trailing: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('22:30 - 07:30', style: TextStyle(fontSize: 12)),
                    SizedBox(width: 4),
                    Icon(Icons.chevron_right, color: VvewellColors.muted),
                  ],
                ),
                onTap: () => ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('免打扰时间已保存'.tr))),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Material(
    color: VvewellColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: const BorderSide(color: VvewellColors.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 7),
          child: Text(
            title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
        ...List.generate(
          children.length,
          (index) => Column(
            children: [
              if (index > 0) const Divider(height: 1, indent: 52),
              children[index],
            ],
          ),
        ),
      ],
    ),
  );
}

class _NotificationSwitch extends StatelessWidget {
  const _NotificationSwitch({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
    secondary: Icon(icon, color: VvewellColors.primary),
    title: Text(title, style: const TextStyle(fontSize: 13)),
    subtitle: Text(
      subtitle,
      style: const TextStyle(color: VvewellColors.muted, fontSize: 11),
    ),
    value: value,
    onChanged: onChanged,
  );
}
