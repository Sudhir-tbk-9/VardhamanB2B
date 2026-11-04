import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vardhman_b2b/api/api.dart';
import 'package:vardhman_b2b/api/buyer_info.dart';
import 'package:vardhman_b2b/api/order_detail_line.dart';
import 'package:vardhman_b2b/api/order_header_line.dart';
import 'package:vardhman_b2b/user/user_controller.dart';

class OrdersController extends GetxController
    with GetSingleTickerProviderStateMixin {
  final _userController = Get.find<UserController>(tag: 'userController');

  final rxOrderHeaderLines = <OrderHeaderLine>[].obs;

  final rxSelectedOrder = Rxn<OrderHeaderLine>();

  final rxSelectedOrderDetails = <OrderDetailLine>[].obs;

  late final tabController = TabController(length: 4, vsync: this);

  OrdersController() {
    init();
  }

  Future<void> init() async {
    _userController.rxCustomerDetail.listenAndPump(
      (_) {
        refreshOrders();
      },
    );
  }

  final _rxLoadCount = 0.obs;

  /// True while the order headers are being fetched from JDE.
  bool get isLoading => _rxLoadCount.value > 0;

  Future<void> refreshOrders() async {
    _orderDetailLinesCache.clear();

    final customerSoldToNumber =
        _userController.rxCustomerDetail.value.soldToNumber;

    _rxLoadCount.value++;

    final List<OrderHeaderLine> orderHeaderLines;

    try {
      orderHeaderLines =
          await Api.fetchOrders(soldToNumber: customerSoldToNumber);
    } finally {
      _rxLoadCount.value--;
    }

    orderHeaderLines.sort(
      (a, b) {
        int compareToResult = b.orderDate.compareTo(a.orderDate);

        if (compareToResult != 0) {
          return compareToResult;
        }

        return b.orderNumber.compareTo(a.orderNumber);
      },
    );

    // One update: every order list and its listeners rebuild once.
    rxOrderHeaderLines.assignAll(orderHeaderLines);
  }

  /// Detail lines per order (ORCH5542002_GetOrderDetail), cached for line
  /// level searches (shade / buyer) on the order lists.
  final _orderDetailLinesCache = <String, List<OrderDetailLine>>{};

  final _buyerInfos = <BuyerInfo>[];

  Future<List<OrderDetailLine>> _orderDetailLinesOf(
      OrderHeaderLine orderHeaderLine) async {
    final key =
        '${orderHeaderLine.orderNumber}|${orderHeaderLine.orderType}|${orderHeaderLine.orderCompany}';

    return _orderDetailLinesCache[key] ??= await Api.fetchOrderDetails(
      orderNumber: orderHeaderLine.orderNumber,
      orderType: orderHeaderLine.orderType,
      orderCompany: orderHeaderLine.orderCompany,
    );
  }

  /// Order numbers among [orderHeaderLines] having a line whose shade contains
  /// [shade] and whose buyer (End Use code, or its F00092 BY name) contains
  /// [buyer]. Empty criteria match everything.
  ///
  /// Each order not cached yet costs an ORCH5542002 call, so the search stops
  /// as soon as [isCancelled] says a newer search replaced it, and reports the
  /// share of orders checked so far through [onProgress].
  Future<Set<int>> findOrdersByLine({
    required List<OrderHeaderLine> orderHeaderLines,
    required String shade,
    required String buyer,
    bool Function()? isCancelled,
    void Function(double progress)? onProgress,
  }) async {
    final shadeQuery = shade.trim().toUpperCase();

    final buyerQuery = buyer.trim().toUpperCase();

    if (buyerQuery.isNotEmpty && _buyerInfos.isEmpty) {
      _buyerInfos.addAll(await Api.fetchBuyerInfos());
    }

    final matchingOrderNumbers = <int>{};

    const batchSize = 5;

    for (int i = 0; i < orderHeaderLines.length; i += batchSize) {
      if (isCancelled?.call() ?? false) {
        break;
      }

      await Future.wait(
        orderHeaderLines.skip(i).take(batchSize).map(
          (orderHeaderLine) async {
            final orderDetailLines = await _orderDetailLinesOf(orderHeaderLine);

            final hasMatch = orderDetailLines.any(
              (orderDetailLine) {
                final itemParts =
                    orderDetailLine.item.trim().split(RegExp('\\s+'));

                final lineShade = itemParts.length > 2 ? itemParts[2] : '';

                final buyerCode = orderDetailLine.buyerCode.trim();

                final buyerName = _buyerInfos
                        .firstWhereOrNull(
                            (buyerInfo) => buyerInfo.code.trim() == buyerCode)
                        ?.name ??
                    '';

                return lineShade.toUpperCase().contains(shadeQuery) &&
                    (buyerCode.toUpperCase().contains(buyerQuery) ||
                        buyerName.toUpperCase().contains(buyerQuery));
              },
            );

            if (hasMatch) {
              matchingOrderNumbers.add(orderHeaderLine.orderNumber);
            }
          },
        ),
      );

      onProgress?.call(
        (i + batchSize).clamp(0, orderHeaderLines.length) /
            orderHeaderLines.length,
      );
    }

    return matchingOrderNumbers;
  }

  // List<OrderHeaderLine> get inProgressOrders => filteredOrderHeaderLines
  //     .where(
  //       (orderStatusData) =>
  //           orderStatusData.orderStatus == 'In Progress' ||
  //           orderStatusData.orderStatus == 'Partially Dispatched',
  //     )
  //     .toList();

  // List<OrderHeaderLine> get holdOrders => filteredOrderHeaderLines
  //     .where(
  //       (orderStatusData) => orderStatusData.orderStatus == 'Hold',
  //     )
  //     .toList();

  // List<OrderHeaderLine> get cancelledOrders => filteredOrderHeaderLines
  //     .where(
  //       (orderStatusData) => orderStatusData.orderStatus == 'Cancelled',
  //     )
  //     .toList();

  // List<OrderHeaderLine> get dispatchedOrders => filteredOrderHeaderLines
  //     .where(
  //       (orderStatusData) =>
  //           orderStatusData.orderStatus == 'Dispatched' ||
  //           orderStatusData.orderStatus == 'Partially Dispatched',
  //     )
  //     .toList();
}
