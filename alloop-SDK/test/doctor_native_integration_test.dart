import 'package:alloop/features/doctor_recommendation/main.dart' as doctor;
import 'package:alloop/foundations/localization/app_localization.dart';
import 'package:alloop/main_web.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  tearDown(Get.reset);

  testWidgets('native shell opens doctor search from Home and Chat', (
    tester,
  ) async {
    Get.testMode = true;
    Get.put(AppLanguageController());
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const WebApp());
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Find a doctor'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(doctor.ChatPage), findsOneWidget);
    expect(find.byKey(const Key('doctor-message')), findsOneWidget);
    expect(find.byKey(const Key('chat-topic-doctor')), findsOneWidget);
    expect(find.byKey(const Key('bottom-nav-2')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('chat-topic-0')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const Key('chat-topic-0')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('doctor-message')), findsNothing);
    await tester.drag(
      find.byKey(const Key('chat-topic-strip')),
      const Offset(500, 0),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const Key('chat-topic-doctor')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('doctor-message')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
