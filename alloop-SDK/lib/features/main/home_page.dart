import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'chat_composer.dart';

import '../avatar_coach/domain/models/avatar_coach_view_model.dart';
import '../avatar_coach/presentation/controllers/avatar_coach_controller.dart';
import '../avatar_coach/presentation/widgets/basic_health_summary.dart';
import '../avatar_coach/presentation/widgets/coach_bubble_widget.dart';
import '../avatar_coach/presentation/widgets/panda_avatar_widget.dart';
import '../avatar_coach/presentation/widgets/severity_style.dart';
import '../avatar_coach/presentation/widgets/system_status_row.dart';
import '../../foundations/localization/app_localization.dart';
import '../../foundations/navigation/al_routes.dart';
import '../../foundations/ui/vvewell_theme.dart';
import '../cloud_sync/presentation/widgets/cloud_sync_button.dart';
import '../doctor_recommendation/main.dart' as doctor;
import '../family/presentation/controllers/family_profile_controller.dart';
import '../family/presentation/pages/family_members_page.dart';
import '../family/presentation/pages/health_record_page.dart';
import '../health_reports/data/medical_ocr_service.dart';
import '../health_reports/data/medical_report_store.dart';
import '../health_reports/presentation/medical_report_upload_sheet.dart';
import '../health_score/presentation/health_score_card.dart';
import '../medical/presentation/medical_hub_page.dart';
import '../nutrition_demo/presentation/nutrition_center_page.dart';
import '../nutrition_demo/presentation/nutrition_capture_sheet.dart';
import '../nutrition_demo/presentation/nutrition_demo_controller.dart';
import '../recommendations/presentation/recommendation_section.dart';
import '../women_health/presentation/women_health_panel.dart';

/// The five-tab vvewell application shell.
///
/// Bluetooth scanning, permissions, and the four-device connection flows stay
/// in [DeviceCenterPage] and the existing routes. This file only composes UI.
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    this.avatarCoachController,
    this.familyProfileController,
    this.nutritionDemoController,
    this.medicalReportStore,
    this.initialTabIndex = 0,
  });

  final int initialTabIndex;
  final AvatarCoachController? avatarCoachController;
  final FamilyProfileController? familyProfileController;
  final NutritionDemoController? nutritionDemoController;
  final MedicalReportStore? medicalReportStore;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late int _selectedIndex = widget.initialTabIndex;
  final _chatKey = GlobalKey<_ChatTabState>();
  late final AvatarCoachController _avatarCoachController =
      widget.avatarCoachController ??
      (Get.isRegistered<AvatarCoachController>()
          ? Get.find<AvatarCoachController>()
          : Get.put(AvatarCoachController()));
  late final FamilyProfileController _familyProfileController =
      widget.familyProfileController ?? FamilyProfileController();
  late final NutritionDemoController _nutritionDemoController =
      widget.nutritionDemoController ?? NutritionDemoController();
  late final MedicalReportStore _medicalReportStore =
      widget.medicalReportStore ?? MedicalReportStore();

  @override
  void initState() {
    super.initState();
    _nutritionDemoController.hydrate();
  }

  @override
  void dispose() {
    if (widget.nutritionDemoController == null) {
      _nutritionDemoController.dispose();
    }
    if (widget.medicalReportStore == null) {
      _medicalReportStore.dispose();
    }
    super.dispose();
  }

  void _openDoctor() {
    _chatKey.currentState?.selectDoctor();
    setState(() => _selectedIndex = 2);
  }

  void _openDevices() => Get.toNamed(AlRoutes.deviceCenter);
  void _openRppg() => Get.toNamed(AlRoutes.rppgMeasurement);
  void _openThermalCamera() => Get.toNamed(AlRoutes.thermalCamera);

  void _openHealthRecord() {
    Get.to<void>(() => HealthRecordPage(controller: _familyProfileController));
  }

  void _openNutrition() {
    Get.to<void>(
      () => NutritionCenterPage(
        controller: _nutritionDemoController,
        familyProfileController: _familyProfileController,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (Get.isRegistered<AppLanguageController>()) {
      final languageController = Get.find<AppLanguageController>();
      return Obx(() {
        languageController.currentLocale.value;
        return _buildShell();
      });
    }
    return _buildShell();
  }

  Widget _buildShell() {
    final pages = <Widget>[
      _HomeTab(
        controller: _avatarCoachController,
        familyProfileController: _familyProfileController,
        onOpenDevices: _openDevices,
        onOpenRppg: _openRppg,
        onOpenMedical: () => setState(() => _selectedIndex = 3),
        onOpenHealthRecord: _openHealthRecord,
        onOpenNutrition: _openNutrition,
        onOpenDoctor: _openDoctor,
        onOpenThermalCamera: _openThermalCamera,
      ),
      _HealthTab(
        familyProfileController: _familyProfileController,
        nutritionDemoController: _nutritionDemoController,
        medicalReportStore: _medicalReportStore,
      ),
      _ChatTab(
        key: _chatKey,
        familyProfileController: _familyProfileController,
        nutritionDemoController: _nutritionDemoController,
        medicalReportStore: _medicalReportStore,
      ),
      _MedicalTab(familyProfileController: _familyProfileController),
      _ProfileTab(
        onOpenDevices: _openDevices,
        familyProfileController: _familyProfileController,
      ),
    ];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: _selectedIndex, children: pages),
      ),
      bottomNavigationBar: _BottomNavigation(
        currentIndex: _selectedIndex,
        onSelected: (index) => setState(() => _selectedIndex = index),
      ),
    );
  }
}

class _BottomNavigation extends StatelessWidget {
  const _BottomNavigation({
    required this.currentIndex,
    required this.onSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final items = <_NavigationItem>[
      _NavigationItem('首页'.tr, Icons.home_outlined),
      _NavigationItem('健康'.tr, Icons.monitor_heart_outlined),
      _NavigationItem('对话'.tr, Icons.chat_bubble_outline),
      _NavigationItem('医疗'.tr, Icons.medical_services_outlined),
      _NavigationItem('我的'.tr, Icons.person_outline),
    ];
    return Material(
      color: VvewellColors.surface,
      child: SafeArea(
        top: false,
        child: Container(
          height: 70,
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: VvewellColors.border)),
          ),
          child: Row(
            children: List.generate(items.length, (index) {
              final item = items[index];
              final selected = currentIndex == index;
              return Expanded(
                child: InkWell(
                  key: Key('bottom-nav-$index'),
                  onTap: () => onSelected(index),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        item.icon,
                        size: 25,
                        color: selected
                            ? VvewellColors.primary
                            : VvewellColors.muted,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected
                              ? VvewellColors.primary
                              : VvewellColors.muted,
                          fontSize: 11,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavigationItem {
  const _NavigationItem(this.label, this.icon);

  final String label;
  final IconData icon;
}

class _VvewellHeader extends StatelessWidget {
  const _VvewellHeader({
    required this.familyProfileController,
    this.onCoachTap,
  });

  final FamilyProfileController familyProfileController;
  final VoidCallback? onCoachTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: const BoxDecoration(
        color: VvewellColors.background,
        border: Border(bottom: BorderSide(color: VvewellColors.border)),
      ),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: "Expand or collapse coach advice",
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                key: const Key('coach-toggle'),
                onTap: onCoachTap,
                borderRadius: BorderRadius.circular(14),
                child: const VvewellMark(size: 44),
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '晚上好'.tr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '欢迎回到 vvewell'.tr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: VvewellColors.muted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const CloudSyncButton(),
          const SizedBox(width: 2),
          if (!kIsWeb) ...[
            _HeaderButton(
              icon: Icons.language_outlined,
              label: Get.locale?.languageCode == 'en' ? 'EN' : '中',
              semanticLabel: Get.locale?.languageCode == 'en'
                  ? '切换到中文'.tr
                  : '切换到英文'.tr,
              onTap: Get.find<AppLanguageController>().toggle,
            ),
            const SizedBox(width: 2),
          ],
          _HeaderButton(
            icon: Icons.notifications_none_rounded,
            onTap: () => Get.toNamed(AlRoutes.notificationSettings),
          ),
          const SizedBox(width: 4),
          AnimatedBuilder(
            animation: familyProfileController,
            builder: (context, _) {
              final member = familyProfileController.activeMember;
              return Semantics(
                button: true,
                label: '当前健康档案 @name，点击切换家庭成员'.trParams({
                  'name': member.name.tr,
                }),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    key: const Key('header-family-switcher'),
                    onTap: () => showFamilyMemberSwitcher(
                      context,
                      familyProfileController,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const _ProfileAvatar(size: 28),
                            const SizedBox(width: 5),
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.sizeOf(context).width < 360
                                    ? 44
                                    : 80,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    member.name.tr,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    (member.isSelf
                                            ? '我自己'
                                            : member.relationship)
                                        .tr,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: VvewellColors.muted,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.keyboard_arrow_down,
                              color: VvewellColors.muted,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.icon,
    this.label,
    this.semanticLabel,
    required this.onTap,
  });

  final IconData icon;
  final String? label;
  final String? semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Tooltip(
        message: semanticLabel ?? '',
        child: SizedBox(
          width: label == null ? 38 : 46,
          height: 38,
          child: InkResponse(
            radius: 22,
            onTap: onTap,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: VvewellColors.foreground, size: 23),
                  if (label != null) ...[
                    const SizedBox(width: 1),
                    Text(
                      label!,
                      maxLines: 1,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: VvewellColors.softTeal,
        border: Border.all(color: VvewellColors.primary.withValues(alpha: .18)),
      ),
      child: Icon(
        Icons.person_outline_rounded,
        size: size * .58,
        color: VvewellColors.primary,
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({
    required this.controller,
    required this.familyProfileController,
    required this.onOpenDevices,
    required this.onOpenRppg,
    required this.onOpenMedical,
    required this.onOpenHealthRecord,
    required this.onOpenNutrition,
    required this.onOpenThermalCamera,
    required this.onOpenDoctor,
  });

  final AvatarCoachController controller;
  final FamilyProfileController familyProfileController;
  final VoidCallback onOpenDevices;
  final VoidCallback onOpenRppg;
  final VoidCallback onOpenMedical;
  final VoidCallback onOpenHealthRecord;
  final VoidCallback onOpenNutrition;
  final VoidCallback onOpenThermalCamera;
  final VoidCallback onOpenDoctor;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final viewModel = controller.viewModel.value;
      final showMainContent =
          viewModel.dataStatus == AvatarCoachDataStatus.ready ||
          viewModel.dataStatus == AvatarCoachDataStatus.fallback;
      return ListView(
        key: const Key('home-scroll-view'),
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          _VvewellHeader(
            familyProfileController: familyProfileController,
            onCoachTap: controller.toggleCoach,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: FilledButton.icon(
              onPressed: onOpenDoctor,
              icon: const Icon(Icons.person_search),
              label: const Text('Find a doctor'),
            ),
          ),
          if (viewModel.riskDisplay.visible)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _RiskDisplayBanner(
                risk: viewModel.riskDisplay,
                onNormalRetest: controller.submitNormalManualRetest,
              ),
            ),
          CoachBubbleWidget(
            severity: viewModel.coachSeverity,
            severityLabel: viewModel.coachSeverityLabel,
            message: viewModel.coachMessage,
            expanded:
                controller.isCoachExpanded.value &&
                viewModel.coachMessage.isNotEmpty,
            showActions:
                viewModel.dataStatus == AvatarCoachDataStatus.ready &&
                (viewModel.taskStatus == MockTaskStatus.offered ||
                    viewModel.taskStatus == MockTaskStatus.snoozed),
            completionEnabled: viewModel.avatarState != AvatarState.warning,
            onCompleted: controller.completeTask,
            onSnooze: controller.snoozeTask,
            onDecline: controller.declineTask,
          ),
          if (showMainContent) ...[
            if (viewModel.dataStatus == AvatarCoachDataStatus.fallback)
              _AvatarCoachStatusPanel(viewModel: viewModel),
            _DigitalTwinSection(viewModel: viewModel),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: _PageSectionTitle(title: 'Basic health overview'),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: BasicHealthSummary(metrics: viewModel.basicHealthMetrics),
            ),
          ] else
            _AvatarCoachStatusPanel(viewModel: viewModel),
          const SizedBox(height: 22),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _PageSectionTitle(title: '快捷入口'.tr),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: _QuickEntryGrid(
              onOpenDevices: onOpenDevices,
              onOpenRppg: onOpenRppg,
              onOpenMedical: onOpenMedical,
              onOpenHealthRecord: onOpenHealthRecord,
              onOpenNutrition: onOpenNutrition,
              onOpenThermalCamera: onOpenThermalCamera,
            ),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _ConnectedDeviceBanner(onTap: onOpenDevices),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _PageSectionTitle(title: '推荐阅读'.tr),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: AnimatedBuilder(
              animation: familyProfileController,
              builder: (context, _) => RecommendationSection(
                healthTags: familyProfileController.activeMember.tags,
              ),
            ),
          ),
        ],
      );
    });
  }
}

class _DigitalTwinSection extends StatelessWidget {
  const _DigitalTwinSection({required this.viewModel});

  final AvatarCoachViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final pandaSize = math.min(210.0, constraints.maxWidth * .58);
              final ringsSize = math.min(142.0, constraints.maxWidth * .41);
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 58,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: PandaAvatarWidget(
                        state: viewModel.avatarState,
                        variant: viewModel.avatarVariant,
                        animationState: viewModel.animationState,
                        size: pandaSize,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    flex: 42,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _AnimatedHealthOverview(
                          size: ringsSize,
                          indices: viewModel.healthIndices,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          _PageSectionTitle(title: '系统状态'.tr),
          const SizedBox(height: 7),
          SystemStatusRow(statuses: viewModel.systemStatuses),
        ],
      ),
    );
  }
}

class _RiskDisplayBanner extends StatelessWidget {
  const _RiskDisplayBanner({required this.risk, required this.onNormalRetest});

  final RiskDisplay risk;
  final VoidCallback onNormalRetest;

  @override
  Widget build(BuildContext context) {
    final color = AvatarSeverityStyle.color(risk.severity);
    return Semantics(
      container: true,
      liveRegion: true,
      label: '${risk.label.tr}, ${risk.message.tr}',
      child: Container(
        key: const Key('risk-display-priority'),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AvatarSeverityStyle.softColor(risk.severity),
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(AvatarSeverityStyle.icon(risk.severity), color: color),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    risk.label.tr,
                    style: TextStyle(color: color, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(risk.message.tr, style: const TextStyle(height: 1.4)),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const Key('mock-warning-normal-retest'),
                    onPressed: onNormalRetest,
                    icon: const Icon(Icons.fact_check_outlined, size: 17),
                    label: Text('Mock 人工复测正常'.tr),
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

class _AnimatedHealthOverview extends StatefulWidget {
  const _AnimatedHealthOverview({required this.size, required this.indices});

  final double size;
  final List<HealthIndex> indices;

  @override
  State<_AnimatedHealthOverview> createState() =>
      _AnimatedHealthOverviewState();
}

class _AnimatedHealthOverviewState extends State<_AnimatedHealthOverview> {
  late List<HealthIndex> _from = widget.indices;
  late List<HealthIndex> _to = widget.indices;
  int _revision = 0;
  bool _showDeltas = false;
  Timer? _deltaTimer;

  @override
  void didUpdateWidget(covariant _AnimatedHealthOverview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameIndices(_to, widget.indices)) {
      _from = _to;
      _to = widget.indices;
      _revision += 1;
      _showDeltas = _to.any((index) => index.delta != 0);
      _deltaTimer?.cancel();
      if (_showDeltas) {
        _deltaTimer = Timer(const Duration(milliseconds: 1400), () {
          if (mounted) setState(() => _showDeltas = false);
        });
      }
    }
  }

  @override
  void dispose() {
    _deltaTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(_revision),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 760),
      curve: Curves.easeOutCubic,
      builder: (context, progress, _) {
        final indices = _interpolateIndices(progress);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _HealthRings(
              score: indices.isEmpty ? 0 : indices.first.value,
              size: widget.size,
              indices: indices,
            ),
            const SizedBox(height: 8),
            _HealthRingLegend(indices: indices, showDeltas: _showDeltas),
          ],
        );
      },
    );
  }

  List<HealthIndex> _interpolateIndices(double progress) {
    if (_to.length != _from.length) return _to;
    return [
      for (var index = 0; index < _to.length; index++)
        HealthIndex(
          metric: _to[index].metric,
          label: _to[index].label,
          value:
              (_from[index].value +
                      ((_to[index].value - _from[index].value) * progress))
                  .round(),
          delta: _to[index].delta,
        ),
    ];
  }

  static bool _sameIndices(List<HealthIndex> a, List<HealthIndex> b) {
    if (a.length != b.length) return false;
    for (var index = 0; index < a.length; index++) {
      if (a[index].value != b[index].value ||
          a[index].delta != b[index].delta) {
        return false;
      }
    }
    return true;
  }
}

class _AvatarCoachStatusPanel extends StatelessWidget {
  const _AvatarCoachStatusPanel({required this.viewModel});

  final AvatarCoachViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final status = viewModel.dataStatus;
    final isLoading = status == AvatarCoachDataStatus.loading;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        key: Key('avatar-coach-${status.name}'),
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 90),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: VvewellColors.surface,
          border: Border.all(color: VvewellColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            if (isLoading)
              const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            else
              Icon(
                status == AvatarCoachDataStatus.error
                    ? Icons.cloud_off_outlined
                    : status == AvatarCoachDataStatus.empty
                    ? Icons.inbox_outlined
                    : Icons.info_outline_rounded,
                color: VvewellColors.muted,
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                (viewModel.statusMessage ?? '今日状态暂不可用').tr,
                style: const TextStyle(color: VvewellColors.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HealthRings extends StatelessWidget {
  const _HealthRings({
    required this.score,
    required this.size,
    required this.indices,
  });

  final int score;
  final double size;
  final List<HealthIndex> indices;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _HealthRingPainter(indices: indices),
          ),
          Text(
            '$score',
            style: TextStyle(
              fontSize: size * .31,
              height: 1,
              fontWeight: FontWeight.w800,
              color: VvewellColors.foreground,
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthRingPainter extends CustomPainter {
  const _HealthRingPainter({required this.indices});

  final List<HealthIndex> indices;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final values = [
      for (final index in indices.take(3)) index.value / 100,
      ...List<double>.filled(math.max(0, 3 - indices.length), 0),
    ];
    final rings = <_RingStyle>[
      _RingStyle(
        size.width * .43,
        size.width * .055,
        values[0],
        VvewellColors.primary,
      ),
      _RingStyle(
        size.width * .34,
        size.width * .048,
        values[1],
        VvewellColors.success,
      ),
      _RingStyle(
        size.width * .25,
        size.width * .041,
        values[2],
        const Color(0xFFA363D5),
      ),
    ];
    for (final ring in rings) {
      final base = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ring.width
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFE4ECEB);
      final arc = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ring.width
        ..strokeCap = StrokeCap.round
        ..color = ring.color;
      final rect = Rect.fromCircle(center: center, radius: ring.radius);
      canvas.drawCircle(center, ring.radius, base);
      canvas.drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2 * ring.progress,
        false,
        arc,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HealthRingPainter oldDelegate) =>
      oldDelegate.indices != indices;
}

class _RingStyle {
  const _RingStyle(this.radius, this.width, this.progress, this.color);

  final double radius;
  final double width;
  final double progress;
  final Color color;
}

class _HealthRingLegend extends StatelessWidget {
  const _HealthRingLegend({required this.indices, required this.showDeltas});

  final List<HealthIndex> indices;
  final bool showDeltas;

  @override
  Widget build(BuildContext context) {
    const colors = [
      VvewellColors.primary,
      VvewellColors.success,
      Color(0xFFA363D5),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < math.min(3, indices.length); index++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: _HealthRingLegendItem(
              color: colors[index],
              label: indices[index].label,
              value: '${indices[index].value}',
              delta: indices[index].delta,
              showDelta: showDeltas,
            ),
          ),
      ],
    );
  }
}

class _HealthRingLegendItem extends StatelessWidget {
  const _HealthRingLegendItem({
    required this.color,
    required this.label,
    required this.value,
    required this.delta,
    required this.showDelta,
  });

  final Color color;
  final String label;
  final String value;
  final int delta;
  final bool showDelta;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label.tr,
            maxLines: 2,
            style: const TextStyle(color: VvewellColors.muted, fontSize: 11),
          ),
        ),
        const SizedBox(width: 3),
        Text(
          value,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 3),
        SizedBox(
          width: 29,
          child: AnimatedOpacity(
            opacity: showDelta && delta != 0 ? 1 : 0,
            duration: const Duration(milliseconds: 160),
            child: Text(
              delta > 0 ? '+$delta' : '$delta',
              key: Key('metric-delta-$label'),
              style: TextStyle(
                color: delta >= 0
                    ? VvewellColors.success
                    : VvewellColors.warning,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PageSectionTitle extends StatelessWidget {
  const _PageSectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title.tr,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    );
  }
}

class _QuickEntryGrid extends StatelessWidget {
  const _QuickEntryGrid({
    required this.onOpenDevices,
    required this.onOpenRppg,
    required this.onOpenMedical,
    required this.onOpenHealthRecord,
    required this.onOpenNutrition,
    required this.onOpenThermalCamera,
  });

  final VoidCallback onOpenDevices;
  final VoidCallback onOpenRppg;
  final VoidCallback onOpenMedical;
  final VoidCallback onOpenHealthRecord;
  final VoidCallback onOpenNutrition;
  final VoidCallback onOpenThermalCamera;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 9,
      crossAxisSpacing: 9,
      childAspectRatio: 1.2,
      children: [
        _QuickEntry(
          icon: Icons.medical_services_outlined,
          label: '医疗'.tr,
          onTap: onOpenMedical,
        ),
        _QuickEntry(
          icon: Icons.description_outlined,
          label: '健康档案'.tr,
          onTap: onOpenHealthRecord,
        ),
        _QuickEntry(
          icon: Icons.bluetooth_searching_rounded,
          label: '设备'.tr,
          onTap: onOpenDevices,
        ),
        _QuickEntry(
          icon: Icons.thermostat_outlined,
          label: '红外摄像头'.tr,
          onTap: onOpenThermalCamera,
        ),
        _QuickEntry(
          icon: Icons.monitor_heart_outlined,
          label: '手机测量'.tr,
          onTap: onOpenRppg,
        ),
        _QuickEntry(
          icon: Icons.apple_outlined,
          label: '营养'.tr,
          onTap: onOpenNutrition,
        ),
      ],
    );
  }
}

class _QuickEntry extends StatelessWidget {
  const _QuickEntry({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: VvewellColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: Key('quick-entry-$label'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 100,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: VvewellColors.primary, size: 24),
              const SizedBox(height: 7),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 3,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConnectedDeviceBanner extends StatelessWidget {
  const _ConnectedDeviceBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      color: VvewellColors.softTeal,
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        children: [
          const _SoftIcon(
            icon: Icons.watch_outlined,
            color: VvewellColors.success,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '连接你的健康设备'.tr,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(
                  'Alloop、AIZORING、健康小助手、JDY-23 雷达'.tr,
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
    );
  }
}

class _HealthTab extends StatefulWidget {
  const _HealthTab({
    required this.familyProfileController,
    required this.nutritionDemoController,
    required this.medicalReportStore,
  });

  final FamilyProfileController familyProfileController;
  final NutritionDemoController nutritionDemoController;
  final MedicalReportStore medicalReportStore;

  @override
  State<_HealthTab> createState() => _HealthTabState();
}

class _HealthTabState extends State<_HealthTab> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('health-scroll-view'),
      padding: const EdgeInsets.only(bottom: 28),
      children: [
        _VvewellHeader(familyProfileController: widget.familyProfileController),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
          child: AnimatedBuilder(
            animation: widget.familyProfileController,
            builder: (context, _) => HealthScoreCard(
              actualAge: widget.familyProfileController.activeMember.ageAt(
                DateTime.now().year,
              ),
            ),
          ),
        ),
        const SizedBox(height: 22),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _SurfaceCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _SectionTabs(
                  labels: const ['Vitals', 'Sleep', 'Exercise', 'Women’s health'],
                  index: _tabIndex,
                  onChanged: (value) => setState(() => _tabIndex = value),
                ),
                const SizedBox(height: 16),
                if (_tabIndex == 0)
                  const _PhysiologyOverview()
                else if (_tabIndex == 1)
                  const _SleepOverview()
                else if (_tabIndex == 2)
                  const _ExerciseOverview()
                else
                  const WomenHealthPanel(),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _MedicalReportSection(
            familyProfileController: widget.familyProfileController,
            nutritionDemoController: widget.nutritionDemoController,
            medicalReportStore: widget.medicalReportStore,
          ),
        ),
        const SizedBox(height: 22),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: _RecommendationSection(),
        ),
      ],
    );
  }
}

class _SectionTabs extends StatelessWidget {
  const _SectionTabs({
    required this.labels,
    required this.index,
    required this.onChanged,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF0EF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: List.generate(labels.length, (itemIndex) {
          final selected = itemIndex == index;
          return Expanded(
            child: Material(
              color: selected ? VvewellColors.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(11),
              child: InkWell(
                onTap: () => onChanged(itemIndex),
                borderRadius: BorderRadius.circular(11),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Text(
                    labels[itemIndex].tr,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selected
                          ? VvewellColors.foreground
                          : VvewellColors.muted,
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _PhysiologyOverview extends StatelessWidget {
  const _PhysiologyOverview();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _SleepDurationCard(),
        SizedBox(height: 14),
        _TodayExerciseCard(),
        SizedBox(height: 14),
        _PhysiologyDataCard(),
      ],
    );
  }
}

class _SleepDurationCard extends StatelessWidget {
  const _SleepDurationCard();

  @override
  Widget build(BuildContext context) {
    return _InsetCard(
      child: Column(
        children: [
          Row(
            children: [
              const _SoftIcon(
                icon: Icons.nightlight_round,
                color: VvewellColors.warning,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '昨晚时长'.tr,
                      style: const TextStyle(
                        color: VvewellColors.muted,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '06小时30分钟'.tr,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          const _ProgressBar(progress: .79, color: VvewellColors.warning),
        ],
      ),
    );
  }
}

class _TodayExerciseCard extends StatelessWidget {
  const _TodayExerciseCard();

  @override
  Widget build(BuildContext context) {
    return _InsetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _SoftIcon(
                icon: Icons.directions_walk_outlined,
                color: VvewellColors.success,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '今日运动'.tr,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Row(
            children: [
              Expanded(
                child: _OverviewValue(
                  icon: Icons.directions_walk_outlined,
                  value: '11.5k',
                  label: 'Steps',
                ),
              ),
              SizedBox(width: 9),
              Expanded(
                child: _OverviewValue(
                  icon: Icons.local_fire_department_outlined,
                  value: '1400',
                  label: 'kcal',
                ),
              ),
              SizedBox(width: 9),
              Expanded(
                child: _OverviewValue(
                  icon: Icons.schedule_outlined,
                  value: '166',
                  label: 'min',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OverviewValue extends StatelessWidget {
  const _OverviewValue({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: VvewellColors.softTeal,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: VvewellColors.muted),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            label.tr,
            style: const TextStyle(color: VvewellColors.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _PhysiologyDataCard extends StatelessWidget {
  const _PhysiologyDataCard();

  @override
  Widget build(BuildContext context) {
    const items = <_VitalItem>[
      _VitalItem(
        Icons.monitor_heart_outlined,
        'Current heart rate',
        '50 BPM',
        VvewellColors.error,
      ),
      _VitalItem(
        Icons.water_drop_outlined,
        'Current blood oxygen',
        '98 %',
        Color(0xFF249CE0),
      ),
      _VitalItem(
        Icons.thermostat_outlined,
        'Current temperature',
        '35 ℃',
        VvewellColors.warning,
      ),
      _VitalItem(
        Icons.graphic_eq_outlined,
        'Heart rate variability',
        '40 ms',
        VvewellColors.primary,
      ),
      _VitalItem(Icons.nightlight_round, 'Resting heart rate', '72 BPM', Color(0xFF9B6CDD)),
    ];
    return _InsetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('生理数据'.tr, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(
            '最近同步时间: 2026-06-27 16:18'.tr,
            style: const TextStyle(color: VvewellColors.muted, fontSize: 11),
          ),
          const SizedBox(height: 12),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _VitalRow(item: item),
            ),
          ),
        ],
      ),
    );
  }
}

class _VitalItem {
  const _VitalItem(this.icon, this.label, this.value, this.color);

  final IconData icon;
  final String label;
  final String value;
  final Color color;
}

class _VitalRow extends StatelessWidget {
  const _VitalRow({required this.item});

  final _VitalItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      decoration: BoxDecoration(
        color: VvewellColors.softTeal,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(item.icon, color: item.color, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Text(item.label.tr, style: const TextStyle(fontSize: 13)),
          ),
          Text(
            item.value,
            style: const TextStyle(
              color: VvewellColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SleepOverview extends StatelessWidget {
  const _SleepOverview();

  @override
  Widget build(BuildContext context) {
    const sleepDays = <double>[.72, .84, .68, .77, .86, .91, .79];
    return Column(
      children: [
        _InsetCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '睡眠阶段趋势'.tr,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 17),
              SizedBox(
                height: 120,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(
                    sleepDays.length,
                    (index) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Expanded(
                              child: FractionallySizedBox(
                                alignment: Alignment.bottomCenter,
                                heightFactor: sleepDays[index],
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: index == 5
                                        ? VvewellColors.primary
                                        : VvewellColors.softBlue,
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              Get.locale?.languageCode == 'en'
                                  ? const [
                                      'Mon',
                                      'Tue',
                                      'Wed',
                                      'Thu',
                                      'Fri',
                                      'Sat',
                                      'Sun',
                                    ][index]
                                  : '周${'一二三四五六日'[index]}',
                              style: const TextStyle(
                                color: VvewellColors.muted,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _InsetCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '睡眠阶段时长'.tr,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              const _KeyValueRow(label: 'Total sleep', value: '6 h 20 min'),
              const _KeyValueRow(label: 'REM sleep', value: '4 h 18 min'),
              const _KeyValueRow(label: 'Core sleep', value: '1 h 20 min'),
              const _KeyValueRow(label: 'Deep sleep', value: '47 min'),
            ],
          ),
        ),
      ],
    );
  }
}

class _ExerciseOverview extends StatelessWidget {
  const _ExerciseOverview();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _TodayExerciseCard(),
        const SizedBox(height: 14),
        _InsetCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '运动记录'.tr,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              const _ExerciseRecord(
                time: '2026-07-27 08:30',
                duration: '20 min',
                distance: '5.2 km',
              ),
              const SizedBox(height: 9),
              const _ExerciseRecord(
                time: '2026-07-27 12:15',
                duration: '35 min',
                distance: '3.8 km',
              ),
              const SizedBox(height: 9),
              const _ExerciseRecord(
                time: '2026-07-26 18:00',
                duration: '45 min',
                distance: '4.5 km',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ExerciseRecord extends StatelessWidget {
  const _ExerciseRecord({
    required this.time,
    required this.duration,
    required this.distance,
  });

  final String time;
  final String duration;
  final String distance;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: VvewellColors.softTeal,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const _SoftIcon(
            icon: Icons.directions_walk_outlined,
            color: VvewellColors.success,
            size: 34,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '户外步行'.tr,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  time,
                  style: const TextStyle(
                    color: VvewellColors.muted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${duration.tr}\n${distance.tr}',
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: VvewellColors.muted,
              fontSize: 11,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  const _KeyValueRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
        decoration: BoxDecoration(
          color: VvewellColors.softTeal,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(label.tr, style: const TextStyle(fontSize: 13)),
            ),
            Text(
              value.tr,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _MedicalReportSection extends StatefulWidget {
  const _MedicalReportSection({
    required this.familyProfileController,
    required this.nutritionDemoController,
    required this.medicalReportStore,
  });

  final FamilyProfileController familyProfileController;
  final NutritionDemoController nutritionDemoController;
  final MedicalReportStore medicalReportStore;

  @override
  State<_MedicalReportSection> createState() => _MedicalReportSectionState();
}

class _MedicalReportSectionState extends State<_MedicalReportSection> {
  @override
  void initState() {
    super.initState();
    widget.familyProfileController.addListener(_refresh);
    widget.medicalReportStore.addListener(_refresh);
  }

  @override
  void didUpdateWidget(covariant _MedicalReportSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.familyProfileController != widget.familyProfileController) {
      oldWidget.familyProfileController.removeListener(_refresh);
      widget.familyProfileController.addListener(_refresh);
    }
    if (oldWidget.medicalReportStore != widget.medicalReportStore) {
      oldWidget.medicalReportStore.removeListener(_refresh);
      widget.medicalReportStore.addListener(_refresh);
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.familyProfileController.removeListener(_refresh);
    widget.medicalReportStore.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _uploadReport() async {
    final result = await showMedicalReportUploadSheet(
      context,
      memberName: widget.familyProfileController.activeMember.name.tr,
      memberId: widget.familyProfileController.activeMember.id,
    );
    if (result == null || !mounted) return;
    widget.medicalReportStore.add(
      widget.familyProfileController.activeMember.id,
      result,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          (result.isDemo ? '脱敏演示报告已加入本次档案' : '报告识别完成，已加入本次演示档案').tr,
        ),
      ),
    );
  }

  Future<void> _uploadMeal() async {
    final result = await showNutritionCaptureSheet(
      context,
      controller: widget.nutritionDemoController,
    );
    if (result == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '已记录@meal：@summary'.trParams({
            'meal': result.mealType.tr,
            'summary': '@calories kcal · 蛋白 @protein g'.trParams({
              'calories': '${result.totals.kcal.round()}',
              'protein': result.totals.protein.toStringAsFixed(1),
            }),
          }),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reports = widget.medicalReportStore.reportsFor(
      widget.familyProfileController.activeMember.id,
    );
    return _SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '医疗报告与饮食摄入'.tr,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '真实图片生成可复核的 OCR 结果，并加入当前家庭成员的本次演示档案。'.tr,
            style: const TextStyle(
              color: VvewellColors.muted,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = constraints.maxWidth < 360
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: _UploadModuleCard(
                      key: const Key('medical-report-upload-entry'),
                      icon: Icons.description_outlined,
                      color: const Color(0xFF3A8DD9),
                      title: 'Medical report upload',
                      subtitle: 'Checkups, lab tests, imaging or discharge records',
                      action: 'Upload report',
                      onTap: _uploadReport,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _UploadModuleCard(
                      key: const Key('meal-upload-entry'),
                      icon: Icons.restaurant_outlined,
                      color: VvewellColors.warning,
                      title: 'Today’s meals',
                      subtitle: 'Breakfast, lunch, dinner or snacks',
                      action: 'Analyze nutrition',
                      onTap: _uploadMeal,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          if (reports.isEmpty)
            const _EmptyUploadRow(
              icon: Icons.folder_open_outlined,
              text: 'No medical reports yet. Upload a report to see its summary here.',
            )
          else ...[
            Text(
              '最近医疗报告'.tr,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            ...reports
                .take(2)
                .map(
                  (report) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: VvewellColors.softBlue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${report.reportType.tr} · ${report.institution}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            report.summary,
                            style: const TextStyle(
                              color: VvewellColors.muted,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          ],
          const SizedBox(height: 14),
          AnimatedBuilder(
            animation: widget.nutritionDemoController,
            builder: (context, _) {
              final intakes = widget.nutritionDemoController.intakes;
              if (intakes.isEmpty) {
                return const _EmptyUploadRow(
                  icon: Icons.no_meals_outlined,
                  text: 'No food intake recorded today. Upload a meal to see nutrition totals.',
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '今日饮食摄入'.tr,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      Text(
                        '${widget.nutritionDemoController.todayCalories} kcal',
                        style: const TextStyle(
                          color: VvewellColors.primaryDark,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...intakes
                      .take(4)
                      .map(
                        (intake) => Padding(
                          padding: const EdgeInsets.only(bottom: 7),
                          child: Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: VvewellColors.softOrange,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.restaurant_menu,
                                  size: 18,
                                  color: VvewellColors.warning,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '${intake.mealType} · ${intake.foods.map((food) => food.name).join('、')}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                intake.summary,
                                style: const TextStyle(
                                  color: VvewellColors.muted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _UploadModuleCard extends StatelessWidget {
  const _UploadModuleCard({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.action,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: 168,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color, size: 26),
                const SizedBox(height: 10),
                Text(
                  title.tr,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle.tr,
                  style: const TextStyle(
                    color: VvewellColors.muted,
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        action.tr,
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Icon(Icons.arrow_forward, color: color, size: 17),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyUploadRow extends StatelessWidget {
  const _EmptyUploadRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VvewellColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: VvewellColors.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text.tr,
              style: const TextStyle(color: VvewellColors.muted, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendationSection extends StatelessWidget {
  const _RecommendationSection();

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '健康建议'.tr,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 18),
          Text(
            '生活方式'.tr,
            style: const TextStyle(color: VvewellColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 7),
          const _SuggestionTile(title: 'Improve your sleep routine', description: 'Keep consistent bedtimes and wake times'),
          const SizedBox(height: 13),
          Text(
            '营养'.tr,
            style: const TextStyle(color: VvewellColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 7),
          const _SuggestionTile(
            title: 'Increase vitamin D',
            description: 'Consider 2,000 IU daily',
          ),
          const SizedBox(height: 13),
          Text(
            '运动'.tr,
            style: const TextStyle(color: VvewellColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 7),
          const _SuggestionTile(title: 'Add strength training', description: 'Aim for 2–3 sessions per week'),
        ],
      ),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: VvewellColors.softTeal,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.tr, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            description.tr,
            style: const TextStyle(color: VvewellColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ChatTab extends StatefulWidget {
  const _ChatTab({
    super.key,
    required this.familyProfileController,
    required this.nutritionDemoController,
    required this.medicalReportStore,
  });

  final FamilyProfileController familyProfileController;
  final NutritionDemoController nutritionDemoController;
  final MedicalReportStore medicalReportStore;

  @override
  State<_ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<_ChatTab> {
  final _inputController = TextEditingController();
  final _ocrService = MedicalOcrService();
  final Map<int, List<_ChatMessage>> _messagesByTopic =
      <int, List<_ChatMessage>>{};
  int _topicIndex = 0;
  bool _doctorSelected = true;

  void selectDoctor() => setState(() => _doctorSelected = true);
  bool _isResponding = false;
  MedicalReportResult? _consultationReport;
  late String _consultationMemberId;

  @override
  void initState() {
    super.initState();
    _consultationMemberId = widget.familyProfileController.activeMember.id;
    widget.familyProfileController.addListener(_refreshContext);
    widget.medicalReportStore.addListener(_refreshContext);
  }

  @override
  void didUpdateWidget(covariant _ChatTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.familyProfileController != widget.familyProfileController) {
      oldWidget.familyProfileController.removeListener(_refreshContext);
      widget.familyProfileController.addListener(_refreshContext);
    }
    if (oldWidget.medicalReportStore != widget.medicalReportStore) {
      oldWidget.medicalReportStore.removeListener(_refreshContext);
      widget.medicalReportStore.addListener(_refreshContext);
    }
  }

  void _refreshContext() {
    final memberId = widget.familyProfileController.activeMember.id;
    if (memberId != _consultationMemberId) {
      _consultationMemberId = memberId;
      _consultationReport = null;
    }
    if (mounted) setState(() {});
  }

  static const _topics = <_ChatTopic>[
    _ChatTopic(
      label: kIsWeb ? 'Health' : '健康咨询',
      icon: Icons.medical_services_outlined,
      title: '先了解你的当前健康状况',
      description: '我会区分已确认事实、设备趋势与预测风险，并在需要时建议线下就医。',
      suggestions: [
        _ChatSuggestion('心血管', '血压最近稳定，但为什么仍建议做年度心血管复查？'),
        _ChatSuggestion('症状判断', '出现哪些胸闷或心悸信号时应该立即就医？'),
        _ChatSuggestion('健康档案', '帮我总结当前健康档案里最需要关注的三件事'),
        _ChatSuggestion('复查准备', '心血管复查前应该准备哪些报告和测量记录？'),
      ],
    ),
    _ChatTopic(
      label: kIsWeb ? 'Reports' : '报告咨询',
      icon: Icons.document_scanner_outlined,
      title: '上传报告后继续咨询',
      description: '我会读取 OCR 结构化结果，整理异常指标、参考范围和复诊问题；所有数值仍须与原报告核对。',
      suggestions: [
        _ChatSuggestion('体检报告', '体检报告里哪些异常项通常需要优先复核？'),
        _ChatSuggestion('检验指标', '如何区分单次异常和需要持续观察的趋势？'),
        _ChatSuggestion('复诊清单', '根据报告帮我整理一份向医生提问的清单'),
        _ChatSuggestion('隐私', '上传医疗报告时哪些个人信息可以先遮挡？'),
      ],
    ),
    _ChatTopic(
      label: kIsWeb ? 'Nutrition' : '营养顾问',
      icon: Icons.apple_outlined,
      title: '结合今天的饮食与补剂记录',
      description: '优先改善全天饮食结构，再讨论是否需要补剂和人工复核。',
      suggestions: [
        _ChatSuggestion('饮食摄入', '根据今天已记录的餐食，我还缺哪些营养？'),
        _ChatSuggestion('补剂安全', '鱼油、镁和维生素 D 应该怎样安排时间？'),
        _ChatSuggestion('食物优先', '有哪些食物可以替代当前候选补剂？'),
        _ChatSuggestion('拍照识别', '我想上传午餐图片并估算营养成分'),
      ],
    ),
    _ChatTopic(
      label: kIsWeb ? 'Sleep' : '睡眠助手',
      icon: Icons.nightlight_round,
      title: '先看睡眠时长、趋势与风险标签',
      description: '当前结果只用于健康提醒，不用于诊断；中等睡眠呼吸风险建议专业评估。',
      suggestions: [
        _ChatSuggestion('睡眠时长', '昨晚只睡了 6 小时 30 分钟，今晚怎么调整？'),
        _ChatSuggestion('呼吸风险', '睡眠呼吸风险为中等意味着什么，下一步做什么？'),
        _ChatSuggestion('作息', '帮我制定未来七天固定入睡和起床计划'),
        _ChatSuggestion('助眠补剂', '褪黑素和镁是否适合长期使用？'),
      ],
    ),
    _ChatTopic(
      label: 'Medication',
      icon: Icons.medication_outlined,
      title: 'Ask about medication safety',
      description:
          'Discuss medication questions and interactions. Confirm any treatment changes with your clinician.',
      suggestions: [
        _ChatSuggestion(
          'Interactions',
          'What should I check before combining a medicine with a supplement?',
        ),
        _ChatSuggestion(
          'Review',
          'Help me prepare questions for a medication review with my doctor.',
        ),
      ],
    ),
  ];

  List<_ChatMessage> get _messages =>
      _messagesByTopic.putIfAbsent(_topicIndex, () => <_ChatMessage>[]);

  @override
  void dispose() {
    widget.familyProfileController.removeListener(_refreshContext);
    widget.medicalReportStore.removeListener(_refreshContext);
    _inputController.dispose();
    _ocrService.close();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isResponding) return;
    final topic = _topicIndex;
    final topicMessages = _messages;
    setState(() {
      topicMessages.add(_ChatMessage(text, true));
      _inputController.clear();
      _isResponding = topic == 0 || topic == 1 || topic == 4;
    });

    if (topic == 2 || topic == 3) {
      setState(
        () => topicMessages.add(_ChatMessage(_responseForTopic(), false)),
      );
      return;
    }

    final member = widget.familyProfileController.activeMember;
    final report = topic == 1
        ? _consultationReport
        : widget.medicalReportStore.latestFor(member.id);
    if (topic == 1 && report?.ocrResult == null) {
      setState(() {
        topicMessages.add(
          _ChatMessage('请先上传一张真实医疗报告。完成 OCR 后，我才能基于报告内容回答。'.tr, false),
        );
        _isResponding = false;
      });
      return;
    }

    try {
      final response = await _ocrService.consult(
        question: text,
        memberName: member.name.tr,
        profileContext: _profileContext(includeStoredReport: topic == 0),
        report: report?.ocrResult,
        responseLanguage: Get.locale?.languageCode ?? 'en',
        profileIsSample: kIsWeb && member.id.startsWith('member-'),
      );
      if (!mounted) return;
      setState(() {
        topicMessages.add(_ChatMessage(response, false));
        _isResponding = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        topicMessages.add(_ChatMessage('${'咨询失败'.tr}：$error', false));
        _isResponding = false;
      });
    }
  }

  String _profileContext({required bool includeStoredReport}) {
    final member = widget.familyProfileController.activeMember;
    final tags = member.tags
        .where((tag) => !tag.hiddenFromPersonalization)
        .map(
          (tag) =>
              '${tag.category.tr}/${tag.label.tr}: ${tag.value.tr}; status=${tag.status.name}; source=${tag.source.tr}',
        )
        .join('\n');
    final latestReport = includeStoredReport
        ? widget.medicalReportStore.latestFor(member.id)
        : null;
    final reportSummary = latestReport == null
        ? "No archived reports"
        : '${latestReport.reportType.tr}: ${latestReport.summary}';
    return 'Member: ${member.relationship.tr}, ${member.gender.tr}, born ${member.birthYear}\n'
        '$tags\nLatest report: $reportSummary';
  }

  String _responseForTopic() => (switch (_topicIndex) {
    1 => '我会先提取报告类型、日期、医疗机构、异常指标和医生结论，并把无法确认的 OCR 内容标记出来。请不要仅依据识别结果自行停药或调整治疗。',
    2 =>
      '我会结合已确认的餐食摄入、过敏与用药信息判断。当前建议先保证蛋白质、蔬菜和全谷物，再评估补剂；涉及鱼油、维生素 K 或助眠成分时需核对药物相互作用。',
    3 =>
      '当前档案显示昨晚睡眠 6 小时 30 分钟，并有中等睡眠呼吸风险标签。建议先记录一周作息、打鼾和日间嗜睡情况；若有夜间憋醒或明显日间嗜睡，应进行专业睡眠评估。',
    _ => '当前已确认血压近 7 天稳定，同时存在 30 天内完成年度心血管复查的提醒。我会先区分紧急信号、既往事实和趋势数据，再给出下一步建议。',
  }).tr;

  Future<void> _captureNutrition() async {
    final result = await showNutritionCaptureSheet(
      context,
      controller: widget.nutritionDemoController,
    );
    if (result == null || !mounted) return;
    setState(
      () => _messages.add(
        _ChatMessage(
          Get.locale?.languageCode == 'en'
              ? 'Saved the Mock nutrition assessment for ${result.mealType.tr}: ${result.totals.kcal.round()} kcal · Protein ${result.totals.protein.toStringAsFixed(1)} g. You can ask how to complete today\'s remaining nutrition.'
              : 'Saved ${result.mealType} demo nutrition assessment: ${result.summary}. Ask how to meet your remaining nutrition needs today.',
          false,
        ),
      ),
    );
  }

  Future<void> _uploadReport() async {
    final member = widget.familyProfileController.activeMember;
    final result = await showMedicalReportUploadSheet(
      context,
      memberName: member.name.tr,
      saveToMedicalArchive: false,
    );
    if (result == null || !mounted) return;
    _consultationMemberId = member.id;
    _consultationReport = result;
    setState(
      () => _messages.add(
        _ChatMessage(
          result.isDemo
              ? '已载入脱敏演示报告。若要进行真实报告咨询，请上传实际报告图片。'.tr
              : Get.locale?.languageCode == 'en'
              ? 'Report OCR completed: ${result.summary}\nYou can now ask questions about this report.'
              : 'Report OCR complete: ${result.summary}\nYou can now ask about this report.',
          false,
        ),
      ),
    );
  }

  void _useSuggestion(String text) {
    _inputController.text = text;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final activeMember = widget.familyProfileController.activeMember;
    final latestReport = _consultationReport;
    return Column(
      children: [
        _VvewellHeader(familyProfileController: widget.familyProfileController),
        Container(
          height: 71,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: const BoxDecoration(
            color: VvewellColors.surface,
            border: Border(bottom: BorderSide(color: VvewellColors.border)),
          ),
          child: ListView.separated(
            key: const Key('chat-topic-strip'),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: _topics.length + 1,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, position) {
              if (position == 0) {
                return _TopicButton(
                  key: const Key('chat-topic-doctor'),
                  topic: const _ChatTopic(
                    label: 'Find a doctor',
                    icon: Icons.person_search_outlined,
                    title: '',
                    description: '',
                    suggestions: [],
                  ),
                  selected: _doctorSelected,
                  onTap: selectDoctor,
                );
              }
              final index = kIsWeb
                  ? const [1, 2, 4, 0, 3][position - 1]
                  : position - 1;
              final topic = _topics[index];
              return _TopicButton(
                key: Key('chat-topic-$index'),
                topic: topic,
                selected: !_doctorSelected && _topicIndex == index,
                onTap: () => setState(() {
                  _doctorSelected = false;
                  _topicIndex = index;
                  _inputController.clear();
                }),
              );
            },
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _doctorSelected ? 0 : 1,
            children: [
              doctor.ChatPage(
                showTopChips: false,
                memberName: activeMember.name.tr,
              ),
              Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 28, 16, 18),
                      children: [
                        if (_messages.isEmpty)
                          _ChatWelcome(
                            memberName: activeMember.name.tr,
                            topic: _topics[_topicIndex],
                            onSuggestion: _useSuggestion,
                            onUploadReport: _topicIndex == 1
                                ? _uploadReport
                                : null,
                            reportSummary: _topicIndex == 1
                                ? latestReport?.summary
                                : null,
                          )
                        else
                          ..._messages.map(
                            (message) => _MessageBubble(message: message),
                          ),
                      ],
                    ),
                  ),
                  ChatComposer(
                    controller: _inputController,
                    onSend: _send,
                    enabled: !_isResponding,
                    hintText: '输入 @topic 问题'.trParams({
                      'topic': _topics[_topicIndex].label.tr,
                    }),
                    actions: [
                      if (_topicIndex == 1)
                        IconButton(
                          key: const Key('report-consultation-upload'),
                          tooltip: '上传或选择医疗报告'.tr,
                          onPressed: _isResponding ? null : _uploadReport,
                          icon: const Icon(Icons.upload_file_outlined),
                        ),
                      if (_topicIndex == 2)
                        IconButton(
                          tooltip: '拍摄或选择餐食照片'.tr,
                          onPressed: _captureNutrition,
                          icon: const Icon(Icons.add_a_photo_outlined),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChatTopic {
  const _ChatTopic({
    required this.label,
    required this.icon,
    required this.title,
    required this.description,
    required this.suggestions,
  });

  final String label;
  final IconData icon;
  final String title;
  final String description;
  final List<_ChatSuggestion> suggestions;
}

class _ChatSuggestion {
  const _ChatSuggestion(this.tag, this.question);

  final String tag;
  final String question;
}

class _TopicButton extends StatelessWidget {
  const _TopicButton({
    super.key,
    required this.topic,
    required this.selected,
    required this.onTap,
  });

  final _ChatTopic topic;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? VvewellColors.primary : VvewellColors.surface,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected ? VvewellColors.primary : VvewellColors.border,
            ),
          ),
          child: Row(
            children: [
              Icon(
                topic.icon,
                size: 19,
                color: selected ? Colors.white : VvewellColors.foreground,
              ),
              const SizedBox(width: 7),
              Text(
                topic.label.tr,
                style: TextStyle(
                  color: selected ? Colors.white : VvewellColors.foreground,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatWelcome extends StatelessWidget {
  const _ChatWelcome({
    required this.memberName,
    required this.topic,
    required this.onSuggestion,
    this.onUploadReport,
    this.reportSummary,
  });

  final String memberName;
  final _ChatTopic topic;
  final ValueChanged<String> onSuggestion;
  final VoidCallback? onUploadReport;
  final String? reportSummary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _SoftIcon(icon: topic.icon, color: VvewellColors.primary, size: 52),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    topic.label.tr,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '@member 的个性化咨询场景'.trParams({'member': memberName}),
                    style: const TextStyle(
                      color: VvewellColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: VvewellColors.softBlue,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                topic.title.tr,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 5),
              Text(
                topic.description.tr,
                style: const TextStyle(
                  color: VvewellColors.muted,
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 10),
              const Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  _ContextTag('血压近 7 天稳定'),
                  _ContextTag('睡眠 6小时30分钟'),
                  _ContextTag('睡眠呼吸风险：中等'),
                  _ContextTag('心血管复查：30天内'),
                ],
              ),
            ],
          ),
        ),
        if (onUploadReport != null) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const Key('report-consultation-welcome-upload'),
              onPressed: onUploadReport,
              icon: const Icon(Icons.upload_file_outlined),
              label: Text((reportSummary == null ? '上传报告开始咨询' : '更换咨询报告').tr),
            ),
          ),
          if (reportSummary != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: VvewellColors.softTeal,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '当前报告：@report'.trParams({'report': reportSummary!.tr}),
                style: const TextStyle(fontSize: 12, height: 1.4),
              ),
            ),
          ],
        ],
        const SizedBox(height: 22),
        Text(
          '你可以从这些问题开始'.tr,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        ...topic.suggestions.map(
          (suggestion) => Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Material(
              color: VvewellColors.surface,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: () => onSuggestion(suggestion.question.tr),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    border: Border.all(color: VvewellColors.border),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: VvewellColors.softTeal,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          suggestion.tag.tr,
                          style: const TextStyle(
                            color: VvewellColors.primaryDark,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(suggestion.question.tr)),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: VvewellColors.muted,
                        size: 14,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ContextTag extends StatelessWidget {
  const _ContextTag(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: VvewellColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: VvewellColors.border),
      ),
      child: Text(text.tr, style: const TextStyle(fontSize: 10)),
    );
  }
}

class _ChatMessage {
  const _ChatMessage(this.text, this.isUser);

  final String text;
  final bool isUser;
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: const BoxConstraints(maxWidth: 300),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: message.isUser ? VvewellColors.primary : VvewellColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: message.isUser
              ? null
              : Border.all(color: VvewellColors.border),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: message.isUser ? Colors.white : VvewellColors.foreground,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

class _MedicalTab extends StatefulWidget {
  const _MedicalTab({required this.familyProfileController});

  final FamilyProfileController familyProfileController;

  @override
  State<_MedicalTab> createState() => _MedicalTabState();
}

class _MedicalTabState extends State<_MedicalTab> {
  int _selectedTier = 1;
  int _orderTab = 0;

  @override
  Widget build(BuildContext context) {
    if (!const bool.fromEnvironment('VVEWELL_LEGACY_MEDICAL_UI')) {
      return MedicalHubPage(
        familyProfileController: widget.familyProfileController,
        header: _VvewellHeader(
          familyProfileController: widget.familyProfileController,
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 28),
      children: [
        _VvewellHeader(familyProfileController: widget.familyProfileController),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: "Emergency help",
                  icon: Icons.warning_amber_rounded,
                  color: VvewellColors.error,
                  onTap: () => _notice(context, '紧急救援服务入口已准备就绪'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionButton(
                  label: '在线客服',
                  icon: Icons.chat_bubble_outline,
                  outlined: true,
                  onTap: () => _notice(context, '在线客服服务入口已准备就绪'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: _PageSectionTitle(title: "Specialist services"),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: _RecommendedServiceCard(),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _ServiceTierList(
            selectedTier: _selectedTier,
            onSelected: (index) => setState(() => _selectedTier = index),
          ),
        ),
        const SizedBox(height: 22),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: _GlobalReferralSection(),
        ),
        const SizedBox(height: 22),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _MedicalOrdersSection(
            tabIndex: _orderTab,
            onChanged: (index) => setState(() => _orderTab = index),
          ),
        ),
        const SizedBox(height: 22),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: _MedicalResourcesSection(),
        ),
        const SizedBox(height: 22),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: _InsuranceSection(),
        ),
        const SizedBox(height: 22),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: _ExclusiveServiceSection(),
        ),
      ],
    );
  }

  void _notice(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message.tr)));
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.color = VvewellColors.primary,
    this.outlined = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: outlined
          ? OutlinedButton.icon(
              onPressed: onTap,
              icon: Icon(icon),
              label: Text(label),
            )
          : ElevatedButton.icon(
              onPressed: onTap,
              icon: Icon(icon),
              label: Text(label),
              style: ElevatedButton.styleFrom(backgroundColor: color),
            ),
    );
  }
}

class _RecommendedServiceCard extends StatelessWidget {
  const _RecommendedServiceCard();

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      color: VvewellColors.softTeal,
      padding: const EdgeInsets.all(15),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SmallBadge(label: "Recommended"),
                SizedBox(height: 9),
                Text(
                  "Specialist consultation",
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 4),
                Text(
                  "Specialist services matched to your current health assessment.",
                  style: TextStyle(color: VvewellColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          _SoftIcon(
            icon: Icons.medical_services_outlined,
            color: VvewellColors.primary,
          ),
        ],
      ),
    );
  }
}

class _ServiceTierList extends StatelessWidget {
  const _ServiceTierList({
    required this.selectedTier,
    required this.onSelected,
  });

  final int selectedTier;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    const tiers = <_ServiceTier>[
      _ServiceTier(
        "Basic consultation",
        "General health advice and common questions",
        "CNY 199 / visit",
        Icons.medical_services_outlined,
        VvewellColors.primary,
      ),
      _ServiceTier(
        "Specialist consultation",
        "Online consultation with specialists from leading hospitals",
        "CNY 699 / visit",
        Icons.star_outline,
        Color(0xFF3A8DD9),
      ),
      _ServiceTier(
        "Complex care support",
        "Care coordination and appointment support for serious conditions",
        "CNY 1,699 / visit",
        Icons.shield_outlined,
        Color(0xFF8759CF),
      ),
      _ServiceTier(
        '全球医疗',
        "International care and cross-border referral services",
        "CNY 2,999 / visit",
        Icons.public,
        VvewellColors.success,
      ),
    ];
    return Column(
      children: List.generate(
        tiers.length,
        (index) => Padding(
          padding: EdgeInsets.only(bottom: index == tiers.length - 1 ? 0 : 10),
          child: _ServiceTierCard(
            tier: tiers[index],
            selected: selectedTier == index,
            onTap: () => onSelected(index),
          ),
        ),
      ),
    );
  }
}

class _ServiceTier {
  const _ServiceTier(
    this.title,
    this.subtitle,
    this.price,
    this.icon,
    this.color,
  );

  final String title;
  final String subtitle;
  final String price;
  final IconData icon;
  final Color color;
}

class _ServiceTierCard extends StatelessWidget {
  const _ServiceTierCard({
    required this.tier,
    required this.selected,
    required this.onTap,
  });

  final _ServiceTier tier;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      color: selected ? VvewellColors.softTeal : null,
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      borderColor: selected ? VvewellColors.primary : VvewellColors.border,
      borderWidth: selected ? 1.6 : 1,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SoftIcon(icon: tier.icon, color: tier.color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        tier.title.tr,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (selected) _SmallBadge(label: '推荐'.tr),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  tier.subtitle.tr,
                  style: const TextStyle(
                    color: VvewellColors.muted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  tier.price,
                  style: TextStyle(
                    color: tier.color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  "✓ Qualified doctors · ✓ Health records · ✓ Service support",
                  style: TextStyle(color: VvewellColors.muted, fontSize: 11),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    height: 33,
                    child: selected
                        ? ElevatedButton(
                            onPressed: onTap,
                            child: Text('已选择'.tr),
                          )
                        : OutlinedButton(
                            onPressed: onTap,
                            child: Text('选择服务'.tr),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GlobalReferralSection extends StatelessWidget {
  const _GlobalReferralSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _PageSectionTitle(title: "Global referrals"),
        const SizedBox(height: 10),
        _SurfaceCard(
          color: VvewellColors.softTeal,
          padding: const EdgeInsets.all(15),
          child: Column(
            children: [
              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.public, color: VvewellColors.primary, size: 24),
                  SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Cross-border care",
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "Overseas hospital matching, medical record translation, appointment coordination and ongoing support.",
                          style: TextStyle(
                            color: VvewellColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 13),
              Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  height: 37,
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    icon: Icon(Icons.chevron_right),
                    label: Text("Quick assessment"),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MedicalOrdersSection extends StatelessWidget {
  const _MedicalOrdersSection({
    required this.tabIndex,
    required this.onChanged,
  });

  final int tabIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const labels = ['All', 'Pending', 'In progress', 'Completed'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _PageSectionTitle(title: 'My orders'),
        const SizedBox(height: 10),
        _SectionTabs(labels: labels, index: tabIndex, onChanged: onChanged),
        const SizedBox(height: 10),
        _SurfaceCard(
          padding: const EdgeInsets.all(16),
          child: const Column(
            children: [
              Icon(
                Icons.medical_services_outlined,
                size: 36,
                color: VvewellColors.border,
              ),
              SizedBox(height: 8),
              Text(
                "No care service orders yet",
                style: TextStyle(color: VvewellColors.muted, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MedicalResourcesSection extends StatelessWidget {
  const _MedicalResourcesSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _PageSectionTitle(title: "Care providers"),
        const SizedBox(height: 10),
        Row(
          children: [
            const Expanded(
              child: TextField(
                decoration: InputDecoration(
                  hintText: "Search hospitals, doctors or conditions…",
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 48,
              width: 48,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(padding: EdgeInsets.zero),
                child: const Icon(Icons.search),
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        const Wrap(
          spacing: 8,
          children: [
            _FilterPill(label: "All locations"),
            _FilterPill(label: "All departments"),
          ],
        ),
        const SizedBox(height: 10),
        const _ResourceCard(
          title: 'Beijing General Hospital',
          country: 'China',
          type: 'Hospital',
          tags: ['Cardiology', 'Neurology', 'Oncology'],
        ),
        const SizedBox(height: 9),
        const _ResourceCard(
          title: 'Mayo Clinic',
          country: 'United States',
          type: 'Hospital',
          tags: ['Cardiology', 'Gastroenterology', 'Orthopedics'],
        ),
        const SizedBox(height: 9),
        const _ResourceCard(
          title: 'Dr. Chen Wei',
          country: 'China',
          type: 'Doctor',
          tags: ['Cardiology'],
        ),
      ],
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: VvewellColors.surface,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: VvewellColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          const Icon(
            Icons.keyboard_arrow_down,
            size: 17,
            color: VvewellColors.muted,
          ),
        ],
      ),
    );
  }
}

class _ResourceCard extends StatelessWidget {
  const _ResourceCard({
    required this.title,
    required this.country,
    required this.type,
    required this.tags,
  });

  final String title;
  final String country;
  final String type;
  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      padding: const EdgeInsets.all(13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SoftIcon(
            icon: Icons.location_on_outlined,
            color: VvewellColors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    _SmallBadge(label: type),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  country,
                  style: const TextStyle(
                    color: VvewellColors.muted,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 5,
                  runSpacing: 4,
                  children: tags
                      .map((tag) => _SmallBadge(label: tag, muted: true))
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InsuranceSection extends StatelessWidget {
  const _InsuranceSection();

  @override
  Widget build(BuildContext context) {
    const plans = <_InsurancePlan>[
      _InsurancePlan('Premium Health Shield', '95%', "CNY 380 / month", "Health insurance"),
      _InsurancePlan('Family Care Plus', '87%', "CNY 256 / month", '医疗险'),
      _InsurancePlan('Critical Illness Guard', '82%', "CNY 168 / month", "Critical illness insurance"),
      _InsurancePlan('Global Medical Elite', '78%', "CNY 1,280 / year", '全球医疗'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PageSectionTitle(title: '保险服务'.tr),
        const SizedBox(height: 5),
        const Text(
          "Coverage options matched to your health needs.",
          style: TextStyle(color: VvewellColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 10),
        ...plans.map(
          (plan) => Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: _InsurancePlanCard(plan: plan),
          ),
        ),
        const SizedBox(height: 2),
        _SurfaceCard(
          color: VvewellColors.softTeal,
          padding: const EdgeInsets.all(14),
          child: const Row(
            children: [
              _SoftIcon(
                icon: Icons.health_and_safety_outlined,
                color: VvewellColors.primary,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Coverage matching",
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 3),
                    Text(
                      "AI suggests options using your health profile and risk information.",
                      style: TextStyle(
                        color: VvewellColors.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              _SmallBadge(label: "Find options"),
            ],
          ),
        ),
      ],
    );
  }
}

class _InsurancePlan {
  const _InsurancePlan(this.title, this.score, this.price, this.type);

  final String title;
  final String score;
  final String price;
  final String type;
}

class _InsurancePlanCard extends StatelessWidget {
  const _InsurancePlanCard({required this.plan});

  final _InsurancePlan plan;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      padding: const EdgeInsets.all(13),
      child: Row(
        children: [
          Container(
            width: 47,
            height: 47,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: VvewellColors.softTeal,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              plan.score,
              style: const TextStyle(
                color: VvewellColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.title.tr,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  plan.type.tr,
                  style: const TextStyle(
                    color: VvewellColors.muted,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: const [
                    _SmallBadge(label: "Medical coverage", muted: true),
                    SizedBox(width: 5),
                    _SmallBadge(label: "Critical illness coverage", muted: true),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                plan.price,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 30,
                child: ElevatedButton(
                  onPressed: () {},
                  child: const Text("Apply now"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExclusiveServiceSection extends StatelessWidget {
  const _ExclusiveServiceSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _PageSectionTitle(title: "Personal care services"),
        const SizedBox(height: 10),
        _SurfaceCard(
          color: VvewellColors.softTeal,
          padding: const EdgeInsets.all(14),
          child: const Row(
            children: [
              _SoftIcon(
                icon: Icons.support_agent_outlined,
                color: VvewellColors.primary,
              ),
              SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Personal care coordinator",
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 3),
                    Text(
                      "Ongoing support, appointment assistance and health follow-up.",
                      style: TextStyle(
                        color: VvewellColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              _SmallBadge(label: "Ask about care"),
            ],
          ),
        ),
        const SizedBox(height: 9),
        const _ServiceHistoryRow(
          title: "Family doctor service",
          subtitle: "2026-08-05 · Visit arranged",
          price: '¥3,500',
        ),
        const SizedBox(height: 8),
        const _ServiceHistoryRow(
          title: "Specialist consultation",
          subtitle: "2026-08-03 · Appointment confirmed",
          price: '¥12,000',
        ),
        const SizedBox(height: 8),
        const _ServiceHistoryRow(
          title: "Referral service",
          subtitle: "2026-07-28 · Urgent referral",
          price: '¥8,800',
        ),
      ],
    );
  }
}

class _ServiceHistoryRow extends StatelessWidget {
  const _ServiceHistoryRow({
    required this.title,
    required this.subtitle,
    required this.price,
  });

  final String title;
  final String subtitle;
  final String price;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const _SoftIcon(
            icon: Icons.schedule_outlined,
            color: VvewellColors.muted,
            size: 37,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: VvewellColors.muted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Text(
            price,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({
    required this.onOpenDevices,
    required this.familyProfileController,
  });

  final VoidCallback onOpenDevices;
  final FamilyProfileController familyProfileController;

  @override
  Widget build(BuildContext context) {
    void notice(String message) => ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message.tr)));
    return ListView(
      padding: const EdgeInsets.only(bottom: 28),
      children: [
        _VvewellHeader(familyProfileController: familyProfileController),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
          child: _ProfileMemberSummary(controller: familyProfileController),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _ProfileMenuGroup(
            title: '家庭与健康'.tr,
            items: [
              _ProfileMenuItem(
                Icons.groups_outlined,
                '家庭成员管理'.tr,
                () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        FamilyMembersPage(controller: familyProfileController),
                  ),
                ),
              ),
              _ProfileMenuItem(
                Icons.favorite_border,
                '健康档案'.tr,
                () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        HealthRecordPage(controller: familyProfileController),
                  ),
                ),
              ),
              _ProfileMenuItem(
                Icons.smartphone_outlined,
                '设备管理'.tr,
                onOpenDevices,
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _ProfileMenuGroup(
            title: '订单与权益'.tr,
            items: [
              _ProfileMenuItem(
                Icons.shopping_bag_outlined,
                '我的订单'.tr,
                () => Get.toNamed(AlRoutes.orders),
              ),
              _ProfileMenuItem(
                Icons.workspace_premium_outlined,
                '我的权益'.tr,
                () => Get.toNamed(AlRoutes.benefits),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _ProfileMenuGroup(
            title: '设置'.tr,
            items: [
              _ProfileMenuItem(
                Icons.notifications_none_rounded,
                '通知设置'.tr,
                () => Get.toNamed(AlRoutes.notificationSettings),
              ),
              _ProfileMenuItem(
                Icons.language_outlined,
                '${'语言'.tr} · ${Get.locale?.languageCode == 'en' ? 'English' : '简体中文'.tr}',
                Get.find<AppLanguageController>().toggle,
              ),
              _ProfileMenuItem(
                Icons.shield_outlined,
                '隐私与安全'.tr,
                () => notice('隐私与安全入口已准备就绪'),
              ),
              _ProfileMenuItem(
                Icons.help_outline,
                '帮助与反馈'.tr,
                () => notice('帮助与反馈入口已准备就绪'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _SurfaceCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _ProfileMenuRow(
                  item: _ProfileMenuItem(
                    Icons.info_outline,
                    '关于我们'.tr,
                    () => notice('关于我们入口已准备就绪'),
                  ),
                ),
                const Divider(height: 1),
                _ProfileMenuRow(
                  item: _ProfileMenuItem(
                    Icons.logout_rounded,
                    '退出登录'.tr,
                    () => notice('退出登录入口已准备就绪'),
                    destructive: true,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 36),
        Column(
          children: [
            Text(
              'Vvewell 家庭健康管家'.tr,
              style: const TextStyle(color: VvewellColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Text(
              '版本 1.0.0'.tr,
              style: const TextStyle(color: Color(0xFFACC0BD), fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }
}

class _ProfileMemberSummary extends StatelessWidget {
  const _ProfileMemberSummary({required this.controller});

  final FamilyProfileController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final member = controller.activeMember;
        return _SurfaceCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                color: VvewellColors.softTeal,
                child: Row(
                  children: [
                    const _ProfileAvatar(),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            member.name.tr,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            member.isSelf ? '本人档案'.tr : member.relationship,
                            style: const TextStyle(
                              color: VvewellColors.muted,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _SmallBadge(label: '家庭健康成员'.tr),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: "Switch family member",
                      onPressed: () =>
                          showFamilyMemberSwitcher(context, controller),
                      icon: const Icon(Icons.swap_horiz),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const Icon(
                      Icons.monitor_heart_outlined,
                      color: VvewellColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '健康评分'.tr,
                            style: const TextStyle(
                              color: VvewellColors.muted,
                              fontSize: 13,
                            ),
                          ),
                          if (member.yesterdayHealthScore != null &&
                              member.healthScore > 0) ...[
                            const SizedBox(height: 3),
                            Text(
                              _scoreDeltaText(
                                member.healthScore -
                                    member.yesterdayHealthScore!,
                              ),
                              style: TextStyle(
                                color:
                                    member.healthScore >=
                                        member.yesterdayHealthScore!
                                    ? VvewellColors.success
                                    : VvewellColors.warning,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Text(
                      member.healthScore == 0 ? '--' : '${member.healthScore}',
                      style: const TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      '/100',
                      style: TextStyle(
                        color: VvewellColors.success,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

String _scoreDeltaText(int delta) {
  final english = Get.locale?.languageCode == 'en';
  if (delta == 0) return english ? 'No change from yesterday' : '与昨天持平';
  final amount = delta.abs();
  if (english) {
    return delta > 0
        ? '$amount points higher than yesterday'
        : '$amount points lower than yesterday';
  }
  return delta > 0 ? '较昨天增加 $amount 分' : '较昨天减少 $amount 分';
}

class _ProfileMenuGroup extends StatelessWidget {
  const _ProfileMenuGroup({required this.title, required this.items});

  final String title;
  final List<_ProfileMenuItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 9),
          child: Text(
            title,
            style: const TextStyle(
              color: VvewellColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        _SurfaceCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: List.generate(
              items.length,
              (index) => Column(
                children: [
                  _ProfileMenuRow(item: items[index]),
                  if (index != items.length - 1) const Divider(height: 1),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileMenuItem {
  const _ProfileMenuItem(
    this.icon,
    this.label,
    this.onTap, {
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;
}

class _ProfileMenuRow extends StatelessWidget {
  const _ProfileMenuRow({required this.item});

  final _ProfileMenuItem item;

  @override
  Widget build(BuildContext context) {
    final color = item.destructive
        ? VvewellColors.error
        : VvewellColors.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 15),
          child: Row(
            children: [
              _SoftIcon(icon: item.icon, color: color),
              const SizedBox(width: 13),
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 2,
                  style: TextStyle(
                    color: item.destructive
                        ? VvewellColors.error
                        : VvewellColors.foreground,
                    fontSize: 14,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF9BB1AD)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.onTap,
    this.borderColor = VvewellColors.border,
    this.borderWidth = 1,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final VoidCallback? onTap;
  final Color borderColor;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final body = Container(
      decoration: BoxDecoration(
        color: color ?? VvewellColors.surface,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08152E2B),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
    if (onTap == null) return body;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(21),
        child: body,
      ),
    );
  }
}

class _InsetCard extends StatelessWidget {
  const _InsetCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VvewellColors.surface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: VvewellColors.border),
      ),
      child: child,
    );
  }
}

class _SoftIcon extends StatelessWidget {
  const _SoftIcon({required this.icon, required this.color, this.size = 44});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(size * .3),
      ),
      child: Icon(icon, color: color, size: size * .5),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 8,
        child: Stack(
          children: [
            Positioned.fill(child: Container(color: const Color(0xFFE9EEEE))),
            FractionallySizedBox(
              widthFactor: progress,
              child: Container(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallBadge extends StatelessWidget {
  const _SmallBadge({required this.label, this.muted = false});

  final String label;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: muted ? const Color(0xFFEAF0EF) : VvewellColors.primary,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: muted ? VvewellColors.muted : Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
