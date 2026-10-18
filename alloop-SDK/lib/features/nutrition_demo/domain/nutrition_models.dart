class NutritionTotals {
  const NutritionTotals({
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
    required this.sodium,
  });

  final double kcal;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final double sodium;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'kcal': kcal,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
    'fiber': fiber,
    'sodium': sodium,
  };

  factory NutritionTotals.fromJson(Map<dynamic, dynamic> json) {
    double number(String key) => (json[key] as num?)?.toDouble() ?? 0;
    return NutritionTotals(
      kcal: number('kcal'),
      protein: number('protein'),
      carbs: number('carbs'),
      fat: number('fat'),
      fiber: number('fiber'),
      sodium: number('sodium'),
    );
  }
}

class NutritionFood {
  const NutritionFood({
    required this.name,
    required this.grams,
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
    required this.sodium,
  });

  final String name;
  final double grams;
  final double kcal;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final double sodium;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name,
    'grams': grams,
    'kcal': kcal,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
    'fiber': fiber,
    'sodium': sodium,
  };

  factory NutritionFood.fromJson(Map<dynamic, dynamic> json) {
    double number(String key) => (json[key] as num?)?.toDouble() ?? 0;
    return NutritionFood(
      name: '${json['name'] ?? '未识别食物'}',
      grams: number('grams'),
      kcal: number('kcal'),
      protein: number('protein'),
      carbs: number('carbs'),
      fat: number('fat'),
      fiber: number('fiber'),
      sodium: number('sodium'),
    );
  }
}

class NutritionIntakeRecord {
  const NutritionIntakeRecord({
    required this.id,
    required this.mealType,
    required this.recordedAt,
    required this.photoPath,
    required this.foods,
    required this.totals,
    required this.advice,
  });

  final String id;
  final String mealType;
  final DateTime recordedAt;
  final String photoPath;
  final List<NutritionFood> foods;
  final NutritionTotals totals;
  final String advice;

  String get summary =>
      '${totals.kcal.round()} kcal · Protein ${totals.protein.toStringAsFixed(1)} g';

  Map<String, dynamic> toAnalysisJson() => <String, dynamic>{
    'meal': mealType,
    'foods': foods.map((food) => food.toJson()).toList(),
    'totals': totals.toJson(),
    'advice': advice,
  };
}

class SupplementItem {
  const SupplementItem({
    required this.id,
    required this.name,
    required this.dose,
    required this.timing,
    required this.purpose,
    required this.category,
    required this.price,
    required this.originalPrice,
    required this.badge,
    required this.tone,
    this.purchased = false,
  });

  final String id;
  final String name;
  final String dose;
  final String timing;
  final String purpose;
  final String category;
  final int price;
  final int originalPrice;
  final String badge;
  final int tone;
  final bool purchased;
}
