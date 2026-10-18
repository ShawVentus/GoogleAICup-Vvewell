import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../foundations/ui/vvewell_theme.dart';
import '../../domain/family_member.dart';
import '../controllers/family_profile_controller.dart';
import 'health_record_page.dart';

Future<void> showFamilyMemberSwitcher(
  BuildContext context,
  FamilyProfileController controller,
) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '切换健康档案'.tr,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                '送诊、保险与健康建议将使用所选成员的独立档案。'.tr,
                style: const TextStyle(color: VvewellColors.muted),
              ),
              const SizedBox(height: 16),
              ...controller.members.map(
                (member) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _MemberChoice(
                    member: member,
                    selected: controller.activeMember.id == member.id,
                    onTap: () {
                      controller.selectMember(member.id);
                      Navigator.pop(sheetContext);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            FamilyMembersPage(controller: controller),
                      ),
                    );
                  },
                  icon: const Icon(Icons.manage_accounts_outlined),
                  label: Text('管理家庭成员'.tr),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class FamilyMembersPage extends StatelessWidget {
  const FamilyMembersPage({super.key, required this.controller});

  final FamilyProfileController controller;

  Future<void> _addMember(BuildContext context) async {
    final member = await showModalBottomSheet<FamilyMember>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AddMemberSheet(controller: controller),
    );
    if (member == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已添加 @name，并切换至该健康档案'.trParams({'name': member.name})),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('家庭成员'.tr)),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final active = controller.activeMember;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _ActiveMemberCard(member: active),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '全部成员'.tr,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '@count 人'.trParams({
                      'count': '${controller.members.length}',
                    }),
                    style: const TextStyle(color: VvewellColors.muted),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...controller.members.map(
                (member) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _MemberListCard(
                    member: member,
                    selected: active.id == member.id,
                    onSelect: () => controller.selectMember(member.id),
                    onRecord: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            HealthRecordPage(controller: controller),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: const Key('add-family-member'),
                  onPressed: () => _addMember(context),
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  label: Text('添加成员'.tr),
                ),
              ),
              const SizedBox(height: 20),
              const _PermissionNotice(),
            ],
          );
        },
      ),
    );
  }
}

class _MemberChoice extends StatelessWidget {
  const _MemberChoice({
    required this.member,
    required this.selected,
    required this.onTap,
  });

  final FamilyMember member;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? VvewellColors.softTeal : VvewellColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? VvewellColors.primary : VvewellColors.border,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        minTileHeight: 56,
        leading: const CircleAvatar(
          backgroundColor: VvewellColors.softTeal,
          child: Icon(Icons.person_outline, color: VvewellColors.primary),
        ),
        title: Text(
          member.name.tr,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(member.relationship.tr),
        trailing: selected
            ? const Icon(Icons.check_circle, color: VvewellColors.primary)
            : const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _ActiveMemberCard extends StatelessWidget {
  const _ActiveMemberCard({required this.member});

  final FamilyMember member;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: VvewellColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: VvewellColors.primary, width: 1.5),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 32,
            backgroundColor: VvewellColors.softTeal,
            child: Icon(
              Icons.person_outline,
              size: 34,
              color: VvewellColors.primary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      member.name.tr,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    _Label(text: member.relationship),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.circle,
                      size: 9,
                      color: VvewellColors.success,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '当前查看'.tr,
                        style: const TextStyle(color: VvewellColors.muted),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _Label(text: '当前'.tr, filled: true),
        ],
      ),
    );
  }
}

class _MemberListCard extends StatelessWidget {
  const _MemberListCard({
    required this.member,
    required this.selected,
    required this.onSelect,
    required this.onRecord,
  });

  final FamilyMember member;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onRecord;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: VvewellColors.softBlue,
              child: Icon(Icons.person_outline, color: VvewellColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.name.tr,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '@relationship · @gender · @year 年'.trParams({
                      'relationship': member.relationship.tr,
                      'gender': member.gender.tr,
                      'year': '${member.birthYear}',
                    }),
                    style: const TextStyle(
                      color: VvewellColors.muted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton(onPressed: onRecord, child: Text('查看健康档案'.tr)),
                      if (!selected)
                        TextButton(
                          key: Key('switch-member-${member.id}'),
                          onPressed: onSelect,
                          child: Text('切换'.tr),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: VvewellColors.primary),
          ],
        ),
      ),
    );
  }
}

class _PermissionNotice extends StatelessWidget {
  const _PermissionNotice();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: VvewellColors.softTeal,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.shield_outlined, color: VvewellColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '权限说明'.tr,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '每位成员拥有独立的健康、送诊、保险和社区档案。成年成员的数据仅在其明确授权范围内共享，授权可随时撤回。'.tr,
                    style: const TextStyle(
                      color: VvewellColors.muted,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddMemberSheet extends StatefulWidget {
  const _AddMemberSheet({required this.controller});

  final FamilyProfileController controller;

  @override
  State<_AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends State<_AddMemberSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _birthYearController = TextEditingController();
  String _relationship = '配偶';
  String _gender = '女';
  bool _authorized = false;

  @override
  void dispose() {
    _nameController.dispose();
    _birthYearController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate() || !_authorized) {
      setState(() {});
      return;
    }
    final member = widget.controller.addMember(
      name: _nameController.text,
      relationship: _relationship,
      gender: _gender,
      birthYear: int.parse(_birthYearController.text),
    );
    Navigator.pop(context, member);
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, keyboard + 16),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '添加家庭成员'.tr,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('family-member-name'),
                controller: _nameController,
                decoration: InputDecoration(labelText: '成员姓名 *'.tr),
                textInputAction: TextInputAction.next,
                validator: (value) =>
                    value == null || value.trim().isEmpty ? '请输入成员姓名'.tr : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _relationship,
                isExpanded: true,
                decoration: InputDecoration(labelText: '与我的关系 *'.tr),
                items: const ['配偶', '子女', '父母', '其他被扶养人']
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value.tr)),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _relationship = value!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _gender,
                isExpanded: true,
                decoration: InputDecoration(labelText: '性别 *'.tr),
                items: const ['女', '男', '其他/不便说明']
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value.tr)),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _gender = value!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('family-member-birth-year'),
                controller: _birthYearController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: '出生年份 *'.tr,
                  helperText: '用于年龄相关的服务适配，不会自动用于保险定价。'.tr,
                ),
                validator: (value) {
                  final year = int.tryParse(value ?? '');
                  if (year == null ||
                      year < 1900 ||
                      year > DateTime.now().year) {
                    return '请输入有效的出生年份'.tr;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: _authorized,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text('我已获得该成员授权，或拥有合法代理权限'.tr),
                subtitle: !_authorized && _formKey.currentState != null
                    ? Text(
                        '添加前需要确认授权'.tr,
                        style: const TextStyle(color: VvewellColors.error),
                      )
                    : null,
                onChanged: (value) => setState(() => _authorized = value!),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  key: const Key('submit-family-member'),
                  onPressed: _submit,
                  child: Text('保存并切换'.tr),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({required this.text, this.filled = false});

  final String text;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? VvewellColors.primary : VvewellColors.softTeal,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text.tr,
        style: TextStyle(
          color: filled ? Colors.white : VvewellColors.primaryDark,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
