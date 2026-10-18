import 'dart:async';
import 'dart:convert';
import 'package:alloop/features/doctor_recommendation/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

class StreamingDoctorClient extends http.BaseClient {
  final streams = <StreamController<List<int>>>[];
  final bodies = <Map<String, dynamic>>[];
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    expect(request.url.path, '/api/chat/stream');
    bodies.add(
      jsonDecode(utf8.decode(await request.finalize().toBytes()))
          as Map<String, dynamic>,
    );
    final stream = StreamController<List<int>>();
    streams.add(stream);
    return http.StreamedResponse(
      stream.stream,
      200,
      headers: {'content-type': 'text/event-stream'},
    );
  }

  void emit(String event, Map<String, dynamic> body) {
    final data = utf8.encode('event: $event\ndata: ${jsonEncode(body)}\n\n');
    // Network chunks need not align with UTF-8 text or SSE lines.
    streams.last.add(data.sublist(0, data.length ~/ 2));
    streams.last.add(data.sublist(data.length ~/ 2));
  }

  @override
  void close() {
    for (final s in streams) {
      if (!s.isClosed) s.close();
    }
  }
}

void main() {
  testWidgets(
    'doctor chat streams English cards and sends history with shown IDs',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final client = StreamingDoctorClient();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatPage(
              client: client,
              endpoint: Uri.parse('https://preview.example/api/chat/stream'),
            ),
          ),
        ),
      );
      await tester.enterText(find.byKey(const Key('doctor-patient-age')), '38');
      await tester.tap(find.byKey(const Key('doctor-patient-sex')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Female').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('doctor-message')),
        '38F, US, uterine fibroids. Please recommend a doctor.',
      );
      await tester.runAsync(() async {
        await tester.testTextInput.receiveAction(TextInputAction.send);
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(client.bodies.length, 1);
      expect(client.bodies.first['current_country'], 'OTHER');
      expect(client.bodies.first['age'], 38);
      expect(client.bodies.first['sex_at_birth'], 'F');
      client.emit('status', {'text': 'Finding matching doctors…'});
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Finding matching doctors…'), findsOneWidget);
      client.emit('result', {
        'type': 'doctor_recommendation',
        'reply': 'Here are matching doctors.',
        'cards': {
          'department': {'en': 'Gynecology', 'zh': '妇科'},
          'also_consider': [],
          'hospitals': [
            {
              'hospital_id': 'SZ003',
              'name_en': 'The University of Hong Kong-Shenzhen Hospital',
              'name_zh': '香港大学深圳医院',
              'district_en': 'Futian District',
              'feature': null,
              'recognition': null,
              'dept_only': null,
              'doctors': [
                {
                  'doctor_id': 'test-doctor-1',
                  'name_zh': '测试医生',
                  'name_en': 'Test Doctor',
                  'title': {'en': 'Consultant', 'zh': '顾问医生'},
                  'dept': {'en': 'Gynecology', 'zh': '妇科'},
                  'matched': [],
                },
              ],
            },
          ],
        },
      });
      await tester.runAsync(() async {
        await client.streams.last.close();
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        find.text('The University of Hong Kong-Shenzhen Hospital'),
        findsOneWidget,
      );
      expect(find.text('香港大学深圳医院'), findsNothing);
      expect(find.text('Test Doctor'), findsOneWidget);
      expect(find.text('Consultant'), findsOneWidget);
      expect(find.textContaining('官网原文'), findsNothing);
      await tester.enterText(
        find.byKey(const Key('doctor-message')),
        'More doctors at this hospital, please.',
      );
      await tester.runAsync(() async {
        await tester.testTextInput.receiveAction(TextInputAction.send);
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(client.bodies.last['shown_doctor_ids'], ['test-doctor-1']);
      expect((client.bodies.last['messages'] as List).length, 3);
      expect(
        jsonEncode(client.bodies.last['messages']),
        contains('Hong Kong-Shenzhen'),
      );
      client.emit('result', {
        'type': 'chat',
        'reply': 'No additional matching doctors.',
        'cards': null,
      });
      await tester.runAsync(() async {
        await client.streams.last.close();
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
}
