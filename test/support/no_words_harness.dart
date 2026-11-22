import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:punchme/models/day_entry.dart';

/// Shared harness for test/ui/no_words_test.dart (textgate): split out so
/// that file stays under the 250-line cap.
///
/// Any letter at all counts: weekday initials (`M T W`) are words too.
/// Durations (`8h 04m`) are the one letter-bearing value, so they are cut
/// out first. The only kept chrome is the app's proper noun.
final RegExp _word = RegExp('[A-Za-z]');
final RegExp _duration = RegExp(r'-?\+?\d+h \d{2}m');
const Set<String> _keep = <String>{'punchme'};

/// The fixed "now" every screen is pumped at.
DateTime noWordsNow() => DateTime(2026, 8, 25, 12);

/// August 1-25 2026, 09:00-17:00 each day; today left open if [openToday].
List<DayEntry> august({bool openToday = false}) => <DayEntry>[
  for (var d = 1; d <= 25; d++)
    DayEntry(
      dateKey: '2026-08-${d.toString().padLeft(2, '0')}',
      checkIn: DateTime(2026, 8, d, 9),
      checkOut: d == 25 && openToday ? null : DateTime(2026, 8, d, 17),
    ),
];

/// Every painted string with a word in it, minus the kept proper noun.
List<String> wordsOn(WidgetTester tester) =>
    <String>[
      for (final e in find.byType(RichText).evaluate())
        (e.widget as RichText).text.toPlainText(),
    ].where((s) {
      final bare = s.replaceAll(_duration, '');
      return _word.hasMatch(bare) && !_keep.contains(s.trim());
    }).toList();

/// Pumps [home] on a tall phone-sized view and lets it settle.
Future<void> pumpScreen(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(1080, 12000);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: home));
  await tester.pumpAndSettle();
}

/// Fails when any painted string carries a word.
void expectNoWords(WidgetTester tester) =>
    expect(wordsOn(tester), isEmpty, reason: 'painted words');
