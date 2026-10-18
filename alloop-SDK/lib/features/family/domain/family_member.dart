enum HealthTagStatus { confirmed, predicted, inferred, unknown }

class FamilyHealthTag {
  const FamilyHealthTag({
    required this.id,
    required this.category,
    required this.label,
    required this.value,
    required this.status,
    required this.source,
    required this.updatedAt,
    required this.purpose,
    this.confidence,
    this.hiddenFromPersonalization = false,
  });

  final String id;
  final String category;
  final String label;
  final String value;
  final HealthTagStatus status;
  final String source;
  final DateTime updatedAt;
  final String purpose;
  final double? confidence;
  final bool hiddenFromPersonalization;

  FamilyHealthTag copyWith({
    HealthTagStatus? status,
    bool? hiddenFromPersonalization,
  }) {
    return FamilyHealthTag(
      id: id,
      category: category,
      label: label,
      value: value,
      status: status ?? this.status,
      source: source,
      updatedAt: updatedAt,
      purpose: purpose,
      confidence: confidence,
      hiddenFromPersonalization:
          hiddenFromPersonalization ?? this.hiddenFromPersonalization,
    );
  }
}

class FamilyMember {
  const FamilyMember({
    required this.id,
    required this.name,
    required this.relationship,
    required this.gender,
    required this.birthYear,
    required this.healthScore,
    required this.tags,
    this.yesterdayHealthScore,
    this.isSelf = false,
  });

  final String id;
  final String name;
  final String relationship;
  final String gender;
  final int birthYear;
  final int healthScore;
  final int? yesterdayHealthScore;
  final List<FamilyHealthTag> tags;
  final bool isSelf;

  int ageAt(int year) => year - birthYear;

  FamilyMember copyWith({List<FamilyHealthTag>? tags}) {
    return FamilyMember(
      id: id,
      name: name,
      relationship: relationship,
      gender: gender,
      birthYear: birthYear,
      healthScore: healthScore,
      yesterdayHealthScore: yesterdayHealthScore,
      tags: tags ?? this.tags,
      isSelf: isSelf,
    );
  }
}
