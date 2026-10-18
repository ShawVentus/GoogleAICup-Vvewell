import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alloop/web/web_cloud.dart';
import 'package:alloop/web/web_records.dart';
import 'package:alloop/main_web.dart';

void main() {
  tearDown(() => WebCloud.instance.clear());

  testWidgets('empty cloud records never substitute sample values', (tester) async {
    WebCloud.instance.clear();
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: WebReadingsPanel())));
    expect(find.textContaining('No uploaded records'), findsOneWidget);
    expect(find.textContaining('72'), findsNothing);
    expect(find.textContaining('98'), findsNothing);
  });

  testWidgets('uploaded record preserves its actual value, source and timestamp', (tester) async {
    WebCloud.instance.readings = [{'id': 'test', 'metric_type': 'heart_rate', 'value': 63,
      'unit': 'bpm', 'source': 'aizo_ring', 'recorded_at': '2026-10-18T00:00:00Z',
      'is_valid': true, 'is_abnormal': false}];
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: WebReadingsPanel())));
    expect(find.text('63 bpm'), findsOneWidget);
    expect(find.textContaining('aizo_ring'), findsOneWidget);
    final local = WebCloud.instance.localReadings({});
    expect(local.single['heart_rate'], 63);
    expect(local.single['is_mock'], 0);
  });

  testWidgets('hardware entry preserves the device routes and explains app requirement', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: WebHardwarePage(title: 'Devices', showDevices: true)));
    expect(find.textContaining('require the mobile app'), findsOneWidget);
    expect(hardwareRoutes.values, containsAll(['AIZO Ring', 'Radar records', 'Thermal camera']));
    expect(find.text('AIZO Ring'), findsOneWidget);
  });

  testWidgets('sign-in has no shared demo credentials or automatic login', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: WebSignIn()));
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(tester.widgetList<TextField>(find.byType(TextField)).every((field) => field.controller!.text.isEmpty), isTrue);
  });
}
