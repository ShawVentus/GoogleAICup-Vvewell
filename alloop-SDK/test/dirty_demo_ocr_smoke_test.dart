import 'dart:io';

import 'package:alloop/features/health_reports/data/medical_ocr_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final imagePath = Platform.environment['OCR_SMOKE_IMAGE'];

  test(
    'dirty demo embedded credentials recognize a real report',
    () async {
      final liveClient = _LiveHttpOverrides().createClient();
      final result = await MedicalOcrService(
        client: liveClient,
      ).recognize(File(imagePath!));

      expect(result.summary, isNotEmpty);
      expect(result.labItems, isNotEmpty);

      final answer = await MedicalOcrService(client: liveClient).consult(
        question: '请概括最需要向医生复核的项目。',
        memberName: '演示成员',
        profileContext: '仅使用本次报告，不补充其他健康事实。',
        report: result,
      );
      expect(answer, isNotEmpty);
    },
    skip: imagePath == null
        ? 'Set OCR_SMOKE_IMAGE to explicitly send a local report image.'
        : false,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

class _LiveHttpOverrides extends HttpOverrides {
  HttpClient createClient() => super.createHttpClient(null);
}
