import 'package:get/get.dart';
import 'package:vardhman_b2b/api/order_header_line.dart';
import 'package:vardhman_b2b/orders/orders_controller.dart';

/// Quick From / To date ranges offered above the date fields, each ending
/// today.
enum OrderDateRange {
  today('Today'),
  thisWeek('This Week'),
  thisMonth('This Month'),
  lastThreeMonths('Last 3 Months');

  final String label;

  const OrderDateRange(this.label);

  /// First day of the range ending on [now]'s date. Weeks start on Monday.
  DateTime startDate(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);

    switch (this) {
      case OrderDateRange.today:
        return today;
      case OrderDateRange.thisWeek:
        return today.subtract(Duration(days: today.weekday - DateTime.monday));
      case OrderDateRange.thisMonth:
        return DateTime(today.year, today.month);
      case OrderDateRange.lastThreeMonths:
        // Same day three months back, or that month's last day when it is
        // shorter (31 May -> 28/29 Feb).
        final lastDayOfMonth = DateTime(today.year, today.month - 2, 0).day;

        return DateTime(
          today.year,
          today.month - 3,
          today.day > lastDayOfMonth ? lastDayOfMonth : today.day,
        );
    }
  }
}

/// Filtering shared by the Bulk, DTM, Sampling and Labdip order lists.
///
/// The list's orders and the filtered orders are kept in [rxOrders] and
/// [rxFilteredOrders], worked out again only when the orders or a filter
/// change rather than on every rebuild: a customer can have well over a
/// thousand orders.
mixin OrderListFilters on GetxController {
  OrdersController get ordersController;

  /// Date of the oldest order in the list: the From date's lower bound.
  Rx<DateTime> get rxEarliestOrderDate;

  Rx<DateTime> get rxOrderFromDate;

  Rx<DateTime> get rxOrderToDate;

  RxString get rxOrderNumberInput;

  RxString get rxMerchandiserInput;

  RxString get rxShadeInput;

  RxString get rxBuyerInput;

  /// Orders having a line matching the shade / buyer inputs, or null when
  /// neither is entered.
  Rxn<Set<int>> get rxLineSearchMatches;

  /// Only the Bulk and DTM lists filter on PO number.
  RxString? get rxPoNumberInput => null;

  /// Whether [orderHeaderLine] belongs to this list.
  bool isListOrder(OrderHeaderLine orderHeaderLine);

  /// This list's orders, newest first.
  final rxOrders = <OrderHeaderLine>[].obs;

  /// [rxOrders] the filters let through.
  final rxFilteredOrders = <OrderHeaderLine>[].obs;

  /// Share of orders the running shade / buyer search has checked, or null
  /// when none is running.
  final rxLineSearchProgress = Rxn<double>();

  /// Quick range last chosen for the From / To dates, or null once either
  /// date is picked by hand or the filters are reset.
  final rxDateRange = Rxn<OrderDateRange>();

  int _lineSearchGeneration = 0;

  /// Sets the From / To dates to [dateRange]. The From date is kept no
  /// earlier than the oldest order, the calendar's first date.
  void selectDateRange(OrderDateRange dateRange) {
    final now = DateTime.now();

    final from = dateRange.startDate(now);

    rxDateRange.value = dateRange;

    rxOrderFromDate.value = from.isBefore(rxEarliestOrderDate.value)
        ? rxEarliestOrderDate.value
        : from;

    rxOrderToDate.value = now;
  }

  /// Applies the chosen quick range again, e.g. after the orders reload and
  /// the From date goes back to the oldest order.
  void reapplyDateRange() {
    final dateRange = rxDateRange.value;

    if (dateRange != null) {
      selectDateRange(dateRange);
    }
  }

  /// Call from onInit.
  void initOrderListFilters() {
    const typingDelay = Duration(milliseconds: 300);

    debounce(rxOrderNumberInput, (_) => _onHeaderFiltersChanged(),
        time: typingDelay);

    debounce(rxMerchandiserInput, (_) => _onHeaderFiltersChanged(),
        time: typingDelay);

    if (rxPoNumberInput != null) {
      debounce(rxPoNumberInput!, (_) => _onHeaderFiltersChanged(),
          time: typingDelay);
    }

    everAll([rxOrderFromDate, rxOrderToDate], (_) => _onHeaderFiltersChanged());

    debounce(rxShadeInput, (_) => _searchByLine(),
        time: const Duration(milliseconds: 600));

    debounce(rxBuyerInput, (_) => _searchByLine(),
        time: const Duration(milliseconds: 600));

    ever(rxLineSearchMatches, (_) => _applyFilters());
  }

  /// Takes this list's orders out of all the customer's [orderHeaderLines];
  /// call whenever those are (re)loaded, before reading [rxOrders].
  void assignListOrders(List<OrderHeaderLine> orderHeaderLines) {
    rxOrders.assignAll(orderHeaderLines.where(isListOrder));

    _onHeaderFiltersChanged();
  }

  void _onHeaderFiltersChanged() {
    _applyFilters();

    // The shade / buyer search only checks orders the other filters let
    // through, so it has to run again over the new set.
    _searchByLine();
  }

  bool _matchesHeaderFilters(OrderHeaderLine orderHeaderLine) =>
      (orderHeaderLine.orderReference
              .trim()
              .contains(rxOrderNumberInput.value) ||
          orderHeaderLine.orderNumber
              .toString()
              .contains(rxOrderNumberInput.value)) &&
      orderHeaderLine.orderDate.isAfter(
        rxOrderFromDate.value.subtract(
          const Duration(days: 1),
        ),
      ) &&
      orderHeaderLine.orderDate.isBefore(
        rxOrderToDate.value.add(
          const Duration(days: 1),
        ),
      ) &&
      orderHeaderLine.merchandiser.contains(rxMerchandiserInput.value) &&
      orderHeaderLine.poNumber.contains(rxPoNumberInput?.value ?? '');

  void _applyFilters() {
    final lineSearchMatches = rxLineSearchMatches.value;

    // One update: the list and its listeners rebuild once.
    rxFilteredOrders.assignAll(
      rxOrders.where(
        (orderHeaderLine) =>
            _matchesHeaderFilters(orderHeaderLine) &&
            (lineSearchMatches?.contains(orderHeaderLine.orderNumber) ?? true),
      ),
    );
  }

  Future<void> _searchByLine() async {
    // A newer search (or clearing shade / buyer) makes this one stop.
    final generation = ++_lineSearchGeneration;

    bool isCurrent() => generation == _lineSearchGeneration;

    final shade = rxShadeInput.value;

    final buyer = rxBuyerInput.value;

    if (shade.trim().isEmpty && buyer.trim().isEmpty) {
      rxLineSearchProgress.value = null;

      rxLineSearchMatches.value = null;

      return;
    }

    rxLineSearchProgress.value = 0;

    final matches = await ordersController.findOrdersByLine(
      orderHeaderLines: rxOrders.where(_matchesHeaderFilters).toList(),
      shade: shade,
      buyer: buyer,
      isCancelled: () => !isCurrent(),
      onProgress: (progress) {
        if (isCurrent()) {
          rxLineSearchProgress.value = progress;
        }
      },
    );

    if (isCurrent()) {
      rxLineSearchProgress.value = null;

      rxLineSearchMatches.value = matches;
    }
  }
}
