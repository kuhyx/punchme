import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punchme/ui/wifi/location_rationale.dart';

void main() {
  /// Opens the dialog and returns the future of its answer.
  Future<Future<bool>> open(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    final answer = showLocationRationaleDialog(
      tester.element(find.byType(Scaffold)),
    );
    await tester.pumpAndSettle();
    return answer;
  }

  testWidgets('explains why, and what is never read', (tester) async {
    await open(tester);
    expect(find.text('Why location?'), findsOneWidget);
    expect(find.text(kLocationRationale), findsOneWidget);
    expect(find.text(kLocationPromise), findsOneWidget);
    expect(find.text(kBackgroundLocationHint), findsOneWidget);
  });

  testWidgets('Continue answers true', (tester) async {
    final answer = await open(tester);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(await answer, isTrue);
  });

  testWidgets('Not now answers false', (tester) async {
    final answer = await open(tester);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(await answer, isFalse);
  });

  testWidgets('dismissing the barrier answers false', (tester) async {
    final answer = await open(tester);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(await answer, isFalse);
  });
}
