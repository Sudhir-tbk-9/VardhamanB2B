import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:toastification/toastification.dart';
import 'package:vardhman_b2b/api/api.dart';
import 'package:vardhman_b2b/api/labdip_feedback.dart';
import 'package:vardhman_b2b/api/labdip_table_row.dart';
import 'package:vardhman_b2b/api/order_detail_line.dart';
import 'package:vardhman_b2b/api/order_header_line.dart';
import 'package:vardhman_b2b/constants.dart';
import 'package:vardhman_b2b/drift/database.dart';
import 'package:vardhman_b2b/orders/order_list_filters.dart';
import 'package:vardhman_b2b/orders/orders_controller.dart';
import 'package:vardhman_b2b/user/user_controller.dart';

class LabdipController extends GetxController with OrderListFilters {
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
      orderHeaderLine.orderType == 'LD';

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

  final rxLabdipTableRows = <LabdipTableRow>[].obs;

  final rxSelectedOrderHeaderLine = Rxn<OrderHeaderLine>();

  final rxOrderDetailLines = <OrderDetailLine>[].obs;

  final rxOrderDetailFeedbackMap = <OrderDetailLine, LabdipFeedback>{}.obs;

  final rxLabdipFeedbacks = <LabdipFeedback>[].obs;

  final Database _database = Get.find<Database>();

  final UserController _userController =
      Get.find<UserController>(tag: 'userController');

  LabdipController() {
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
            labdipOrders.lastOrNull?.orderDate ?? oldestDateTime;

        rxOrderFromDate.value =
            labdipOrders.lastOrNull?.orderDate ?? oldestDateTime;

        // A quick range such as This Month outlasts a reload.
        reapplyDateRange();

        refreshLabdipFeedbacks();
      },
    );
  }

  Future<void> refreshOrders() async {
    await ordersController.refreshOrders();
  }

  Future<void> selectOrder(OrderHeaderLine orderHeaderLine) async {
    rxSelectedOrderHeaderLine.value = orderHeaderLine;

    await refreshSelectedOrderDetails();

    _refreshLabdipTableRows();
  }

  Future<void> _refreshLabdipTableRows() async {
    rxLabdipTableRows.clear();

    final labdipTableRows = await Api.fetchLabdipTableRows(
      workOrderNumbers: rxOrderDetailLines
          .map((orderDetailLine) => orderDetailLine.workOrderNumber)
          .toList(),
    );

    rxLabdipTableRows.addAll(labdipTableRows);
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

  Future<void> refreshLabdipFeedbacks() async {
    final labdipFeedbacks = await Api.fetchLabdipFeedback(
      labdipOrders
          .map((orderHeaderLine) => orderHeaderLine.orderNumber)
          .toList(),
    );

    rxLabdipFeedbacks.assignAll(labdipFeedbacks);
  }

  Future<void> submitFeedback() async {
    final UserController userController =
        Get.find<UserController>(tag: 'userController');

    var orderReferenceNumberOriginal =
        rxSelectedOrderHeaderLine.value!.orderReference;

    var orderReferenceNumber = orderReferenceNumberOriginal.split('-').first;

    final nextOrderNumber =
        await Api.fetchLabdipRejectionCount(orderReferenceNumber);

    var b2bRejectionOrderNumber =
        '$orderReferenceNumber-R${nextOrderNumber.length + 1}';

    rxOrderDetailFeedbackMap.forEach(
      (orderDetailLine, labdipFeedback) async {
        await Api.submitLabdipFeedback(
          orderDetailLine: orderDetailLine,
          labdipFeedback: labdipFeedback,
          orderReferenceNumber: orderReferenceNumber,
        );
      },
    );

    rxOrderDetailFeedbackMap.removeWhere(
      (orderDetailLine, labdipFeedback) => !labdipFeedback.shouldRematch,
    );

    if (nextOrderNumber != null && rxOrderDetailFeedbackMap.isNotEmpty) {
      final orderDetailLinesReasonMap = rxOrderDetailFeedbackMap.map(
        (orderDetailLine, labdipFeedback) => MapEntry(
          orderDetailLine,
          labdipFeedback.reason,
        ),
      );

      final isSubmitted = await Api.submitLabDipRematchOrder(
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

    await refreshLabdipFeedbacks();

    Get.back();
  }

  List<LabdipTableRow> getLabdipTableRows(int workOrderNumber) {
    return rxLabdipTableRows
        .where(
          (labdipTableRow) => labdipTableRow.workOrderNumber == workOrderNumber,
        )
        .toList();
  }

  List<OrderHeaderLine> get labdipOrders => rxOrders;

  List<OrderHeaderLine> get filteredLabdipOrders => rxFilteredOrders;

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
