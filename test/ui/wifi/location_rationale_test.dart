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
    expect(find.byKey(const Key('rationale-continue')), findsOneWidget);
    expect(find.byKey(const Key('rationale-not-now')), findsOneWidget);
    expect(find.bySemanticsLabel(kLocationRationale), findsOneWidget);
    expect(find.bySemanticsLabel(kLocationPromise), findsOneWidget);
    expect(find.bySemanticsLabel(kBackgroundLocationHint), findsOneWidget);
  });

  testWidgets('Continue answers true', (tester) async {
    final answer = await open(tester);
    await tester.tap(find.byKey(const Key('rationale-continue')));
    await tester.pumpAndSettle();
    expect(await answer, isTrue);
  });

  testWidgets('Not now answers false', (tester) async {
    final answer = await open(tester);
    await tester.tap(find.byKey(const Key('rationale-not-now')));
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
