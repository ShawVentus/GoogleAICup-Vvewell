import 'package:alloop/features/cloud_sync/presentation/widgets/cloud_sync_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('home exposes an explicit manual measurement sync button', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Align(alignment: Alignment.topRight, child: CloudSyncButton()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Sync dashboard data'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_sync_outlined), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Sign in to sync'), findsNothing);
  });
}
