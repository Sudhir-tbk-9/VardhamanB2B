import 'package:get/get.dart';
import 'package:vardhman_b2b/api/api.dart';
import 'package:vardhman_b2b/api/order_detail_line.dart';
import 'package:vardhman_b2b/api/order_header_line.dart';
import 'package:vardhman_b2b/constants.dart';
import 'package:vardhman_b2b/drift/database.dart';
import 'package:vardhman_b2b/orders/order_list_filters.dart';
import 'package:vardhman_b2b/orders/orders_controller.dart';
import 'package:vardhman_b2b/user/user_controller.dart';

class DtmController extends GetxController with OrderListFilters {
  @override
  final OrdersController ordersController = Get.find<OrdersController>();

  final rejectionReasons = [
    'Late Delivery',
    'Tonel Difference',
    'Brighter',
    'Lighter',
    'Darker',
    'Wrong Dispatch',
    'Metamerism',
    'Duller',
    'Order Cancel by Buyer',
  ];

  @override
  final rxEarliestOrderDate = oldestDateTime.obs;

  @override
  final rxOrderFromDate = oldestDateTime.obs;

  @override
  final rxOrderToDate = DateTime.now().obs;

  @override
  final rxOrderNumberInput = ''.obs;

  @override
  final RxString rxPoNumberInput = ''.obs;

  @override
  final rxMerchandiserInput = ''.obs;

  @override
  final rxShadeInput = ''.obs;

  @override
  final rxBuyerInput = ''.obs;

  /// Orders having a line matching the shade / buyer inputs, or null when
  /// neither is entered.
  @override
  final rxLineSearchMatches = Rxn<Set<int>>();

  @override
  void onInit() {
    super.onInit();

    initOrderListFilters();
  }

  @override
  bool isListOrder(OrderHeaderLine orderHeaderLine) =>
      // JDE can create a portal order as SO instead of SW, as for Bulk.
      const {'SW', 'SO'}.contains(orderHeaderLine.orderType) &&
      orderHeaderLine.isDTM;

  final rxDraftOrders = <DraftTableData>[].obs;

  @override
  final rxSelectedOrderHeaderLine = Rxn<OrderHeaderLine>();

  final rxOrderDetailLines = <OrderDetailLine>[].obs;

  final rxSelectedOrderDetailLinesReasonMap = <OrderDetailLine, String>{}.obs;

  final Database _database = Get.find<Database>();

  final UserController _userController =
      Get.find<UserController>(tag: 'userController');

  DtmController() {
    _database.managers.draftTable
        .filter(
          (f) => f.orderType.equals('DT'),
        )
        .filter(
          (f) =>
              f.soldTo.equals(_userController.rxUserDetail.value.soldToNumber),
        )
        .orderBy(
          (o) => o.lastUpdated.desc(),
        )
        .watch()
        .listen(
      (draftTableDatas) {
        // Remove duplicate orders, keeping the latest draft of each; assigned
        // in one go so the list view rebuilds once, not once per row.
        final seenOrderNumbers = <int>{};

        rxDraftOrders.assignAll(
          draftTableDatas.where(
            (draftTableData) =>
                seenOrderNumbers.add(draftTableData.orderNumber),
          ),
        );
      },
    );

    ordersController.rxOrderHeaderLines.listenAndPump(
      (orderHeaderLines) {
        assignListOrders(orderHeaderLines);

        rxEarliestOrderDate.value =
            dtmOrders.lastOrNull?.orderDate ?? oldestDateTime;

        rxOrderFromDate.value =
            dtmOrders.lastOrNull?.orderDate ?? oldestDateTime;

        // A quick range such as Last 30 Days outlasts a reload.
        reapplyDateRange();
      },
    );
  }

  Future<void> refreshOrders() async {
    await ordersController.refreshOrders();
  }

  void selectOrderDetailLine(OrderDetailLine orderDetailLine) {
    if (rxSelectedOrderDetailLinesReasonMap.containsKey(orderDetailLine)) {
      rxSelectedOrderDetailLinesReasonMap.remove(orderDetailLine);
    } else {
      rxSelectedOrderDetailLinesReasonMap[orderDetailLine] = '';
    }
  }

  Future<void> selectOrder(OrderHeaderLine orderHeaderLine) async {
    rxSelectedOrderHeaderLine.value = orderHeaderLine;

    // Each order opens showing all its lines.
    rxLineStatusFilter.value = null;

    refreshSelectedOrderDetails();
  }

  final _rxDetailsLoadCount = 0.obs;

  /// True while the selected order's lines are being fetched from JDE.
  bool get isLoadingDetails => _rxDetailsLoadCount.value > 0;

  Future<void> refreshSelectedOrderDetails() async {
    rxOrderDetailLines.clear();

    rxSelectedOrderDetailLinesReasonMap.clear();

    final selectedOrderHeaderLine = rxSelectedOrderHeaderLine.value;

    if (selectedOrderHeaderLine != null) {
      _rxDetailsLoadCount.value++;

      final List<OrderDetailLine> orderDetailLines;

      try {
        orderDetailLines = await Api.fetchOrderDetails(
          orderNumber: selectedOrderHeaderLine.orderNumber,
          orderType: selectedOrderHeaderLine.orderType,
          orderCompany: selectedOrderHeaderLine.orderCompany,
        );
      } finally {
        _rxDetailsLoadCount.value--;
      }

      // Deselected, or another order picked, while these loaded.
      if (isSameOrder(
          rxSelectedOrderHeaderLine.value, selectedOrderHeaderLine)) {
        rxOrderDetailLines.assignAll(orderDetailLines);
      }
    }
  }

  List<OrderHeaderLine> get dtmOrders => rxOrders;

  List<OrderHeaderLine> get filteredDtmOrders => rxFilteredOrders;

  List<OrderDetailLine> get primaryOrderDetailLines => rxOrderDetailLines.where(
        (orderDetailLine) {
          final itemParts = orderDetailLine.item.split(RegExp('\\s+'));

          return itemParts.length == 3 && itemParts[2].startsWith('SWT');
        },
      ).toList();

  OrderDetailLine? getPermanentShadeLine(int workOrderNumber) {
    return rxOrderDetailLines.firstWhereOrNull(
      (detailLine) =>
          detailLine.catalogName.endsWith(workOrderNumber.toString()),
    );
  }

  List<OrderDetailLine> getInvoicedLines(String itemNumber) {
    return rxOrderDetailLines
        .where(
          (detailLine) =>
              detailLine.item == itemNumber && detailLine.invoiceNumber > 0,
        )
        .toList();
  }

  /// What the Order Details table shows for a DTM line, all from the
  /// order's ORCH5542002 lines: the final (permanent) shade JDE made for the
  /// line's work order, and that line's status, shipments and invoices.
  /// Until JDE has made it, the line's own status and unit price.
  DtmLineValues lineValuesOf(OrderDetailLine orderDetailLine) {
    final permanentShadeLine =
        getPermanentShadeLine(orderDetailLine.workOrderNumber);

    if (permanentShadeLine == null) {
      return DtmLineValues(
        finalShade: '',
        status: orderDetailLine.status,
        quantityShipped: 0,
        unitPrice: orderDetailLine.unitPrice,
        totalPrice: 0,
        invoicedLines: const [],
      );
    }

    final permanentShadeParts = permanentShadeLine.item.split(RegExp('\\s+'));

    final invoicedLines = getInvoicedLines(permanentShadeLine.item);

    return DtmLineValues(
      finalShade: permanentShadeParts.length == 3 ? permanentShadeParts[2] : '',
      status:
          invoicedLines.isNotEmpty ? 'Dispatched' : permanentShadeLine.status,
      quantityShipped: invoicedLines.fold(
        0,
        (total, invoicedLine) => total + invoicedLine.quantityShipped,
      ),
      unitPrice:
          invoicedLines.firstOrNull?.unitPrice ?? orderDetailLine.unitPrice,
      totalPrice: invoicedLines.fold(
        0,
        (total, invoicedLine) => total + invoicedLine.extendedPrice,
      ),
      invoicedLines: invoicedLines,
    );
  }

  /// Line status as shown in Order Details ([lineValuesOf]).
  String displayStatusOf(OrderDetailLine orderDetailLine) =>
      lineValuesOf(orderDetailLine).status;

  /// Number of order lines per displayed status, for the status chips.
  Map<String, int> get lineStatusCounts {
    final counts = <String, int>{};

    for (final orderDetailLine in primaryOrderDetailLines) {
      final status = displayStatusOf(orderDetailLine);

      counts[status] = (counts[status] ?? 0) + 1;
    }

    return counts;
  }

  /// Line status the Order Details table is filtered to (a status chip);
  /// null for All. Back to All whenever another order is opened.
  final rxLineStatusFilter = RxnString();

  /// The status filter in effect: null (All) also when the picked status
  /// no longer has lines, e.g. after the order was refreshed.
  String? get lineStatusFilter {
    final status = rxLineStatusFilter.value;

    return status != null && lineStatusCounts.containsKey(status)
        ? status
        : null;
  }

  /// The lines shown in the Order Details table: [primaryOrderDetailLines]
  /// with the status chip filter applied, on the lines already loaded.
  List<OrderDetailLine> get visibleOrderDetailLines {
    final status = lineStatusFilter;

    final lines = primaryOrderDetailLines;

    return status == null
        ? lines
        : lines.where((line) => displayStatusOf(line) == status).toList();
  }

  @override
  bool get hasDefaultValues =>
      areDatesEqual(
        rxOrderFromDate.value,
        rxEarliestOrderDate.value,
      ) &&
      areDatesEqual(rxOrderToDate.value, DateTime.now()) &&
      rxOrderNumberInput.value.isEmpty &&
      rxPoNumberInput.value.isEmpty &&
      rxMerchandiserInput.value.isEmpty &&
      rxShadeInput.value.isEmpty &&
      rxBuyerInput.value.isEmpty;

  @override
  Future<void> setDefaultValues() async {
    rxOrderFromDate.value = rxEarliestOrderDate.value;

    rxDateRange.value = null;

    rxOrderToDate.value = DateTime.now();

    rxOrderNumberInput.value = '';

    rxPoNumberInput.value = '';

    rxMerchandiserInput.value = '';

    rxShadeInput.value = '';

    rxBuyerInput.value = '';
  }
}

/// A DTM line's values in the Order Details table
/// ([DtmController.lineValuesOf]).
class DtmLineValues {
  final String finalShade;

  final String status;

  final int quantityShipped;

  final double unitPrice;

  final double totalPrice;

  final List<OrderDetailLine> invoicedLines;

  const DtmLineValues({
    required this.finalShade,
    required this.status,
    required this.quantityShipped,
    required this.unitPrice,
    required this.totalPrice,
    required this.invoicedLines,
  });
}
