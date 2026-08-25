import 'package:flutter_test/flutter_test.dart';
import 'package:punchme/logic/periods.dart';

void main() {
  // 2026-08-25 is a Tuesday.
  final tuesday = DateTime(2026, 8, 25, 14, 30);

  test('startOfWeek is the Monday at midnight', () {
    expect(startOfWeek(tuesday), DateTime(2026, 8, 24));
  });

  test('startOfWeek on a Monday is that same day', () {
    expect(startOfWeek(DateTime(2026, 8, 24, 9)), DateTime(2026, 8, 24));
  });

  test('startOfWeek on a Sunday looks back to the Monday', () {
    expect(startOfWeek(DateTime(2026, 8, 30, 9)), DateTime(2026, 8, 24));
  });

  test('startOfWeek crosses a month boundary', () {
    // Tuesday 2026-09-01 belongs to the week starting Monday 2026-08-31.
    expect(startOfWeek(DateTime(2026, 9, 1, 9)), DateTime(2026, 8, 31));
  });

  test('startOfMonth is the first at midnight', () {
    expect(startOfMonth(tuesday), DateTime(2026, 8));
  });

  test('startOfYear is 1 January at midnight', () {
    expect(startOfYear(tuesday), DateTime(2026));
  });
}
