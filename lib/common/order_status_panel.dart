import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vardhman_b2b/api/order_header_line.dart';
import 'package:vardhman_b2b/app/theme_variants.dart';
import 'package:vardhman_b2b/constants.dart';

/// Order summary shown at the top of the order details, with the line
/// status chips that filter the line table below it. Header values come
/// from ORCH5542001_GetOrderStatus; line counts from ORCH5542002.
class OrderStatusPanel extends StatelessWidget {
  final OrderHeaderLine orderHeaderLine;

  /// Number of order lines per displayed status (e.g. Dispatched: 3).
  final Map<String, int> lineStatusCounts;

  /// Status the line table is filtered to; null for All.
  final String? selectedLineStatus;

  /// Called with the chip's status, or null for All.
  final ValueChanged<String?> onLineStatusSelected;

  const OrderStatusPanel({
    super.key,
    required this.orderHeaderLine,
    required this.lineStatusCounts,
    required this.selectedLineStatus,
    required this.onLineStatusSelected,
  });

  Color _statusColor(String status) {
    final lower = status.toLowerCase();

    if (lower.contains('cancel') || lower.contains('hold')) {
      return VardhmanColors.red;
    }

    if (lower.contains('dispatch') || lower.contains('ship')) {
      return VardhmanColors.green;
    }

    return VardhmanColors.orange;
  }

  Widget _field(String label, String value, {Color? color}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
        const SizedBox(height: 2),
        Text(
          value.trim().isEmpty ? '-' : value.trim(),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color ?? VardhmanColors.darkGrey,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final header = orderHeaderLine;

    final amountFormat = NumberFormat('#,##,##0.00', 'en_IN');

    final totalLines =
        lineStatusCounts.values.fold(0, (total, count) => total + count);

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 32,
            runSpacing: 8,
            children: [
              _field('Order', header.orderNumberString),
              _field('JDE Order No.', '${header.orderNumber}'),
              _field('Order Date',
                  DateFormat('dd/MM/yyyy').format(header.orderDate)),
              _field('PO No.', header.poNumber),
              _field('Merchandiser', header.merchandiser),
              _field('Order Amount',
                  '₹${amountFormat.format(header.orderAmount)}'),
              if (header.holdCode.trim().isNotEmpty)
                _field('Hold', header.holdCode, color: VardhmanColors.red),
            ],
          ),
          if (lineStatusCounts.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Lines:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: VardhmanColors.darkGrey,
                  ),
                ),
                LineStatusChip(
                  label: 'All $totalLines',
                  color: ThemeVariants.current.primary,
                  isSelected: selectedLineStatus == null,
                  onSelected: () => onLineStatusSelected(null),
                ),
                for (final MapEntry(key: status, value: count)
                    in lineStatusCounts.entries)
                  LineStatusChip(
                    label: '$status $count',
                    color: _statusColor(status),
                    isSelected: selectedLineStatus == status,
                    onSelected: () => onLineStatusSelected(status),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// A line status filter chip: tinted with an outline, filled in [color]
/// with white text while selected. A ChoiceChip, so it takes focus with Tab,
/// is picked with Enter / Space, shows the click cursor and is announced as
/// selected.
class LineStatusChip extends StatelessWidget {
  final String label;

  final Color color;

  final bool isSelected;

  final VoidCallback onSelected;

  const LineStatusChip({
    super.key,
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      // Picking the selected chip again keeps it selected: one is always on.
      onSelected: (_) => onSelected(),
      showCheckmark: false,
      // The default (adaptive) cursor is a pointer only on web.
      mouseCursor: SystemMouseCursors.click,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: isSelected ? Colors.white : color,
      ),
      color: WidgetStatePropertyAll(isSelected ? color : color.withAlpha(28)),
      side: BorderSide(color: color, width: isSelected ? 1.5 : 0.8),
      shape: const StadiumBorder(),
      elevation: 0,
      pressElevation: 0,
      shadowColor: Colors.transparent,
      selectedShadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
    );
  }
}
