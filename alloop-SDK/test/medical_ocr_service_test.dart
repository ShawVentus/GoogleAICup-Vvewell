import 'package:flutter_test/flutter_test.dart';

import 'package:alloop/features/health_reports/data/embedded_demo_ocr_credentials.dart';
import 'package:flutter/foundation.dart';
import 'package:alloop/features/health_reports/data/medical_ocr_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('parses the structured OCR gateway response', () {
    final result = MedicalOcrResult.fromJson({
      'patientName': '李某',
      'examDate': '2026-07-25',
      'hospital': '深圳市第二人民医院',
      'examType': '血常规',
      'bloodPressure': '',
      'heartRate': '',
      'bloodSugar': '',
      'cholesterol': '',
      'abnormalItems': '中性粒细胞百分数',
      'labItems': [
        {
          'name': '中性粒细胞百分数',
          'result': '78.5',
          'referenceRange': '40-75',
          'unit': '%',
          'flag': 'H',
        },
      ],
      'summary': '识别完成',
    });

    expect(result.examType, '血常规');
    expect(result.examDate, '2026-07-25');
    expect(result.hospital, '深圳市第二人民医院');
    expect(result.abnormalItems, '中性粒细胞百分数');
    expect(result.labItems.single.flag, 'H');
    expect(result.summary, '识别完成');
  });

  test('builds a consultation-ready summary for direct provider JSON', () {
    final result = MedicalOcrResult.fromJson({
      'examType': '血常规',
      'hospital': '演示医院',
      'abnormalItems': '',
      'labItems': [
        {
          'name': '白细胞计数',
          'result': '12.0',
          'referenceRange': '3.5-9.5',
          'unit': '10^9/L',
          'flag': 'H',
        },
      ],
    });

    expect(result.summary, contains('共识别1项指标'));
    expect(result.summary, contains('异常项目：白细胞计数'));
    expect(
      result.toConsultationContext()['labItems'].toString(),
      contains('白细胞计数'),
    );
  });

  test(
    'public web build does not package embedded OCR credentials',
    () async {
      await expectLater(EmbeddedDemoOcrCredentials.load(),
        throwsA(isA<FlutterError>().having((e) => e.toString(), 'missing asset', contains('Unable to load asset'))));
    },
  );
}
