import 'package:flutter_test/flutter_test.dart';
import 'package:vardhman_b2b/orders/order_list_filters.dart';

void main() {
  // A Thursday afternoon.
  final now = DateTime(2026, 10, 29, 15, 30);

  test('Today starts at midnight', () {
    expect(OrderDateRange.today.startDate(now), DateTime(2026, 10, 29));
  });

  test('Last 7 Days is today and the 6 days before', () {
    expect(
      OrderDateRange.lastSevenDays.startDate(now),
      DateTime(2026, 10, 23),
    );
    // Across a month start.
    expect(
      OrderDateRange.lastSevenDays.startDate(DateTime(2026, 11, 3, 9)),
      DateTime(2026, 10, 28),
    );
  });

  test('Last 30 Days is today and the 29 days before', () {
    expect(
      OrderDateRange.lastThirtyDays.startDate(now),
      DateTime(2026, 9, 30),
    );
    // Across a year start.
    expect(
      OrderDateRange.lastThirtyDays.startDate(DateTime(2027, 1, 10)),
      DateTime(2026, 12, 12),
    );
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
