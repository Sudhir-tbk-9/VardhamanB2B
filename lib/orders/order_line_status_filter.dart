import 'package:get/get.dart';
import 'package:vardhman_b2b/api/order_detail_line.dart';

/// The line status chips above an order's details table (OrderStatusPanel):
/// a count per status of the lines the table lists, and the table filtered
/// to the chip picked. Used by the Labdip and Sampling order details, as
/// Bulk and DTM do in their controllers.
mixin OrderLineStatusFilter on GetxController {
  /// The order's lines the details table lists (ORCH5542002).
  List<OrderDetailLine> get statusFilterLines;

  /// A line's status as the details table shows it.
  String displayStatusOf(OrderDetailLine orderDetailLine);

  /// Line status the table is filtered to (a status chip); null for All.
  /// Back to All whenever another order is opened
  /// ([resetLineStatusFilter]).
  final rxLineStatusFilter = RxnString();

  void resetLineStatusFilter() => rxLineStatusFilter.value = null;

  /// Number of lines per displayed status, for the chips.
  Map<String, int> get lineStatusCounts {
    final counts = <String, int>{};

    for (final orderDetailLine in statusFilterLines) {
      final status = displayStatusOf(orderDetailLine);

      counts[status] = (counts[status] ?? 0) + 1;
    }

    return counts;
  }

  /// The status filter in effect: null (All) also when the picked status
  /// no longer has lines, e.g. after the order was refreshed.
  String? get lineStatusFilter {
    final status = rxLineStatusFilter.value;

    return status != null && lineStatusCounts.containsKey(status)
        ? status
        : null;
  }

  /// The lines shown in the table: [statusFilterLines] with the status chip
  /// filter applied, in their order.
  List<OrderDetailLine> get visibleOrderDetailLines {
    final status = lineStatusFilter;

    final lines = statusFilterLines;

    return status == null
        ? lines
        : lines.where((line) => displayStatusOf(line) == status).toList();
  }
}
