import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../foundations/ui/vvewell_theme.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  int _filter = 0;

  static const _orders = <_MockOrder>[
    _MockOrder(
      id: 'VV202608040018',
      title: 'Alloop Ring 健康套装',
      subtitle: '月光银 · 尺寸 9',
      amount: '¥1,299',
      status: '待付款',
      icon: Icons.ring_volume_outlined,
      color: VvewellColors.softBlue,
    ),
    _MockOrder(
      id: 'VV202608020076',
      title: '跨境医疗专家会诊',
      subtitle: '心血管内科 · 资料复核中',
      amount: '¥3,500',
      status: '进行中',
      icon: Icons.medical_services_outlined,
      color: VvewellColors.softTeal,
    ),
    _MockOrder(
      id: 'VV202607280143',
      title: '家庭营养深度评估',
      subtitle: 'Athena 沐瑶 · 已生成报告',
      amount: '¥299',
      status: '已完成',
      icon: Icons.restaurant_outlined,
      color: VvewellColors.softOrange,
    ),
    _MockOrder(
      id: 'VV202607190052',
      title: '红外健康检测仪',
      subtitle: '标准版 · 已签收',
      amount: '¥399',
      status: '已完成',
      icon: Icons.device_thermostat_outlined,
      color: VvewellColors.softViolet,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final labels = ['全部'.tr, '待付款'.tr, '进行中'.tr, '已完成'.tr];
    final orders = _filter == 0
        ? _orders
        : _orders.where((order) => order.status.tr == labels[_filter]).toList();
    return Scaffold(
      appBar: AppBar(title: Text('我的订单'.tr)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          SegmentedButton<int>(
            segments: [
              for (var index = 0; index < labels.length; index++)
                ButtonSegment(value: index, label: Text(labels[index])),
            ],
            selected: {_filter},
            onSelectionChanged: (value) =>
                setState(() => _filter = value.first),
            showSelectedIcon: false,
          ),
          const SizedBox(height: 16),
          for (final order in orders) ...[
            _OrderCard(order: order),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final _MockOrder order;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (order.status) {
      '待付款' => VvewellColors.warning,
      '进行中' => VvewellColors.primary,
      _ => VvewellColors.success,
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VvewellColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: VvewellColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order.id,
                  style: const TextStyle(
                    color: VvewellColors.muted,
                    fontSize: 11,
                  ),
                ),
              ),
              Text(
                order.status.tr,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const Divider(height: 22),
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: order.color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(order.icon, color: VvewellColors.primaryDark),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.title.tr,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      order.subtitle.tr,
                      style: const TextStyle(
                        color: VvewellColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                order.amount,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: () => ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('订单详情已加载'.tr))),
                child: Text('查看详情'.tr),
              ),
              FilledButton(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      (order.status == '待付款' ? '支付流程已打开' : '服务进度已更新').tr,
                    ),
                  ),
                ),
                child: Text((order.status == '待付款' ? '去付款' : '查看进度').tr),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MockOrder {
  const _MockOrder({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.status,
    required this.icon,
    required this.color,
  });

  final String id;
  final String title;
  final String subtitle;
  final String amount;
  final String status;
  final IconData icon;
  final Color color;
}
