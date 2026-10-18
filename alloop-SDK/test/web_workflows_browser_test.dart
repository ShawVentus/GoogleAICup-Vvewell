import 'dart:convert';
import 'dart:typed_data';
import 'package:alloop/features/nutrition_demo/presentation/nutrition_capture_sheet.dart';
import 'package:alloop/features/nutrition_demo/presentation/nutrition_demo_controller.dart';
import 'package:alloop/features/nutrition_demo/domain/nutrition_models.dart';
import 'package:alloop/features/women_health/data/women_health_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

class BrowserMemoryFile extends XFile {
  BrowserMemoryFile(this.bytes)
    : super.fromData(bytes, mimeType: 'image/png', name: 'test-meal.png');
  final Uint8List bytes;
  @override
  Future<Uint8List> readAsBytes() async => bytes;
}

class BrowserMemoryPicker extends ImagePickerPlatform {
  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    return BrowserMemoryFile(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aN1sAAAAASUVORK5CYII=',
      ),
    );
  }
}

void main() {
  test(
    'browser cycle recording does not call the Android SQLite channel',
    () async {
      final repository = WomenHealthRepository();
      final before = (await repository.loadRecords()).length;
      await repository.savePeriod(
        start: DateTime(2026, 10, 1),
        flow: 'test',
        symptoms: '',
        note: 'browser test',
      );
      final records = await repository.loadRecords();
      expect(records.length, before + 1);
      expect(records.last['record_type'], 'period');
      expect(await repository.hasDeviceTrend(), isFalse);
    },
  );

  testWidgets(
    'browser meal photo preview and original demo confirmation avoid native files',
    (tester) async {
      final previous = ImagePickerPlatform.instance;
      final picker = BrowserMemoryPicker();
      ImagePickerPlatform.instance = picker;
      addTearDown(() => ImagePickerPlatform.instance = previous);
      final controller = NutritionDemoController();
      addTearDown(controller.dispose);
      NutritionIntakeRecord? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showNutritionCaptureSheet(
                    context,
                    controller: controller,
                  );
                },
                child: const Text('Open meal log'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open meal log'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('pick-meal-photo')));
      await tester.tap(find.byKey(const Key('pick-meal-photo')));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.ensureVisible(find.byKey(const Key('save-meal-analysis')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ElevatedButton>(find.byKey(const Key('save-meal-analysis')))
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.byKey(const Key('save-meal-analysis')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(result, isNotNull);
      expect(result!.photoPath, isEmpty);
      expect(result!.foods, isNotEmpty);
    },
  );
}
