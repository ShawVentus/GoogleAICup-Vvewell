import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../foundations/ui/vvewell_theme.dart';
import '../data/nutrition_demo_repository.dart';
import '../domain/nutrition_models.dart';
import 'nutrition_demo_controller.dart';

Future<NutritionIntakeRecord?> showNutritionCaptureSheet(
  BuildContext context, {
  required NutritionDemoController controller,
  String initialMeal = '午餐',
}) {
  return showModalBottomSheet<NutritionIntakeRecord>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) =>
        NutritionCaptureSheet(controller: controller, initialMeal: initialMeal),
  );
}

class NutritionCaptureSheet extends StatefulWidget {
  const NutritionCaptureSheet({
    super.key,
    required this.controller,
    this.initialMeal = '午餐',
  });

  final NutritionDemoController controller;
  final String initialMeal;

  @override
  State<NutritionCaptureSheet> createState() => _NutritionCaptureSheetState();
}

class _NutritionCaptureSheetState extends State<NutritionCaptureSheet> {
  final _picker = ImagePicker();
  final _repository = NutritionDemoRepository();
  File? _photo;
  Uint8List? _webPhoto;
  bool _saving = false;
  late String _meal = widget.initialMeal;
  late List<_EditableFood> _foods = _mockFoodsFor(_meal);

  static const _mealTypes = <String>['早餐', '午餐', '晚餐', '加餐'];

  Future<void> _pick(ImageSource source) async {
    final file = await _picker.pickImage(
      source: source,
      imageQuality: 82,
      maxWidth: 1600,
    );
    if (file == null) return;
    if (kIsWeb) {
      final bytes = await file.readAsBytes();
      if (mounted) setState(() => _webPhoto = bytes);
    } else if (mounted) {
      setState(() => _photo = File(file.path));
    }
  }

  NutritionTotals get _totals {
    double total(double Function(_EditableFood food) value) =>
        _foods.fold(0, (sum, food) => sum + value(food));
    return NutritionTotals(
      kcal: total((food) => food.kcal),
      protein: total((food) => food.protein),
      carbs: total((food) => food.carbs),
      fat: total((food) => food.fat),
      fiber: total((food) => food.fiber),
      sodium: total((food) => food.sodium),
    );
  }

  Future<void> _save() async {
    if (_photo == null && _webPhoto == null) return;
    setState(() => _saving = true);
    final now = DateTime.now();
    var photoPath = kIsWeb ? '' : _photo!.path;
    final totals = _totals;
    final record = NutritionIntakeRecord(
      id: 'meal-${now.microsecondsSinceEpoch}',
      mealType: _meal,
      recordedAt: now,
      photoPath: photoPath,
      foods: _foods.map((food) => food.toFood()).toList(),
      totals: totals,
      advice: _adviceFor(totals),
    );

    if (kIsWeb) {
      widget.controller.addIntake(record);
      if (mounted) Navigator.pop(context, record);
      return;
    }
    try {
      await _repository.cleanup();
      photoPath = await _repository.copyPhoto(_photo!);
      final persisted = NutritionIntakeRecord(
        id: record.id,
        mealType: record.mealType,
        recordedAt: record.recordedAt,
        photoPath: photoPath,
        foods: record.foods,
        totals: record.totals,
        advice: record.advice,
      );
      await _repository.saveMeal(photoPath, persisted.toAnalysisJson());
      widget.controller.addIntake(persisted);
      if (mounted) Navigator.pop(context, persisted);
    } on MissingPluginException {
      widget.controller.addIntake(record);
      if (mounted) Navigator.pop(context, record);
    } on PlatformException {
      widget.controller.addIntake(record);
      if (mounted) Navigator.pop(context, record);
    } on FileSystemException catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('图片保存失败：@error'.trParams({'error': error.message})),
        ),
      );
    }
  }

  void _changeMeal(String meal) {
    setState(() {
      _meal = meal;
      _foods = _mockFoodsFor(meal);
    });
  }

  @override
  Widget build(BuildContext context) {
    final totals = _totals;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '记录今天的餐食'.tr,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                '选择餐次并上传照片。营养识别为可编辑的 Mock 数据，确认后写入饮食摄入。'.tr,
                style: const TextStyle(
                  color: VvewellColors.muted,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _mealTypes
                    .map(
                      (meal) => ChoiceChip(
                        key: Key('meal-type-$meal'),
                        label: Text(meal.tr),
                        selected: _meal == meal,
                        onSelected: (_) => _changeMeal(meal),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
              if (_photo == null && _webPhoto == null)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pick(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: Text('拍照'.tr),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('pick-meal-photo'),
                        onPressed: () => _pick(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: Text('从相册选择'.tr),
                      ),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: kIsWeb
                          ? Image.memory(
                              _webPhoto!,
                              height: 180,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            )
                          : Image.file(
                              _photo!,
                              height: 180,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                    ),
                    TextButton.icon(
                      onPressed: () => setState(() {
                        _photo = null;
                        _webPhoto = null;
                      }),
                      icon: const Icon(Icons.refresh),
                      label: Text('重新选择'.tr),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              Text(
                'Mock 营养识别'.tr,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '可修改识别出的份量，营养合计会同步更新。'.tr,
                style: const TextStyle(
                  color: VvewellColors.muted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              ..._foods.map(
                (food) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(food.name.tr),
                  subtitle: Text(
                    '@calories kcal · 蛋白 @protein g'.trParams({
                      'calories': '${food.kcal.round()}',
                      'protein': food.protein.toStringAsFixed(1),
                    }),
                  ),
                  trailing: SizedBox(
                    width: 86,
                    child: TextFormField(
                      initialValue: food.grams.round().toString(),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(suffixText: 'g'),
                      onChanged: (value) {
                        final grams = double.tryParse(value);
                        if (grams != null && grams > 0) {
                          setState(() => food.scale(grams));
                        }
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: VvewellColors.softBlue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    _NutrientValue('热量', '${totals.kcal.round()} kcal'),
                    _NutrientValue(
                      '蛋白质',
                      '${totals.protein.toStringAsFixed(1)} g',
                    ),
                    _NutrientValue(
                      '碳水',
                      '${totals.carbs.toStringAsFixed(1)} g',
                    ),
                    _NutrientValue('脂肪', '${totals.fat.toStringAsFixed(1)} g'),
                    _NutrientValue(
                      '膳食纤维',
                      '${totals.fiber.toStringAsFixed(1)} g',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: VvewellColors.softOrange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _adviceFor(totals).tr,
                  style: const TextStyle(fontSize: 12, height: 1.45),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  key: const Key('save-meal-analysis'),
                  onPressed: (_photo == null && _webPhoto == null) || _saving
                      ? null
                      : _save,
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text((_saving ? '保存中…' : '确认并记录到饮食摄入').tr),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NutrientValue extends StatelessWidget {
  const _NutrientValue(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.tr,
            style: const TextStyle(color: VvewellColors.muted, fontSize: 11),
          ),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _EditableFood {
  _EditableFood(
    this.name,
    this.grams,
    this.kcal,
    this.protein,
    this.carbs,
    this.fat,
    this.fiber,
    this.sodium,
  );

  final String name;
  double grams;
  double kcal;
  double protein;
  double carbs;
  double fat;
  double fiber;
  double sodium;

  void scale(double newGrams) {
    final factor = newGrams / grams;
    grams = newGrams;
    kcal *= factor;
    protein *= factor;
    carbs *= factor;
    fat *= factor;
    fiber *= factor;
    sodium *= factor;
  }

  NutritionFood toFood() => NutritionFood(
    name: name,
    grams: grams,
    kcal: kcal,
    protein: protein,
    carbs: carbs,
    fat: fat,
    fiber: fiber,
    sodium: sodium,
  );
}

List<_EditableFood> _mockFoodsFor(String meal) => switch (meal) {
  '早餐' => <_EditableFood>[
    _EditableFood('燕麦粥', 180, 126, 4.5, 23, 2.5, 3.2, .1),
    _EditableFood('水煮蛋', 55, 78, 6.5, .6, 5.3, 0, .07),
    _EditableFood('蓝莓', 80, 46, .6, 11.5, .2, 1.9, .01),
  ],
  '晚餐' => <_EditableFood>[
    _EditableFood('烤三文鱼', 120, 250, 26, 0, 15, 0, .15),
    _EditableFood('红薯', 150, 129, 2.4, 30, .2, 4.5, .06),
    _EditableFood('菠菜', 100, 23, 2.9, 3.6, .4, 2.2, .08),
  ],
  '加餐' => <_EditableFood>[
    _EditableFood('无糖酸奶', 150, 95, 8.5, 9, 2.5, 0, .09),
    _EditableFood('混合坚果', 20, 121, 4, 4, 10, 2, .01),
  ],
  _ => <_EditableFood>[
    _EditableFood('糙米饭', 150, 174, 3.9, 36, 1.4, 2.7, .01),
    _EditableFood('鸡胸肉', 100, 165, 31, 0, 3.6, 0, .07),
    _EditableFood('西兰花', 100, 34, 2.8, 7, .4, 2.6, .03),
  ],
};

String _adviceFor(NutritionTotals totals) {
  if (totals.protein < 20) {
    return '本餐蛋白质相对较少，可结合全天摄入补充豆制品、蛋、奶、鱼或瘦肉。该结果仅用于饮食记录。';
  }
  if (totals.fiber < 5) {
    return '蛋白质较充足，膳食纤维偏少，可增加蔬菜、全谷物或适量水果。该结果不是医疗或减重处方。';
  }
  return '本餐包含主食、优质蛋白和蔬菜，结构较均衡；仍需结合全天饮食、多样性与个人禁忌综合判断。';
}
