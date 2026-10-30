import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vardhman_b2b/orders/order_list_filters.dart';

/// Quick ranges (Today, This Week, ...) that fill an order list's From / To
/// date fields; the fields still open the calendar for any other range.
class DateRangeChips extends StatelessWidget {
  final OrderListFilters filters;

  const DateRangeChips({
    super.key,
    required this.filters,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final dateRange in OrderDateRange.values)
            ChoiceChip(
              label: Text(dateRange.label),
              labelStyle: const TextStyle(fontSize: 12),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              selected: filters.rxDateRange.value == dateRange,
              onSelected: (_) => filters.selectDateRange(dateRange),
            ),
        ],
      ),
    );
  }
}
