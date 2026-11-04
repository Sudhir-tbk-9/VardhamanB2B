import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vardhman_b2b/constants.dart';
import 'package:vardhman_b2b/orders/order_list_filters.dart';

/// "Range ▾" next to an order list's From / To dates: Today, This Week, ...
/// fill both dates. The date fields still open the calendar for any other
/// range.
class DateRangeMenu extends StatelessWidget {
  final OrderListFilters filters;

  const DateRangeMenu({
    super.key,
    required this.filters,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(
      () {
        final selectedDateRange = filters.rxDateRange.value;

        // Theme colours, as on the other buttons; the brand colour once a
        // range is chosen.
        final color = selectedDateRange == null
            ? VardhmanColors.darkGrey
            : VardhmanColors.red;

        return PopupMenuButton<OrderDateRange>(
          tooltip: 'Quick date range',
          position: PopupMenuPosition.under,
          color: Colors.white,
          onSelected: filters.selectDateRange,
          itemBuilder: (context) => [
            for (final dateRange in OrderDateRange.values)
              PopupMenuItem(
                value: dateRange,
                height: 36,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        dateRange.label,
                        style: TextStyle(
                          fontSize: 13,
                          color: VardhmanColors.darkGrey,
                        ),
                      ),
                    ),
                    if (dateRange == selectedDateRange)
                      Icon(
                        Icons.check,
                        size: 16,
                        color: VardhmanColors.red,
                      ),
                  ],
                ),
              ),
          ],
          child: Container(
            padding: const EdgeInsets.only(
              left: 12,
              right: 6,
              top: 7,
              bottom: 7,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: selectedDateRange == null ? Colors.grey : color,
                width: selectedDateRange == null ? 0.5 : 1,
              ),
              color: Colors.white,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.date_range,
                  size: 16,
                  color: color,
                ),
                const SizedBox(width: 6),
                Text(
                  selectedDateRange?.label ?? 'Range',
                  style: TextStyle(
                    fontSize: 13,
                    color: color,
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down,
                  size: 18,
                  color: color,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
