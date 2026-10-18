import 'package:flutter/foundation.dart';

import '../../domain/family_member.dart';

class FamilyProfileController extends ChangeNotifier {
  FamilyProfileController({List<FamilyMember>? initialMembers})
    : _members = List<FamilyMember>.from(
        initialMembers ?? <FamilyMember>[_defaultMember],
      ),
      _activeMemberId = (initialMembers?.isNotEmpty ?? false)
          ? initialMembers!.first.id
          : _defaultMember.id;

  static final FamilyMember _defaultMember = FamilyMember(
    id: 'member-self',
    name: '王国良',
    relationship: '本人',
    gender: '男',
    birthYear: 1988,
    healthScore: 86,
    yesterdayHealthScore: 83,
    isSelf: true,
    tags: <FamilyHealthTag>[
      FamilyHealthTag(
        id: 'tag-blood-pressure',
        category: '已确认健康事实',
        label: '血压趋势',
        value: '近 7 天稳定',
        status: HealthTagStatus.confirmed,
        source: '智能设备与本人确认',
        updatedAt: DateTime(2026, 8, 3),
        purpose: '健康管理、送诊服务',
      ),
      FamilyHealthTag(
        id: 'tag-sleep-risk',
        category: '预测风险',
        label: '睡眠呼吸风险',
        value: '中等风险',
        status: HealthTagStatus.predicted,
        source: '多夜睡眠趋势模型 v1.2',
        updatedAt: DateTime(2026, 8, 2),
        purpose: '健康提醒，不用于诊断或保险定价',
        confidence: .78,
      ),
      FamilyHealthTag(
        id: 'tag-follow-up',
        category: '照护与送诊',
        label: '年度心血管复查',
        value: '建议 30 天内完成',
        status: HealthTagStatus.inferred,
        source: '健康档案规则集 2026.07',
        updatedAt: DateTime(2026, 8, 1),
        purpose: '送诊与复诊提醒',
      ),
      FamilyHealthTag(
        id: 'tag-coverage',
        category: '保障需求',
        label: '门诊保障',
        value: '存在 ¥150,000 缺口',
        status: HealthTagStatus.confirmed,
        source: '保单导入与家庭预算问卷',
        updatedAt: DateTime(2026, 7, 28),
        purpose: '保险适当性与保障规划',
      ),
    ],
  );

  final List<FamilyMember> _members;
  String _activeMemberId;

  List<FamilyMember> get members => List<FamilyMember>.unmodifiable(_members);

  FamilyMember get activeMember => _members.firstWhere(
    (member) => member.id == _activeMemberId,
    orElse: () => _members.first,
  );

  bool selectMember(String memberId) {
    if (_activeMemberId == memberId ||
        !_members.any((member) => member.id == memberId)) {
      return false;
    }
    _activeMemberId = memberId;
    notifyListeners();
    return true;
  }

  FamilyMember addMember({
    required String name,
    required String relationship,
    required String gender,
    required int birthYear,
  }) {
    final member = FamilyMember(
      id: 'member-${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim(),
      relationship: relationship,
      gender: gender,
      birthYear: birthYear,
      healthScore: 0,
      tags: <FamilyHealthTag>[
        FamilyHealthTag(
          id: 'profile-${DateTime.now().microsecondsSinceEpoch}',
          category: '身份与人口学',
          label: '基础档案',
          value: '$relationship · $gender · Born $birthYear',
          status: HealthTagStatus.confirmed,
          source: '家庭管理员录入',
          updatedAt: DateTime.now(),
          purpose: '家庭健康服务适配',
        ),
      ],
    );
    _members.add(member);
    _activeMemberId = member.id;
    notifyListeners();
    return member;
  }

  void confirmTag(String tagId) {
    _replaceTag(
      tagId,
      (tag) => tag.copyWith(status: HealthTagStatus.confirmed),
    );
  }

  void setTagHidden(String tagId, {required bool hidden}) {
    _replaceTag(
      tagId,
      (tag) => tag.copyWith(hiddenFromPersonalization: hidden),
    );
  }

  void _replaceTag(
    String tagId,
    FamilyHealthTag Function(FamilyHealthTag tag) update,
  ) {
    final memberIndex = _members.indexWhere(
      (member) => member.id == _activeMemberId,
    );
    if (memberIndex < 0) return;
    final member = _members[memberIndex];
    final tagIndex = member.tags.indexWhere((tag) => tag.id == tagId);
    if (tagIndex < 0) return;
    final tags = List<FamilyHealthTag>.from(member.tags);
    tags[tagIndex] = update(tags[tagIndex]);
    _members[memberIndex] = member.copyWith(tags: tags);
    notifyListeners();
  }
}
