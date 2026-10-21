import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vardhman_b2b/api/order_header_line.dart';
import 'package:vardhman_b2b/constants.dart';

/// Order status summary shown at the top of the order details, so the
/// status is visible without scrolling the line table. Header values come
/// from ORCH5542001_GetOrderStatus; line counts from ORCH5542002.
class OrderStatusPanel extends StatelessWidget {
  final OrderHeaderLine orderHeaderLine;

  /// Number of order lines per displayed status (e.g. Dispatched: 3).
  final Map<String, int> lineStatusCounts;

  const OrderStatusPanel({
    super.key,
    required this.orderHeaderLine,
    required this.lineStatusCounts,
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

  Widget _field(String label, String value) {
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
            color: VardhmanColors.darkGrey,
          ),
        ),
      ],
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        border: Border.all(color: color, width: 0.8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final header = orderHeaderLine;

    final amountFormat = NumberFormat('#,##,##0.00', 'en_IN');

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
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _chip(
                'Status: ${header.orderStatus.trim().isEmpty ? '-' : header.orderStatus.trim()}',
                _statusColor(header.orderStatus),
              ),
              if (header.holdCode.trim().isNotEmpty)
                _chip('Hold: ${header.holdCode.trim()}', VardhmanColors.red),
              _chip(
                  'Ordered ${header.quantityOrdered}', VardhmanColors.darkGrey),
              _chip('Shipped ${header.quantityShipped}', VardhmanColors.green),
              if (header.quantityBackOrdered > 0)
                _chip('Back-ordered ${header.quantityBackOrdered}',
                    VardhmanColors.orange),
              if (header.quantityCancelled > 0)
                _chip('Cancelled ${header.quantityCancelled}',
                    VardhmanColors.red),
              if (lineStatusCounts.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  'Lines:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: VardhmanColors.darkGrey,
                  ),
                ),
                ...lineStatusCounts.entries.map(
                  (entry) => _chip(
                      '${entry.key} ${entry.value}', _statusColor(entry.key)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
