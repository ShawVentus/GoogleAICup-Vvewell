class RecommendationItem {
  RecommendationItem({
    required this.catalogItemId,
    required this.intentCode,
    required this.itemKind,
    required this.title,
    required this.description,
    required this.explanationCodes,
    required this.commercialDisclosure,
    required this.taskId,
    this.taskStatus = 'pending',
    this.dataOrigin = 'REAL',
  });

  final String catalogItemId;
  final String intentCode;
  final String itemKind;
  final String title;
  final String description;
  final List<String> explanationCodes;
  final String? commercialDisclosure;
  final String? taskId;
  String taskStatus;
  String dataOrigin;

  factory RecommendationItem.fromJson(Map<String, dynamic> json) {
    final task = json['task'] is Map
        ? Map<String, dynamic>.from(json['task'] as Map)
        : const <String, dynamic>{};
    return RecommendationItem(
      catalogItemId: json['catalog_item_id']?.toString() ?? '',
      intentCode: json['intent_code']?.toString() ?? '',
      itemKind: json['item_kind']?.toString() ?? 'ADVICE',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      explanationCodes: (json['explanation_codes'] as List? ?? const [])
          .map((value) => value.toString())
          .toList(growable: false),
      commercialDisclosure: json['commercial_disclosure']?.toString(),
      taskId: task['task_id']?.toString(),
      taskStatus: task['status']?.toString() ?? 'pending',
      dataOrigin: json['data_origin']?.toString() ?? 'REAL',
    );
  }
}

class RecommendationPlan {
  const RecommendationPlan({
    required this.decisionId,
    required this.status,
    required this.reasonCode,
    required this.items,
    this.analyzedAt,
    this.cloudSyncedAt,
  });

  final String decisionId;
  final String status;
  final String? reasonCode;
  final List<RecommendationItem> items;
  final DateTime? analyzedAt;
  final DateTime? cloudSyncedAt;
}

abstract interface class RecommendationRepository {
  Future<RecommendationPlan?> load();
  Future<void> recordImpression(
    String decisionId,
    RecommendationItem item, {
    required String sessionId,
    required int displayedRank,
  });
  Future<void> updateTask(
    RecommendationItem item,
    String status, {
    required String sessionId,
    required int displayedRank,
  });
}
