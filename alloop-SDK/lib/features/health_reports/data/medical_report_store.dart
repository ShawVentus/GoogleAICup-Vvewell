import 'package:flutter/foundation.dart';

import 'medical_ocr_service.dart';

class MedicalReportResult {
  const MedicalReportResult({
    required this.reportType,
    required this.institution,
    required this.reportDate,
    required this.summary,
    required this.photoPath,
    required this.isDemo,
    this.ocrResult,
  });

  final String reportType;
  final String institution;
  final DateTime? reportDate;
  final String summary;
  final String? photoPath;
  final bool isDemo;
  final MedicalOcrResult? ocrResult;
}

/// In-memory, member-scoped report context for the hackathon consultation demo.
/// This is intentionally not described as durable persistence.
class MedicalReportStore extends ChangeNotifier {
  final Map<String, List<MedicalReportResult>> _reportsByMember = {};

  List<MedicalReportResult> reportsFor(String memberId) =>
      List<MedicalReportResult>.unmodifiable(
        _reportsByMember[memberId] ?? const <MedicalReportResult>[],
      );

  MedicalReportResult? latestFor(String memberId) {
    final reports = _reportsByMember[memberId];
    return reports == null || reports.isEmpty ? null : reports.first;
  }

  void add(String memberId, MedicalReportResult report) {
    _reportsByMember.putIfAbsent(memberId, () => []).insert(0, report);
    notifyListeners();
  }
}
