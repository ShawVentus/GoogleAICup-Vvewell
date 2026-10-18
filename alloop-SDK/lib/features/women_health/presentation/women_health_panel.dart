import 'package:flutter/material.dart';

import '../../../foundations/ui/vvewell_theme.dart';
import '../data/women_health_repository.dart';

/// Adult-only, local-first cycle demo. It intentionally does not diagnose or measure hormones.
class WomenHealthPanel extends StatefulWidget {
  const WomenHealthPanel({super.key});
  @override State<WomenHealthPanel> createState() => _WomenHealthPanelState();
}

class _WomenHealthPanelState extends State<WomenHealthPanel> {
  final _repository = WomenHealthRepository();
  String _mode = '周期追踪';
  DateTime _lastPeriod = DateTime.now().subtract(const Duration(days: 12));
  List<Map<String, dynamic>> _records = const [];
  bool _hasDeviceTrend = false;

  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final records = await _repository.loadRecords();
    final hasDeviceTrend = await _repository.hasDeviceTrend();
    if (mounted) setState(() { _records = records; _hasDeviceTrend = hasDeviceTrend; });
  }
  Future<void> _recordPeriod() async {
    final date = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime.now(), initialDate: _lastPeriod);
    if (date == null) return;
    await _repository.savePeriod(start: date, flow: '中等', symptoms: '无', note: '');
    setState(() => _lastPeriod = date); await _load();
  }
  Future<void> _saveMode() async { await _repository.saveProfile(mode: _mode, anchorDate: _lastPeriod); await _load(); }
  int get _cycleDay => DateTime.now().difference(_lastPeriod).inDays + 1;
  String get _phase => _cycleDay <= 5 ? '月经期' : _cycleDay <= 13 ? '卵泡期' : _cycleDay <= 15 ? '排卵期' : '黄体期';

  @override Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const _DemoNotice('仅面向成年用户 · 本地保存 · 阶段为记录估计，非激素检测或诊断'),
    const SizedBox(height: 12),
    SegmentedButton<String>(segments: const [ButtonSegment(value: '周期追踪', label: Text('周期')), ButtonSegment(value: '备孕支持', label: Text('备孕')), ButtonSegment(value: '孕期管理', label: Text('孕期'))], selected: {_mode}, onSelectionChanged: (v) => setState(() => _mode = v.first)),
    const SizedBox(height: 14),
    _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('当前：$_phase · 第 $_cycleDay 天', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
      const SizedBox(height: 8), const Text('雌激素与孕激素曲线为教育性示意，不代表任何化验数值。', style: TextStyle(fontSize: 12, color: VvewellColors.muted)),
      const SizedBox(height: 10), const _HormoneCurve(),
      const SizedBox(height: 8), Text(_hasDeviceTrend ? '设备趋势：已有本地生理记录，仅供趋势参考。' : '设备趋势：暂无可用体温/睡眠/HRV 数据', style: const TextStyle(fontSize: 12, color: VvewellColors.muted)),
    ])),
    const SizedBox(height: 12),
    if (_mode == '周期追踪') _periodCard() else if (_mode == '备孕支持') _fertilityCard() else _pregnancyCard(),
    const SizedBox(height: 10), Text('本机已记录 ${_records.where((r) => r['record_type'] == 'period').length} 次经期；可在“我的”中清除本地健康数据。', style: const TextStyle(fontSize: 11, color: VvewellColors.muted)),
  ]);

  Widget _periodCard() => _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('经期记录', style: TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 7),
    Text('上次开始：${_lastPeriod.year}-${_lastPeriod.month.toString().padLeft(2, '0')}-${_lastPeriod.day.toString().padLeft(2, '0')} · 预测下次：${_lastPeriod.add(const Duration(days: 28)).month} 月 ${_lastPeriod.add(const Duration(days: 28)).day} 日'),
    const SizedBox(height: 10), FilledButton.icon(onPressed: _recordPeriod, icon: const Icon(Icons.add), label: const Text('记录经期开始')),
  ]));
  Widget _fertilityCard() => _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('备孕支持', style: TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 7),
    Text('可能受孕窗口：第 11–16 天（当前第 $_cycleDay 天）'), const SizedBox(height: 6),
    const Text('仅由周期记录估计，不能用于避孕、保证受孕或判断排卵。', style: TextStyle(fontSize: 12, color: VvewellColors.muted)), const SizedBox(height: 8),
    OutlinedButton(onPressed: _saveMode, child: const Text('保存备孕模式')),
  ]));
  Widget _pregnancyCard() => _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('孕期管理', style: TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 7),
    Text('按末次月经估计：${DateTime.now().difference(_lastPeriod).inDays ~/ 7 + 1} 周'), const SizedBox(height: 6),
    const Text('可记录产检与感受；如出现异常或担忧，请及时联系医疗专业人员。', style: TextStyle(fontSize: 12, color: VvewellColors.muted)), const SizedBox(height: 8),
    OutlinedButton(onPressed: _saveMode, child: const Text('保存孕期模式')),
  ]));
}

class _HormoneCurve extends StatelessWidget { const _HormoneCurve(); @override Widget build(BuildContext context) => SizedBox(height: 54, child: CustomPaint(size: Size.infinite, painter: _CurvePainter())); }
class _CurvePainter extends CustomPainter { @override void paint(Canvas c, Size s) { final p = Paint()..style=PaintingStyle.stroke..strokeWidth=2.5..color=VvewellColors.primary; final q = Paint()..style=PaintingStyle.stroke..strokeWidth=2.5..color=Colors.pink; final a = Path()..moveTo(0,s.height*.75)..quadraticBezierTo(s.width*.32,s.height*.05,s.width*.53,s.height*.52)..quadraticBezierTo(s.width*.76,s.height*.9,s.width,s.height*.65); final b = Path()..moveTo(0,s.height*.88)..quadraticBezierTo(s.width*.55,s.height*.9,s.width*.68,s.height*.22)..quadraticBezierTo(s.width*.87,s.height*.12,s.width,s.height*.8); c.drawPath(a,p); c.drawPath(b,q); } @override bool shouldRepaint(_) => false; }
class _Card extends StatelessWidget { const _Card({required this.child}); final Widget child; @override Widget build(BuildContext context) => Container(width: double.infinity,padding: const EdgeInsets.all(13),decoration: BoxDecoration(color: VvewellColors.softTeal,borderRadius: BorderRadius.circular(13)),child: child); }
class _DemoNotice extends StatelessWidget { const _DemoNotice(this.text); final String text; @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(9),decoration: BoxDecoration(color: const Color(0xFFFFF3D8),borderRadius: BorderRadius.circular(10)),child: Text(text,style: const TextStyle(fontSize: 11))); }
