import 'package:flutter_test/flutter_test.dart';
import 'package:vardhman_b2b/orders/order_list_filters.dart';

void main() {
  // A Thursday afternoon.
  final now = DateTime(2026, 10, 29, 15, 30);

  test('Today starts at midnight', () {
    expect(OrderDateRange.today.startDate(now), DateTime(2026, 10, 29));
  });

  test('This Week starts on Monday', () {
    expect(OrderDateRange.thisWeek.startDate(now), DateTime(2026, 10, 26));
    expect(
      OrderDateRange.thisWeek.startDate(DateTime(2026, 10, 26, 9)),
      DateTime(2026, 10, 26),
    );
    expect(
      OrderDateRange.thisWeek.startDate(DateTime(2026, 11, 1)),
      DateTime(2026, 10, 26),
    );
  });

  test('This Month starts on the 1st', () {
    expect(OrderDateRange.thisMonth.startDate(now), DateTime(2026, 10, 1));
  });

  test('Last 3 Months goes back to the same day', () {
    expect(
      OrderDateRange.lastThreeMonths.startDate(now),
      DateTime(2026, 7, 29),
    );
    expect(
      OrderDateRange.lastThreeMonths.startDate(DateTime(2026, 2, 10)),
      DateTime(2025, 11, 10),
    );
  });

  test('Last 3 Months stops at a shorter month\'s last day', () {
    expect(
      OrderDateRange.lastThreeMonths.startDate(DateTime(2026, 5, 31)),
      DateTime(2026, 2, 28),
    );
    expect(
      OrderDateRange.lastThreeMonths.startDate(DateTime(2028, 5, 31)),
      DateTime(2028, 2, 29),
    );
  });
}
