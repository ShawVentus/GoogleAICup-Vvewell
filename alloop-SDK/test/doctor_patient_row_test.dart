import 'package:alloop/features/doctor_recommendation/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [320.0, 390.0]) {
    testWidgets('patient controls stay on one bottom row at $width px', (tester) async {
      tester.view.physicalSize = Size(width, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: ChatPage(showTopChips: false))));
      await tester.pump();
      final age = tester.getRect(find.byKey(const Key('doctor-patient-age')));
      final sex = tester.getRect(find.byKey(const Key('doctor-patient-sex')));
      final country = tester.getRect(find.byKey(const Key('doctor-patient-country')));
      final message = tester.getRect(find.byKey(const Key('doctor-message')));
      expect((age.top - sex.top).abs(), lessThan(1));
      expect((country.top - sex.top).abs(), lessThan(1));
      expect(age.right, lessThan(sex.left));
      expect(sex.right, lessThan(country.left));
      expect(country.bottom, lessThanOrEqualTo(message.top));
      for (final label in ['3 hospitals', 'Up to 2 doctors each', 'English', 'Not a diagnosis']) {
        expect(find.text(label), findsNothing);
      }
      expect(find.textContaining('Shenzhen'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }
}
