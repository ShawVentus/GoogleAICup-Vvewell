import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alloop/features/doctor_recommendation/country_selector.dart';

void main() {
  testWidgets('country selector allows choosing a country on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var selected = 'OTHER';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: CountrySelector(
              value: selected,
              onChanged: (value) => selected = value,
            ),
          ),
        ),
      ),
    );
    expect(
      currentCountryOptions.keys,
      containsAll([
        'CN',
        'JP',
        'US',
        'KR',
        'IN',
        'GB',
        'FR',
        'DE',
        'IT',
        'CA',
        'OTHER',
      ]),
    );
    final names = currentCountryOptions.entries
        .where((e) => e.key != 'OTHER')
        .map((e) => e.value)
        .toList();
    expect(names.length, 30);
    expect(
      names,
      [...names]..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase())),
    );
    expect(currentCountryOptions.keys.last, 'OTHER');
    expect(find.text('Current country'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Japan'),
      -120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Japan').last);
    await tester.pumpAndSettle();
    expect(selected, 'JP');
    expect(tester.takeException(), isNull);
  });
}
