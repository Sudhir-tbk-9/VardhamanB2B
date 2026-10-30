import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vardhman_b2b/constants.dart';

/// "1–50 of 1,234 ‹ ›" for an order table, shown in the list's title bar
/// instead of a footer under the table, which took room from the rows.
class OrderPager extends StatelessWidget {
  final PaginatorController controller;

  const OrderPager({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final numberFormat = NumberFormat.decimalPattern('en_IN');

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (!controller.isAttached || controller.rowCount < 1) {
          return const SizedBox.shrink();
        }

        final rowCount = controller.rowCount;

        final firstRow = controller.currentRowIndex + 1;

        final lastRow = (controller.currentRowIndex + controller.rowsPerPage)
            .clamp(0, rowCount);

        Widget pageButton(IconData iconData, VoidCallback? onPressed) =>
            IconButton(
              icon: Icon(iconData),
              iconSize: 20,
              color: VardhmanColors.darkGrey,
              disabledColor: VardhmanColors.dividerGrey,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 28, height: 24),
              onPressed: onPressed,
            );

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            pageButton(
              Icons.chevron_left,
              firstRow > 1 ? controller.goToPreviousPage : null,
            ),
            Text(
              '${numberFormat.format(firstRow)}–${numberFormat.format(lastRow)}'
              ' of ${numberFormat.format(rowCount)}',
              style: TextStyle(
                fontSize: 12,
                color: VardhmanColors.darkGrey,
              ),
            ),
            pageButton(
              Icons.chevron_right,
              lastRow < rowCount ? controller.goToNextPage : null,
            ),
          ],
        );
      },
    );
  }
}
