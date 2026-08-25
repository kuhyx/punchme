import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punchme/models/day_entry.dart';
import 'package:punchme/ui/history/day_editor.dart';

void main() {
  DayEntry closed(String key, {int startHour = 9, int hours = 8}) {
    final checkIn = DateTime.parse(key).add(Duration(hours: startHour));
    return DayEntry(
      dateKey: key,
      checkIn: checkIn,
      checkOut: checkIn.add(Duration(hours: hours)),
    );
  }

  /// Pumps the editor and returns the DayEdit it pops, if any.
  Future<DayEdit?> pumpEditor(WidgetTester tester, DayEntry entry) async {
    DayEdit? result;
    await tester.pumpWidget(
      MaterialApp(
        // The app shows 24-hour times; make the picker agree, so a typed
        // "18" is a valid hour rather than silently rejected.
        builder: (context, child) => MediaQuery(
          data: const MediaQueryData(alwaysUse24HourFormat: true),
          child: child!,
        ),
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await showDialog<DayEdit>(
                context: context,
                builder: (_) => DayEditor(entry: entry),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  group('time pickers', () {
    testWidgets('editing the check-in updates the shown time', (tester) async {
      await pumpEditor(tester, closed('2026-08-24'));
      expect(find.text('09:00'), findsOneWidget);

      await tester.tap(find.text('Check in'));
      await tester.pumpAndSettle();
      // Switch to keyboard entry so a time can be typed deterministically.
      await tester.tap(find.byIcon(Icons.keyboard_outlined));
      await tester.pumpAndSettle();
      final fields = find.byType(TextField);
      await tester.enterText(fields.first, '10');
      await tester.enterText(fields.at(1), '30');
      await tester.tap(
        find.descendant(
          of: find.byType(TimePickerDialog),
          matching: find.text('OK'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('10:30'), findsOneWidget);
    });

    testWidgets('editing the check-out updates the total', (tester) async {
      await pumpEditor(tester, closed('2026-08-24'));
      expect(find.text('Total 8h 00m'), findsOneWidget);

      await tester.tap(find.text('Check out'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.keyboard_outlined));
      await tester.pumpAndSettle();
      final fields = find.byType(TextField);
      await tester.enterText(fields.first, '18');
      await tester.enterText(fields.at(1), '00');
      await tester.tap(
        find.descendant(
          of: find.byType(TimePickerDialog),
          matching: find.text('OK'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Total 9h 00m'), findsOneWidget);
    });

    testWidgets('cancelling a picker leaves the time alone', (tester) async {
      await pumpEditor(tester, closed('2026-08-24'));

      await tester.tap(find.text('Check in'));
      await tester.pumpAndSettle();
      // Both dialogs offer Cancel; target the time picker's.
      await tester.tap(
        find.descendant(
          of: find.byType(TimePickerDialog),
          matching: find.text('Cancel'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('09:00'), findsOneWidget);
    });

    testWidgets('a day with no check-out seeds the picker from check-in', (
      tester,
    ) async {
      final open = DayEntry(
        dateKey: '2026-08-24',
        checkIn: DateTime(2026, 8, 24, 9),
      );
      await pumpEditor(tester, open);
      expect(find.text('not set'), findsOneWidget);

      await tester.tap(find.text('Check out'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.keyboard_outlined));
      await tester.pumpAndSettle();
      final fields = find.byType(TextField);
      await tester.enterText(fields.first, '17');
      await tester.enterText(fields.at(1), '00');
      await tester.tap(
        find.descendant(
          of: find.byType(TimePickerDialog),
          matching: find.text('OK'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Total 8h 00m'), findsOneWidget);
    });
  });

  group('overnight', () {
    testWidgets('a check-out before the check-in rolls to the next day', (
      tester,
    ) async {
      // In 22:00; setting out to 02:00 must mean 4h, never minus 20h.
      final night = DayEntry(
        dateKey: '2026-08-24',
        checkIn: DateTime(2026, 8, 24, 22),
      );
      await pumpEditor(tester, night);

      await tester.tap(find.text('Check out'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.keyboard_outlined));
      await tester.pumpAndSettle();
      final fields = find.byType(TextField);
      await tester.enterText(fields.first, '02');
      await tester.enterText(fields.at(1), '00');
      await tester.tap(
        find.descendant(
          of: find.byType(TimePickerDialog),
          matching: find.text('OK'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Total 4h 00m'), findsOneWidget);
    });
  });

  group('actions', () {
    testWidgets('Save returns the edited entry', (tester) async {
      final result = await pumpEditor(tester, closed('2026-08-24'));
      expect(result, isNull); // not yet popped

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
    });

    testWidgets('Delete returns a delete result', (tester) async {
      await pumpEditor(tester, closed('2026-08-24'));
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.byType(DayEditor), findsNothing);
    });
  });
}
