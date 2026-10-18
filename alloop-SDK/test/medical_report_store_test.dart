import 'package:alloop/features/health_reports/data/medical_report_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps report context isolated by family member', () {
    final store = MedicalReportStore();
    final report = MedicalReportResult(
      reportType: '检验报告',
      institution: '演示医院',
      reportDate: DateTime(2026, 8, 4),
      summary: '演示摘要',
      photoPath: '/tmp/report.jpg',
      isDemo: false,
    );

    store.add('member-a', report);

    expect(store.latestFor('member-a'), same(report));
    expect(store.reportsFor('member-b'), isEmpty);
  });
}
