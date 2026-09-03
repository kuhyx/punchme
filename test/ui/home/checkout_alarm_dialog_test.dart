import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punchme/logic/target_time.dart';
import 'package:punchme/ui/home/checkout_alarm_dialog.dart';

void main() {
  TargetToday target({
    DeficitLevel level = DeficitLevel.none,
    Duration deficit = Duration.zero,
    int spreadOver = 1,
    Duration uncovered = Duration.zero,
  }) => TargetToday(
    share: const Duration(hours: 8, minutes: 4),
    checkOutAt: DateTime(2026, 9, 15, 17, 4),
    level: level,
    deficit: deficit,
    spreadOver: spreadOver,
    uncovered: uncovered,
  );

  group('targetReason names the card being repaid', () {
    test('on track', () {
      expect(targetReason(target()), 'On track, nothing to make up.');
    });

    test('week: all today', () {
      expect(
        targetReason(
          target(level: DeficitLevel.week, deficit: const Duration(minutes: 4)),
        ),
        '0h 04m behind this week — all today.',
      );
    });

    test('month: spread over the week left', () {
      expect(
        targetReason(
          target(
            level: DeficitLevel.month,
            deficit: const Duration(hours: 10),
            spreadOver: 4,
          ),
        ),
        '10h 00m behind this month — spread over 4 days.',
      );
    });

    test('month on the last working day of the week reads "all today"', () {
      expect(
        targetReason(
          target(level: DeficitLevel.month, deficit: const Duration(hours: 1)),
        ),
        '1h 00m behind this month — all today.',
      );
    });

    test('year: spread over the month left', () {
      expect(
        targetReason(
          target(
            level: DeficitLevel.year,
            deficit: const Duration(hours: 10),
            spreadOver: 12,
          ),
        ),
        '10h 00m behind this year — spread over 12 days.',
      );
    });

    test('capped: says what is still uncovered', () {
      expect(
        targetReason(
          target(
            level: DeficitLevel.week,
            deficit: const Duration(hours: 8),
            uncovered: const Duration(hours: 1, minutes: 1),
          ),
        ),
        '8h 00m behind this week — all today. '
        'Capped at 23:59, 1h 01m still uncovered.',
      );
    });
  });

  testWidgets('the dialog shows the share, the time and the reason', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CheckOutAlarmDialog(
          target: target(
            level: DeficitLevel.week,
            deficit: const Duration(minutes: 4),
          ),
        ),
      ),
    );
    expect(find.text('Work 8h 04m today, until 17:04.'), findsOneWidget);
    expect(find.text('0h 04m behind this week — all today.'), findsOneWidget);
  });
}
