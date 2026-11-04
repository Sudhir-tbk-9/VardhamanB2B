import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:toastification/toastification.dart';
import 'package:vardhman_b2b/api/api.dart';
import 'package:vardhman_b2b/api/sampling_feedback.dart';
import 'package:vardhman_b2b/api/order_detail_line.dart';
import 'package:vardhman_b2b/api/order_header_line.dart';
import 'package:vardhman_b2b/constants.dart';
import 'package:vardhman_b2b/drift/database.dart';
import 'package:vardhman_b2b/orders/order_list_filters.dart';
import 'package:vardhman_b2b/orders/orders_controller.dart';
import 'package:vardhman_b2b/user/user_controller.dart';

class SamplingController extends GetxController with OrderListFilters {
  @override
  final OrdersController ordersController = Get.find<OrdersController>();

  @override
  final rxEarliestOrderDate = oldestDateTime.obs;

  @override
  final rxOrderFromDate = oldestDateTime.obs;

  @override
  final rxOrderToDate = DateTime.now().obs;

  @override
  final rxOrderNumberInput = ''.obs;

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
      orderHeaderLine.orderType == 'SA' && orderHeaderLine.isDTM == true;

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

  final rxDraftOrders = <DraftTableData>[].obs;

  final rxSelectedOrderHeaderLine = Rxn<OrderHeaderLine>();

  final rxOrderDetailLines = <OrderDetailLine>[].obs;

  final rxOrderDetailFeedbackMap = <OrderDetailLine, SamplingFeedback>{}.obs;

  final rxSamplingFeedbacks = <SamplingFeedback>[].obs;

  final Database _database = Get.find<Database>();

  final UserController _userController =
      Get.find<UserController>(tag: 'userController');

  SamplingController() {
    _database.managers.draftTable
        .filter(
          (f) => f.orderType.equals('LD'),
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
            samplingOrders.lastOrNull?.orderDate ?? oldestDateTime;

        rxOrderFromDate.value =
            samplingOrders.lastOrNull?.orderDate ?? oldestDateTime;

        // A quick range such as This Month outlasts a reload.
        reapplyDateRange();

        refreshSamplingFeedbacks();
      },
    );
  }

  Future<void> refreshOrders() async {
    await ordersController.refreshOrders();
  }

  Future<void> selectOrder(OrderHeaderLine orderHeaderLine) async {
    rxSelectedOrderHeaderLine.value = orderHeaderLine;

    await refreshSelectedOrderDetails();
  }

  final _rxDetailsLoadCount = 0.obs;

  /// True while the selected order's lines are being fetched from JDE.
  bool get isLoadingDetails => _rxDetailsLoadCount.value > 0;

  Future<void> refreshSelectedOrderDetails() async {
    rxOrderDetailLines.clear();

    rxOrderDetailFeedbackMap.clear();

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

  Future<void> refreshSamplingFeedbacks() async {
    final samplingFeedbacks = await Api.fetchSamplingFeedback(
      samplingOrders
          .map((orderHeaderLine) => orderHeaderLine.orderNumber)
          .toList(),
    );

    rxSamplingFeedbacks.assignAll(samplingFeedbacks);
  }

  Future<bool> fetchSelectedOrderFeedbacks() async {
    var orderNumbers = rxOrderDetailFeedbackMap.keys
        .map((orderDetailLine) => orderDetailLine.orderNumber)
        .toList();
    var lineNumbers = rxOrderDetailFeedbackMap.keys
        .map((orderDetailLine) => orderDetailLine.lineNumber)
        .toList();
    final samplingFeedbacks = await Api.fetchIndividualSamplingOrderFeedback(
        orderNumbers, lineNumbers);
    if (samplingFeedbacks.isEmpty) {
      return false;
    }
    return true;
  }

  Future<void> submitFeedback() async {
    final UserController userController =
        Get.find<UserController>(tag: 'userController');

    var orderReferenceNumberOriginal =
        rxSelectedOrderHeaderLine.value!.orderReference;

    var orderReferenceNumber = orderReferenceNumberOriginal.split('-').first;

    final nextOrderNumber =
        await Api.fetchSamplingRejectionCount(orderReferenceNumber);

    var b2bRejectionOrderNumber =
        '$orderReferenceNumber-R${nextOrderNumber.length + 1}';

    rxOrderDetailFeedbackMap.forEach(
      (orderDetailLine, samplingFeedback) async {
        await Api.submitSamplingFeedback(
          orderDetailLine: orderDetailLine,
          samplingFeedback: samplingFeedback,
          orderReferenceNumber: orderReferenceNumber,
        );
      },
    );

    rxOrderDetailFeedbackMap.removeWhere(
      (orderDetailLine, samplingFeedback) => !samplingFeedback.shouldRematch,
    );

    if (rxOrderDetailFeedbackMap.isNotEmpty) {
      final orderDetailLinesReasonMap = rxOrderDetailFeedbackMap.map(
        (orderDetailLine, samplingFeedback) => MapEntry(
          orderDetailLine,
          samplingFeedback.reason,
        ),
      );

      final isSubmitted = await Api.submitSamplingRematchOrder(
        merchandiserName: rxSelectedOrderHeaderLine.value!.merchandiser,
        b2bOrderNumber: b2bRejectionOrderNumber,
        branchPlant: userController.branchPlant,
        soldTo: userController.rxCustomerDetail.value.soldToNumber,
        // shipTo:
        //     (userController.rxDeliveryAddress.value?.deliveryAddressNumber == 0
        //             ? userController.rxCustomerDetail.value.soldToNumber
        //             : userController
        //                 .rxDeliveryAddress.value?.deliveryAddressNumber)
        //         .toString(),
        shipTo: userController.rxCustomerDetail.value.soldToNumber,
        company: userController.rxCustomerDetail.value.companyCode,
        orderTakenBy: userController.rxUserDetail.value.role,
        orderDetailLinesReasonMap: orderDetailLinesReasonMap,
      );

      if (isSubmitted) {
        rxOrderDetailFeedbackMap.clear();

        toastification.show(
          autoCloseDuration: Duration(minutes: 15),
          primaryColor: VardhmanColors.green,
          title: Text(
            'Rematch order $b2bRejectionOrderNumber placed successfully!',
          ),
        );

        if (userController.rxCustomerDetail.value.canSendSMS) {
          Api.sendOrderEntrySMS(
            orderNumber: b2bRejectionOrderNumber,
            mobileNumber: userController.rxCustomerDetail.value.mobileNumber,
          );
        }

        if (userController.rxCustomerDetail.value.canSendWhatsApp) {
          Api.sendOrderEntryWhatsApp(
            orderNumber: b2bRejectionOrderNumber,
            mobileNumber: userController.rxCustomerDetail.value.mobileNumber,
          );
        }
      } else {
        toastification.show(
          autoCloseDuration: Duration(seconds: 3),
          primaryColor: VardhmanColors.red,
          title: Text(
            'Some error placing the order!',
          ),
        );
      }
    }

    await refreshSamplingFeedbacks();

    Get.back();
  }

  List<OrderDetailLine> get primaryOrderDetailLines {
    return rxOrderDetailLines.where(
      (orderDetailLine) {
        return orderDetailLine.workOrderNumber > 0 &&
            orderDetailLine.catalogName.trim().isEmpty;
      },
    ).toList();
  }

  OrderDetailLine? getPermanentShadeLine(int workOrderNumber) {
    var tempA = rxOrderDetailLines.firstWhereOrNull(
      (detailLine) =>
          detailLine.catalogName.endsWith(workOrderNumber.toString()),
    );
    if (tempA != null) {
      return tempA;
    }

    var tempB = rxOrderDetailLines.firstWhereOrNull(
      (detailLine) => detailLine.workOrderNumber == workOrderNumber,
    );

    return rxOrderDetailLines.firstWhereOrNull(
      (detailLine) => detailLine.item == tempB?.item,
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

  List<OrderHeaderLine> get samplingOrders => rxOrders;

  List<OrderHeaderLine> get filteredSamplingOrders => rxFilteredOrders;

  @override
  bool get hasDefaultValues =>
      areDatesEqual(
        rxOrderFromDate.value,
        rxEarliestOrderDate.value,
      ) &&
      areDatesEqual(rxOrderToDate.value, DateTime.now()) &&
      rxOrderNumberInput.value.isEmpty &&
      rxMerchandiserInput.value.isEmpty &&
      rxShadeInput.value.isEmpty &&
      rxBuyerInput.value.isEmpty;

  @override
  Future<void> setDefaultValues() async {
    rxOrderFromDate.value = rxEarliestOrderDate.value;

    rxDateRange.value = null;

    rxOrderToDate.value = DateTime.now();

    rxOrderNumberInput.value = '';

    rxMerchandiserInput.value = '';

    rxShadeInput.value = '';

    rxBuyerInput.value = '';
  }
}
