import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:date_field/date_field.dart';
import 'package:get/get.dart';
import 'package:vardhman_b2b/common/new_order_date_field.dart';

void main() {
  final today = DateUtils.dateOnly(DateTime.now());

  test('the earliest EDD is 11 days from today', () {
    expect(earliestEdd, today.add(const Duration(days: 11)));
  });

  Future<void> openPicker(
    WidgetTester tester,
    DateTime? date, {
    Size screen = const Size(1280, 900),
  }) async {
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            child: NewOrderDateField(
              labelText: 'Expected Delivery Date',
              rxDate: Rxn<DateTime>(date),
              firstDate: earliestEdd,
              pickerNote: earliestEddNote,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(DateTimeField));
    await tester.pumpAndSettle();
  }

  testWidgets('today and the next 10 days cannot be picked', (tester) async {
    await openPicker(tester, today.add(const Duration(days: 18)));

    expect(find.byType(DatePickerDialog), findsOneWidget);

    final picker = tester.widget<CalendarDatePicker>(
      find.byType(CalendarDatePicker),
    );

    expect(picker.firstDate, earliestEdd);
    expect(picker.initialDate, today.add(const Duration(days: 18)));
  });

  testWidgets('a saved date before the earliest EDD opens on the earliest',
      (tester) async {
    await openPicker(tester, today.subtract(const Duration(days: 3)));

    expect(tester.takeException(), isNull);

    final picker = tester.widget<CalendarDatePicker>(
      find.byType(CalendarDatePicker),
    );

    expect(picker.initialDate, earliestEdd);
  });

  for (final screen in [const Size(1536, 730), const Size(420, 860)]) {
    testWidgets('the calendar shows the note right under it at $screen',
        (tester) async {
      await openPicker(
        tester,
        earliestEdd,
        screen: screen,
      );

      expect(find.text(earliestEddNote), findsOneWidget);
      expect(earliestEddNote, contains('next 10 days are not available'));

      final note = tester.getRect(find.text(earliestEddNote));

      // Under the calendar, within its width, on screen.
      final calendar = tester.getRect(
        find.descendant(
          of: find.byType(DatePickerDialog),
          matching: find.byType(AnimatedContainer),
        ).first,
      );
      expect(note.top, greaterThan(calendar.bottom));
      expect(note.top - calendar.bottom, lessThan(40));
      expect(note.left, greaterThanOrEqualTo(calendar.left));
      expect(note.right, lessThanOrEqualTo(calendar.right));
      expect(note.bottom, lessThan(screen.height));

    });
  }

  testWidgets('tapping a blocked day does not pick it', (tester) async {
    final rxDate = Rxn<DateTime>(earliestEdd);

    tester.view.physicalSize = const Size(1536, 730);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            child: NewOrderDateField(
              labelText: 'Expected Delivery Date',
              rxDate: rxDate,
              firstDate: earliestEdd,
              pickerNote: earliestEddNote,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(DateTimeField));
    await tester.pumpAndSettle();

    final blocked = earliestEdd.subtract(const Duration(days: 1));

    if (blocked.month == earliestEdd.month) {
      await tester.tap(
        find.descendant(
          of: find.byType(CalendarDatePicker),
          matching: find.text('${blocked.day}'),
        ),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
    } else {
      // The earliest date is the 1st: the calendar cannot go back to the
      // month of the blocked day at all.
      final previousMonth = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.chevron_left),
      );

      expect(previousMonth.onPressed, isNull);
    }

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(rxDate.value, earliestEdd);
  });
}
