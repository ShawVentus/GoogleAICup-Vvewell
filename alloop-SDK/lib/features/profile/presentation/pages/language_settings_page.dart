import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../foundations/localization/app_localization.dart';
import '../../../../foundations/ui/vvewell_theme.dart';

class LanguageSettingsPage extends StatelessWidget {
  const LanguageSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AppLanguageController>();
    return Obx(() {
      controller.currentLocale.value;
      return Scaffold(
        appBar: AppBar(title: Text('应用语言'.tr)),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: VvewellColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: VvewellColors.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '应用语言'.tr,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<bool>(
                    segments: [
                      ButtonSegment(value: false, label: Text('简体中文'.tr)),
                      const ButtonSegment(value: true, label: Text('English')),
                    ],
                    selected: {controller.isEnglish},
                    onSelectionChanged: (selection) =>
                        controller.setEnglish(selection.first),
                    showSelectedIcon: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
