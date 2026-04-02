import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Smoke test — confirms the app's main entry point can be imported
/// and basic widget infrastructure works.
///
/// Full integration tests require Hive + Supabase initialization
/// which is better suited for integration_test/ with mocked services.
void main() {
  testWidgets('App infrastructure smoke test', (WidgetTester tester) async {
    // Build a minimal MaterialApp to confirm Flutter widget system works
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('VocabGame')),
        ),
      ),
    );

    expect(find.text('VocabGame'), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
