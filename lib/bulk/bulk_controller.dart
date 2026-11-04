import 'package:get/get.dart';
import 'package:vardhman_b2b/api/api.dart';
import 'package:vardhman_b2b/api/order_detail_line.dart';
import 'package:vardhman_b2b/api/order_header_line.dart';
import 'package:vardhman_b2b/constants.dart';
import 'package:vardhman_b2b/drift/database.dart';
import 'package:vardhman_b2b/orders/order_list_filters.dart';
import 'package:vardhman_b2b/orders/orders_controller.dart';
import 'package:vardhman_b2b/user/user_controller.dart';

class BulkController extends GetxController with OrderListFilters {
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
      orderHeaderLine.orderType == 'SW' && !orderHeaderLine.isDTM;

  final rxDraftOrders = <DraftTableData>[].obs;

  final rxSelectedOrderHeaderLine = Rxn<OrderHeaderLine>();

  final rxOrderDetailLines = <OrderDetailLine>[].obs;

  final rxSelectedOrderDetailLinesReasonMap = <OrderDetailLine, String>{}.obs;

  final Database _database = Get.find<Database>();

  final UserController _userController =
      Get.find<UserController>(tag: 'userController');

  BulkController() {
    _database.managers.draftTable
        .filter(
          (f) => f.orderType.equals('BK'),
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
            bulkOrders.lastOrNull?.orderDate ?? oldestDateTime;

        rxOrderFromDate.value =
            bulkOrders.lastOrNull?.orderDate ?? oldestDateTime;

        // A quick range such as This Month outlasts a reload.
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

    refreshSelectedOrderDetails();
  }

  final _rxDetailsLoadCount = 0.obs;

  /// True while the selected order's lines are being fetched from JDE.
  bool get isLoadingDetails => _rxDetailsLoadCount.value > 0;

  Future<void> refreshSelectedOrderDetails() async {
    rxOrderDetailLines.clear();

    rxSelectedOrderDetailLinesReasonMap.clear();

    if (rxSelectedOrderHeaderLine.value != null) {
      _rxDetailsLoadCount.value++;

      final List<OrderDetailLine> orderDetailLines;

      try {
        orderDetailLines = await Api.fetchOrderDetails(
          orderNumber: rxSelectedOrderHeaderLine.value!.orderNumber,
          orderType: rxSelectedOrderHeaderLine.value!.orderType,
          orderCompany: rxSelectedOrderHeaderLine.value!.orderCompany,
        );
      } finally {
        _rxDetailsLoadCount.value--;
      }

      rxOrderDetailLines.assignAll(orderDetailLines);
    }
  }

  List<OrderDetailLine> get primaryOrderDetailLines => rxOrderDetailLines.where(
        (orderDetailLine) {
          return orderDetailLine.workOrderNumber > 0 &&
              orderDetailLine.workOrderType.isNotEmpty &&
              rxSelectedOrderHeaderLine.value!.orderReference ==
                  orderDetailLine.orderLineReference;
        },
      ).toList();

  List<OrderHeaderLine> get bulkOrders => rxOrders;

  List<OrderHeaderLine> get filteredBulkOrders => rxFilteredOrders;

  List<OrderDetailLine> getInvoicedLines(String itemNumber) {
    return rxOrderDetailLines
        .where(
          (detailLine) =>
              detailLine.item == itemNumber && detailLine.invoiceNumber > 0,
        )
        .toList();
  }

  /// Line status as shown in Order Details: Dispatched once invoiced,
  /// otherwise the ORCH5542002 status.
  String displayStatusOf(OrderDetailLine orderDetailLine) =>
      getInvoicedLines(orderDetailLine.item).isNotEmpty
          ? 'Dispatched'
          : orderDetailLine.status;

  Map<String, int> get lineStatusCounts {
    final counts = <String, int>{};

    for (final orderDetailLine in primaryOrderDetailLines) {
      final status = displayStatusOf(orderDetailLine);

      counts[status] = (counts[status] ?? 0) + 1;
    }

    return counts;
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
