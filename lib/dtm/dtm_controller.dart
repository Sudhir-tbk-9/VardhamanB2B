import 'package:get/get.dart';
import 'package:vardhman_b2b/api/api.dart';
import 'package:vardhman_b2b/api/order_detail_line.dart';
import 'package:vardhman_b2b/api/order_header_line.dart';
import 'package:vardhman_b2b/constants.dart';
import 'package:vardhman_b2b/drift/database.dart';
import 'package:vardhman_b2b/orders/orders_controller.dart';
import 'package:vardhman_b2b/user/user_controller.dart';

class DtmController extends GetxController {
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

  final rxEarliestOrderDate = oldestDateTime.obs;

  final rxOrderFromDate = oldestDateTime.obs;

  final rxOrderToDate = DateTime.now().obs;

  final rxOrderNumberInput = ''.obs;

  final rxPoNumberInput = ''.obs;

  final rxMerchandiserInput = ''.obs;

  final rxShadeInput = ''.obs;

  final rxBuyerInput = ''.obs;

  /// Orders having a line matching the shade / buyer inputs, or null when
  /// neither is entered.
  final rxLineSearchMatches = Rxn<Set<int>>();

  @override
  void onInit() {
    super.onInit();

    debounce(rxShadeInput, (_) => _searchByLine(),
        time: const Duration(milliseconds: 600));

    debounce(rxBuyerInput, (_) => _searchByLine(),
        time: const Duration(milliseconds: 600));

    everAll([rxOrderFromDate, rxOrderToDate], (_) => _searchByLine());
  }

  Future<void> _searchByLine() async {
    final shade = rxShadeInput.value;

    final buyer = rxBuyerInput.value;

    if (shade.trim().isEmpty && buyer.trim().isEmpty) {
      rxLineSearchMatches.value = null;

      return;
    }

    final matches = await ordersController.findOrdersByLine(
      orderHeaderLines: dtmOrders
          .where(
            (orderHeaderLine) =>
                orderHeaderLine.orderDate.isAfter(
                  rxOrderFromDate.value.subtract(const Duration(days: 1)),
                ) &&
                orderHeaderLine.orderDate.isBefore(
                  rxOrderToDate.value.add(const Duration(days: 1)),
                ),
          )
          .toList(),
      shade: shade,
      buyer: buyer,
    );

    if (shade == rxShadeInput.value && buyer == rxBuyerInput.value) {
      rxLineSearchMatches.value = matches;
    }
  }

  final rxDraftOrders = <DraftTableData>[].obs;

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

    ordersController.rxOrderHeaderLines.listen(
      (orderHeaderLines) {
        rxEarliestOrderDate.value =
            dtmOrders.lastOrNull?.orderDate ?? oldestDateTime;

        rxOrderFromDate.value =
            dtmOrders.lastOrNull?.orderDate ?? oldestDateTime;
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

  List<OrderHeaderLine> get dtmOrders => ordersController.rxOrderHeaderLines
      .where(
        (orderHeaderLine) =>
            orderHeaderLine.orderType == 'SW' && orderHeaderLine.isDTM,
      )
      .toList();

  List<OrderHeaderLine> get filteredDtmOrders => dtmOrders
      .where((orderHeaderLine) =>
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
          (rxLineSearchMatches.value?.contains(orderHeaderLine.orderNumber) ??
              true) &&
          orderHeaderLine.poNumber.contains(rxPoNumberInput.value))
      .toList();

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

  Future<void> setDefaultValues() async {
    rxOrderFromDate.value = rxEarliestOrderDate.value;

    rxOrderToDate.value = DateTime.now();

    rxOrderNumberInput.value = '';

    rxPoNumberInput.value = '';

    rxMerchandiserInput.value = '';

    rxShadeInput.value = '';

    rxBuyerInput.value = '';
  }
}
