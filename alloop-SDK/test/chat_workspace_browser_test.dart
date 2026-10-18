import 'package:alloop/features/doctor_recommendation/main.dart' as doctor;
import 'package:alloop/features/main/home_page.dart';
import 'package:alloop/features/main/chat_composer.dart';
import 'package:alloop/features/nutrition_demo/presentation/nutrition_capture_sheet.dart';
import 'package:alloop/foundations/localization/app_localization.dart';
import 'package:alloop/main_web.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  setUp(() {
    Get.testMode = true;
    Get.put(
      AppLanguageController()..currentLocale.value = const Locale('en', 'US'),
    );
  });
  tearDown(Get.reset);

  testWidgets('doctor and existing tools share the primary Chat workspace', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final originalError = FlutterError.onError;
    FlutterError.onError = (details) {
      print('WORKSPACE ERROR: ${details.exceptionAsString()} ${details.stack}');
      originalError?.call(details);
    };
    addTearDown(() => FlutterError.onError = originalError);
    await tester.pumpWidget(const WebApp());
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Find a doctor'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(Get.currentRoute, '/');
    expect(find.byType(doctor.ChatPage), findsOneWidget);
    expect(
      tester.widget<doctor.ChatPage>(find.byType(doctor.ChatPage)).showTopChips,
      isFalse,
    );
    expect(find.byType(doctor.TopChips), findsNothing);
    expect(find.byType(ChatComposer), findsOneWidget);
    final doctorInput = tester.getRect(find.byKey(const Key('doctor-message')));
    expect(find.byKey(const Key('bottom-nav-2')), findsOneWidget);

    await tester.tap(find.byKey(const Key('chat-topic-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      find.byKey(const Key('report-consultation-welcome-upload')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('report-consultation-upload')), findsOneWidget);
    expect(find.byType(ChatComposer), findsOneWidget);
    final reportInput = tester.getRect(
      find.descendant(
        of: find.byType(ChatComposer),
        matching: find.byType(TextField),
      ),
    );
    expect((doctorInput.top - reportInput.top).abs(), lessThan(1));

    await tester.scrollUntilVisible(
      find.byKey(const Key('chat-topic-2')),
      120,
      scrollable: find.descendant(
        of: find.byKey(const Key('chat-topic-strip')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('chat-topic-2')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byIcon(Icons.add_a_photo_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(NutritionCaptureSheet), findsOneWidget);
    Get.back<void>();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.scrollUntilVisible(
      find.byKey(const Key('chat-topic-4')),
      120,
      scrollable: find.descendant(
        of: find.byKey(const Key('chat-topic-strip')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('chat-topic-4')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Ask about medication safety'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Returning through Home selects the existing doctor conversation.
    await tester.tap(find.byKey(const Key('bottom-nav-0')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Find a doctor'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(doctor.ChatPage), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('legacy doctor link opens Chat inside the complete app shell', (
    tester,
  ) async {
    await tester.pumpWidget(
      GetMaterialApp(
        locale: const Locale('en', 'US'),
        translations: VvewellTranslations(),
        home: const HomePage(initialTabIndex: 2),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(doctor.ChatPage), findsOneWidget);
    expect(find.byKey(const Key('bottom-nav-0')), findsOneWidget);
    expect(find.byKey(const Key('bottom-nav-4')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
