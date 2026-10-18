import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../data/nutrition_demo_repository.dart';
import '../domain/nutrition_models.dart';

class NutritionDemoController extends ChangeNotifier {
  NutritionDemoController({NutritionDemoRepository? repository})
    : _repository = repository ?? NutritionDemoRepository();

  final NutritionDemoRepository _repository;
  final List<NutritionIntakeRecord> _intakes = <NutritionIntakeRecord>[];
  final Set<String> _completedSupplementIds = <String>{'d3', 'omega3'};
  final Map<String, int> _cart = <String, int>{};
  bool _hydrated = false;

  static const supplements = <SupplementItem>[
    SupplementItem(
      id: 'd3',
      name: '维生素 D3',
      dose: '2000 IU',
      timing: '早餐后',
      purpose: '在日照不足或检测提示不足时辅助维持骨骼与免疫健康',
      category: '维生素',
      price: 89,
      originalPrice: 129,
      badge: '热销',
      tone: 0,
      purchased: true,
    ),
    SupplementItem(
      id: 'omega3',
      name: 'Omega-3 鱼油',
      dose: '1000 mg',
      timing: '午餐后',
      purpose: '补充 EPA/DHA；正在使用抗凝药时应先咨询医生',
      category: 'Omega-3',
      price: 159,
      originalPrice: 199,
      badge: '推荐',
      tone: 1,
      purchased: true,
    ),
    SupplementItem(
      id: 'magnesium',
      name: '镁（甘氨酸镁）',
      dose: '200 mg',
      timing: '晚餐后',
      purpose: '补充膳食镁；肾功能异常或正在用药时需先咨询医生',
      category: '镁',
      price: 119,
      originalPrice: 159,
      badge: '',
      tone: 2,
      purchased: true,
    ),
    SupplementItem(
      id: 'k2',
      name: '维生素 K2',
      dose: '100 mcg',
      timing: '早餐后',
      purpose: '与维生素 D 搭配的候选；使用华法林等药物时不应自行补充',
      category: '维生素',
      price: 99,
      originalPrice: 129,
      badge: '',
      tone: 3,
      purchased: true,
    ),
    SupplementItem(
      id: 'melatonin',
      name: '褪黑素',
      dose: '3 mg',
      timing: '睡前 30 分钟',
      purpose: '短期睡眠节律支持候选，不用于替代睡眠呼吸风险评估',
      category: '睡眠',
      price: 69,
      originalPrice: 99,
      badge: '助眠',
      tone: 4,
      purchased: true,
    ),
    SupplementItem(
      id: 'b6',
      name: '维生素 B6',
      dose: '50 mg',
      timing: '早餐后',
      purpose: '参与能量代谢；不建议长期超量使用',
      category: '维生素',
      price: 59,
      originalPrice: 79,
      badge: '',
      tone: 5,
    ),
    SupplementItem(
      id: 'theanine',
      name: 'L-茶氨酸',
      dose: '200 mg',
      timing: '睡前',
      purpose: '作为放松支持候选，效果存在个体差异',
      category: '氨基酸',
      price: 129,
      originalPrice: 159,
      badge: '',
      tone: 6,
    ),
    SupplementItem(
      id: 'vitamin-c',
      name: '维生素 C',
      dose: '1000 mg',
      timing: '早餐后',
      purpose: '饮食不足时的补充候选，不替代蔬果摄入',
      category: '维生素',
      price: 49,
      originalPrice: 79,
      badge: '特惠',
      tone: 7,
    ),
    SupplementItem(
      id: 'zinc',
      name: '锌',
      dose: '25 mg',
      timing: '午餐后',
      purpose: '明确膳食不足时短期补充，避免长期高剂量',
      category: '矿物质',
      price: 79,
      originalPrice: 99,
      badge: '',
      tone: 8,
    ),
    SupplementItem(
      id: 'coq10',
      name: '辅酶 Q10',
      dose: '100 mg',
      timing: '午餐后',
      purpose: '心血管用药人群的候选补充需由医生复核',
      category: '抗氧化',
      price: 199,
      originalPrice: 259,
      badge: '护心',
      tone: 9,
    ),
  ];

  List<NutritionIntakeRecord> get intakes =>
      List<NutritionIntakeRecord>.unmodifiable(_intakes);
  Set<String> get completedSupplementIds =>
      Set<String>.unmodifiable(_completedSupplementIds);
  int get cartCount => _cart.values.fold(0, (sum, quantity) => sum + quantity);
  int get todayCalories =>
      _intakes.fold(0, (total, intake) => total + intake.totals.kcal.round());
  int get purchasedCount => supplements.where((item) => item.purchased).length;
  int get completedPurchasedCount => supplements
      .where(
        (item) => item.purchased && _completedSupplementIds.contains(item.id),
      )
      .length;

  Future<void> hydrate() async {
    if (_hydrated) return;
    _hydrated = true;
    try {
      final rows = await _repository.loadTodayMeals();
      for (final row in rows) {
        final payload = row['analysis'];
        if (payload is! Map) continue;
        final foods = (payload['foods'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map>()
            .map(NutritionFood.fromJson)
            .toList();
        final totals = payload['totals'];
        if (totals is! Map) continue;
        _intakes.add(
          NutritionIntakeRecord(
            id: '${row['recordedAt']}',
            mealType: '${payload['meal'] ?? '餐食'}',
            recordedAt: DateTime.fromMillisecondsSinceEpoch(
              (row['recordedAt'] as num?)?.toInt() ?? 0,
            ),
            photoPath: '${row['photoPath'] ?? ''}',
            foods: foods,
            totals: NutritionTotals.fromJson(totals),
            advice: '${payload['advice'] ?? ''}',
          ),
        );
      }
      notifyListeners();
    } on MissingPluginException {
      // Widget tests and web previews do not register the Android database bridge.
    } on PlatformException {
      // Keep the in-memory demo usable if local persistence is temporarily unavailable.
    } on FormatException {
      // Ignore malformed historical demo rows instead of blocking current capture.
    }
  }

  void addIntake(NutritionIntakeRecord intake) {
    _intakes.insert(0, intake);
    notifyListeners();
  }

  void toggleSupplement(String id) {
    _completedSupplementIds.contains(id)
        ? _completedSupplementIds.remove(id)
        : _completedSupplementIds.add(id);
    notifyListeners();
  }

  void completeAllPurchased() {
    _completedSupplementIds.addAll(
      supplements.where((item) => item.purchased).map((item) => item.id),
    );
    notifyListeners();
  }

  void addToCart(String id) {
    _cart.update(id, (quantity) => quantity + 1, ifAbsent: () => 1);
    notifyListeners();
  }

  String exportIntakesJson() =>
      jsonEncode(_intakes.map((intake) => intake.toAnalysisJson()).toList());
}
