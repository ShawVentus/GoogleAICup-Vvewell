import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alloop/features/doctor_recommendation/main.dart' as doctor;

void main() {
  testWidgets(
    'Hospital and physician cards show English without Chinese subtitles',
    (tester) async {
      final hospital = doctor.HospitalCardData({
        'name_en': 'Shenzhen Hospital',
        'name_zh': '深圳医院',
        'district_en': 'Futian District',
        'feature': {'en': 'International patient services', 'zh': '国际患者服务'},
        'doctors': [
          {
            'doctor_id': 'test',
            'name_en': 'Li Ming',
            'name_zh': '李明',
            'title': {'en': 'Chief Physician', 'zh': '主任医师'},
            'dept': {'en': 'Oncology', 'zh': '肿瘤科'},
            'matched': [
              {'en': 'Lung cancer', 'zh': '肺癌'},
            ],
          },
        ],
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: doctor.HospitalCard(index: 1, h: hospital),
            ),
          ),
        ),
      );
      expect(find.text('Li Ming'), findsOneWidget);
      expect(find.text('Lung cancer'), findsOneWidget);
      expect(find.text('Shenzhen Hospital'), findsOneWidget);
      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        expect(RegExp(r'[\u4e00-\u9fff]').hasMatch(text.data ?? ''), isFalse);
      }
    },
  );
}
