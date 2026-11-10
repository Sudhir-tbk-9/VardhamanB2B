import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:toastification/toastification.dart';
import 'package:vardhman_b2b/api/api.dart';
import 'package:vardhman_b2b/api/buyer_info.dart';
import 'package:vardhman_b2b/api/order_detail_line.dart';
import 'package:vardhman_b2b/api/order_header_line.dart';
import 'package:vardhman_b2b/constants.dart';
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

  Future<void>? _refreshing;

  String? _refreshingSoldToNumber;

  /// Reloads the order headers. A tap while the same customer's orders are
  /// still loading waits for that load instead of starting another.
  Future<void> refreshOrders() async {
    final customerSoldToNumber =
        _userController.rxCustomerDetail.value.soldToNumber;

    if (_refreshing != null &&
        _refreshingSoldToNumber == customerSoldToNumber) {
      return _refreshing;
    }

    final refreshing = _refreshOrders(customerSoldToNumber);

    _refreshing = refreshing;

    _refreshingSoldToNumber = customerSoldToNumber;

    try {
      await refreshing;
    } finally {
      if (identical(_refreshing, refreshing)) {
        _refreshing = null;

        _refreshingSoldToNumber = null;
      }
    }
  }

  /// Reloads the orders after [b2bOrderNumber] (e.g. B2BB30041) was placed,
  /// so it shows without a manual refresh. JDE can take a few seconds to
  /// create the order, so while it is not listed yet the reload is tried
  /// again every [retryDelay], up to [attempts] reloads in all.
  Future<void> refreshUntilListed(
    String b2bOrderNumber, {
    int attempts = 4,
    Duration retryDelay = const Duration(seconds: 10),
  }) async {
    final customerSoldToNumber =
        _userController.rxCustomerDetail.value.soldToNumber;

    for (int attempt = 1; attempt <= attempts; attempt++) {
      if (attempt > 1) {
        await Future.delayed(retryDelay);
      }

      // Logged out, or another customer picked meanwhile.
      if (isClosed ||
          customerSoldToNumber !=
              _userController.rxCustomerDetail.value.soldToNumber) {
        return;
      }

      await refreshOrders();

      if (rxOrderHeaderLines.any(
        (orderHeaderLine) =>
            orderHeaderLine.orderReference.trim() == b2bOrderNumber.trim(),
      )) {
        debugPrint('[ORDERS] $b2bOrderNumber listed after reload $attempt');

        return;
      }
    }

    debugPrint(
        '[ORDERS] $b2bOrderNumber not returned by JDE after $attempts reloads');
  }

  Future<void> _refreshOrders(String customerSoldToNumber) async {
    _rxLoadCount.value++;

    final List<OrderHeaderLine>? orderHeaderLines;

    try {
      orderHeaderLines =
          await Api.fetchOrders(soldToNumber: customerSoldToNumber);
    } finally {
      _rxLoadCount.value--;
    }

    // Another customer was picked meanwhile; its own load fills the lists.
    if (customerSoldToNumber !=
        _userController.rxCustomerDetail.value.soldToNumber) {
      return;
    }

    // A failed load keeps the orders on screen rather than emptying the lists.
    if (orderHeaderLines == null) {
      toastification.show(
        autoCloseDuration: const Duration(seconds: 3),
        primaryColor: VardhmanColors.red,
        title: const Text('Could not refresh orders. Please try again.'),
      );

      return;
    }

    _orderDetailLinesCache.clear();

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
