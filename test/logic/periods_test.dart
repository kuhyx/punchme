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

  test('endOfWeek is the following Monday at midnight', () {
    expect(endOfWeek(tuesday), DateTime(2026, 8, 31));
  });

  test('endOfWeek on a Sunday is the very next day', () {
    expect(endOfWeek(DateTime(2026, 8, 30, 9)), DateTime(2026, 8, 31));
  });

  test('endOfMonth is the first of next month', () {
    expect(endOfMonth(tuesday), DateTime(2026, 9));
  });

  test('endOfMonth rolls December into next January', () {
    expect(endOfMonth(DateTime(2026, 12, 15)), DateTime(2027));
  });

  test('endOfYear is next 1 January at midnight', () {
    expect(endOfYear(tuesday), DateTime(2027));
  });

  test('a week spans exactly seven days across a DST boundary', () {
    // Europe/Warsaw ends DST on 2026-10-25, so this week is 169 hours long
    // in wall-clock terms. The end must still be the Monday, not Sunday
    // 23:00.
    final start = startOfWeek(DateTime(2026, 10, 21, 12));
    expect(start, DateTime(2026, 10, 19));
    expect(endOfWeek(DateTime(2026, 10, 21, 12)), DateTime(2026, 10, 26));
  });
}
