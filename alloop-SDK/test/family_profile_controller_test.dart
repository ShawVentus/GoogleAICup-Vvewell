import 'package:alloop/features/family/presentation/controllers/family_profile_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('adding a family member selects an independent health profile', () {
    final controller = FamilyProfileController();
    addTearDown(controller.dispose);

    expect(controller.activeMember.name, '王国良');
    expect(controller.members, hasLength(1));

    final member = controller.addMember(
      name: '李敏',
      relationship: '配偶',
      gender: '女',
      birthYear: 1990,
    );

    expect(controller.members, hasLength(2));
    expect(controller.activeMember.id, member.id);
    expect(controller.activeMember.tags, hasLength(1));

    controller.selectMember('member-self');
    expect(controller.activeMember.name, '王国良');
    expect(controller.activeMember.tags.length, greaterThan(1));
  });

  test('predicted tag can be confirmed or removed from personalization', () {
    final controller = FamilyProfileController();
    addTearDown(controller.dispose);
    final riskTag = controller.activeMember.tags.firstWhere(
      (tag) => tag.id == 'tag-sleep-risk',
    );

    controller.setTagHidden(riskTag.id, hidden: true);
    expect(
      controller.activeMember.tags
          .firstWhere((tag) => tag.id == riskTag.id)
          .hiddenFromPersonalization,
      isTrue,
    );

    controller.confirmTag(riskTag.id);
    expect(
      controller.activeMember.tags
          .firstWhere((tag) => tag.id == riskTag.id)
          .status
          .name,
      'confirmed',
    );
  });
}
