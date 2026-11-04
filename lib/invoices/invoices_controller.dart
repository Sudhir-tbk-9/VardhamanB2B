import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vardhman_b2b/api/api.dart';
import 'package:vardhman_b2b/api/invoice_info.dart';
import 'package:vardhman_b2b/constants.dart';
import 'package:vardhman_b2b/user/user_controller.dart';

class InvoicesController extends GetxController
    with GetSingleTickerProviderStateMixin {
  final _userController = Get.find<UserController>(tag: 'userController');

  final _rxInvoiceInfos = RxList<InvoiceInfo>();

  final rxEarliestInvoiceDate = oldestDateTime.obs;

  final rxInvoiceFromDate = oldestDateTime.obs;

  final rxInvoiceToDate = DateTime.now().obs;

  final rxEarliestReceiptDate = oldestDateTime.obs;

  final rxReceiptFromDate = oldestDateTime.obs;

  final rxReceiptToDate = DateTime.now().obs;

  final rxInvoiceNumberInput = ''.obs;

  /// Customer PO per sales order, keyed by `orderNumber|orderType`, from
  /// ORCH5542001_GetOrderStatus.CustomerPO.
  final rxPoNumbers = <String, String>{}.obs;

  final rxSelectedInvoiceInfos = <InvoiceInfo>[].obs;

  final invoiceNumberTextEditingController = TextEditingController();

  final invoicesOlderThanTextEditingController = TextEditingController();

  final rxAdvancePaymentAmount = 0.0.obs;

  final advancePaymentInputController = TextEditingController(
    text: '0',
  );

  late final tabController = TabController(
    length: 3,
    vsync: this,
  );

  DateTime? previousFromDate;

  InvoicesController() {
    init();
  }

  Future<void> init() async {
    _userController.rxCustomerDetail.listenAndPump(
      (_) async {
        await refreshInvoices();

        clearOpenFilters();

        clearPaidFilters();
      },
    );
  }

  final _rxLoadCount = 0.obs;

  /// True while invoices are being fetched from JDE.
  bool get isLoading => _rxLoadCount.value > 0;

  Future<void> refreshInvoices() async {
    _rxLoadCount.value++;

    try {
      await _loadInvoices();
    } finally {
      _rxLoadCount.value--;
    }

    _loadLastPayment();
  }

  Future<void> _loadInvoices() async {
    final customerSoldToNumber =
        _userController.rxCustomerDetail.value.soldToNumber;

    final invoiceInfos = await Api.fetchInvoices(
      customerNumber: customerSoldToNumber,
      company: _userController.rxCustomerDetail.value.companyCode,
    );

    if (invoiceInfos.isNotEmpty) {
      final invoicesInProcessing =
          await Api.fetchInvoicesInProcessing(customerSoldToNumber);

      final processedInvoiceInfos = invoiceInfos.map(
        (invoiceInfo) {
          InvoiceInfo processedInvoiceInfo =
              getInvoiceInfoWithStatusAndDiscount(invoiceInfo);

          if (invoiceInfo.isOpen &&
              invoicesInProcessing.contains(invoiceInfo.invoiceNumber)) {
            processedInvoiceInfo = processedInvoiceInfo.copyWith(
              status: InvoiceStatus.processing,
            );
          }

          return processedInvoiceInfo;
        },
      ).toList();

      _rxInvoiceInfos.clear();

      processedInvoiceInfos.sort(
        (a, b) => a.date.compareTo(b.date) == 0
            ? a.invoiceNumber.compareTo(b.invoiceNumber)
            : a.date.compareTo(b.date),
      );

      _rxInvoiceInfos.addAll(processedInvoiceInfos);

      _refreshPoNumbers(
        soldToNumber: customerSoldToNumber,
        fromDate: processedInvoiceInfos.first.date,
      );

      rxEarliestInvoiceDate.value =
          openInvoices.isEmpty ? oldestDateTime : openInvoices.first.date;

      rxEarliestReceiptDate.value =
          paidInvoices.isEmpty ? oldestDateTime : paidInvoices.last.receiptDate;
    } else {
      _rxInvoiceInfos.clear();

      rxPoNumbers.clear();

      rxEarliestInvoiceDate.value = oldestDateTime;

      rxEarliestReceiptDate.value = oldestDateTime;
    }
  }

  Future<void> _refreshPoNumbers({
    required String soldToNumber,
    required DateTime fromDate,
  }) async {
    final orderHeaderLines = await Api.fetchOrders(
      soldToNumber: soldToNumber,
      fromDate: fromDate.subtract(const Duration(days: 180)),
    );

    rxPoNumbers.assignAll({
      for (final orderHeaderLine in orderHeaderLines)
        if (orderHeaderLine.poNumber.trim().isNotEmpty)
          '${orderHeaderLine.orderNumber}|${orderHeaderLine.orderType}':
              orderHeaderLine.poNumber.trim(),
    });
  }

  String poNumberOf(InvoiceInfo invoiceInfo) =>
      rxPoNumbers[
          '${invoiceInfo.salesOrderNumber}|${invoiceInfo.salesOrderType}'] ??
      '';

  final rxPoNumberInput = ''.obs;

  final poNumberTextEditingController = TextEditingController();

  bool _matchesSearch(InvoiceInfo invoiceInfo) {
    final invoiceInput = rxInvoiceNumberInput.value.trim();

    final poInput = rxPoNumberInput.value.trim().toLowerCase();

    return invoiceInfo.invoiceNumber.toString().contains(invoiceInput) &&
        poNumberOf(invoiceInfo).toLowerCase().contains(poInput);
  }

  /// Open invoices that can be paid now (not credit notes, on hold or
  /// already in payment processing).
  bool _isPayable(InvoiceInfo invoiceInfo) =>
      invoiceInfo.status == InvoiceStatus.overdue ||
      invoiceInfo.status == InvoiceStatus.notDue ||
      invoiceInfo.status == InvoiceStatus.discounted;

  /// Selects every payable open invoice whose sales order carries
  /// [poNumber] (CustomerPO from ORCH5542001). Returns how many were added.
  int selectInvoicesByPoNumber(String poNumber) {
    final po = poNumber.trim().toLowerCase();

    if (po.isEmpty) {
      return 0;
    }

    final matches = openInvoices
        .where(
          (invoiceInfo) =>
              _isPayable(invoiceInfo) &&
              poNumberOf(invoiceInfo).toLowerCase() == po &&
              !rxSelectedInvoiceInfos.contains(invoiceInfo),
        )
        .toList();

    matches.forEach(addInvoiceToSelected);

    return matches.length;
  }

  final _sharedPrefs = Get.find<SharedPreferences>();

  String get _lastPaymentKey =>
      'lastInvoicePayment_${_userController.rxCustomerDetail.value.soldToNumber}';

  /// Last invoice payment started from this browser: receipt number and,
  /// per invoice, the amount paid and the JDE open amount at that time.
  final rxLastPayment = Rxn<Map<String, dynamic>>();

  void _loadLastPayment() {
    final json = _sharedPrefs.getString(_lastPaymentKey);

    rxLastPayment.value =
        json == null ? null : jsonDecode(json) as Map<String, dynamic>;
  }

  Future<void> recordPayment({
    required int batchNumber,
    required String receiptNumber,
    required List<InvoiceInfo> invoiceInfos,
  }) async {
    final payment = {
      'batchNumber': batchNumber,
      'receiptNumber': receiptNumber,
      'date': DateTime.now().toIso8601String(),
      'invoices': invoiceInfos
          .map(
            (invoiceInfo) => {
              'invoiceNumber': invoiceInfo.invoiceNumber,
              'docType': invoiceInfo.docType,
              'company': invoiceInfo.company,
              'poNumber': poNumberOf(invoiceInfo),
              'openAmount': invoiceInfo.openAmount,
              'paymentAmount': invoiceInfo.status == InvoiceStatus.discounted
                  ? invoiceInfo.discountAmount
                  : invoiceInfo.openAmount,
            },
          )
          .toList(),
    };

    await _sharedPrefs.setString(_lastPaymentKey, jsonEncode(payment));

    rxLastPayment.value = payment;
  }

  /// With [receiptNumber], only when the saved last payment is that receipt.
  /// Read from storage rather than [rxLastPayment], which is only loaded
  /// once the invoices have been fetched.
  Future<void> dismissLastPayment({String? receiptNumber}) async {
    if (receiptNumber != null) {
      final json = _sharedPrefs.getString(_lastPaymentKey);

      if (json == null ||
          (jsonDecode(json) as Map<String, dynamic>)['receiptNumber'] !=
              receiptNumber) {
        return;
      }
    }

    await _sharedPrefs.remove(_lastPaymentKey);

    rxLastPayment.value = null;
  }

  /// Knock-off of one invoice of the last payment, read from JDE: the
  /// invoice's current open amount and status (ORCH5503B11A_GetInvoices,
  /// F550313Z processing) and the receipt applied to it (F03B14 CKNU/DMTJ).
  KnockOff knockOffOf(Map<String, dynamic> paidInvoice) {
    final invoiceInfo = _rxInvoiceInfos.firstWhereOrNull(
      (invoiceInfo) =>
          invoiceInfo.invoiceNumber == paidInvoice['invoiceNumber'] &&
          invoiceInfo.docType == paidInvoice['docType'] &&
          invoiceInfo.company == paidInvoice['company'],
    );

    final openAmountAtPayment = (paidInvoice['openAmount'] as num).toDouble();

    if (invoiceInfo == null) {
      return KnockOff(
        status: 'Not returned by JDE',
        knockedOffAmount: 0,
        openAmount: null,
        receiptNumber: '',
        receiptDate: null,
      );
    }

    final openAmount =
        invoiceInfo.status == InvoiceStatus.paid ? 0.0 : invoiceInfo.openAmount;

    final hasReceipt = invoiceInfo.receiptNumber.trim().isNotEmpty;

    return KnockOff(
      status: invoiceInfo.status == InvoiceStatus.paid
          ? 'Knocked off'
          : invoiceInfo.status == InvoiceStatus.processing
              ? 'Processing in JDE'
              : openAmount < openAmountAtPayment
                  ? 'Partly knocked off'
                  : 'Not knocked off yet',
      knockedOffAmount:
          (openAmountAtPayment - openAmount).clamp(0, double.infinity),
      openAmount: openAmount,
      receiptNumber: hasReceipt ? invoiceInfo.receiptNumber : '',
      receiptDate: hasReceipt ? invoiceInfo.receiptDate : null,
    );
  }

  List<InvoiceInfo> get creditNotes => filteredOpenInvoices
      .where(
        (invoiceInfo) => invoiceInfo.status == InvoiceStatus.creditNote,
      )
      .toList();

  List<InvoiceInfo> get overdueInvoices => filteredOpenInvoices
      .where(
        (invoiceInfo) => invoiceInfo.status == InvoiceStatus.overdue,
      )
      .toList();

  List<InvoiceInfo> get notDueInvoices => filteredOpenInvoices
      .where(
        (invoiceInfo) => invoiceInfo.status == InvoiceStatus.notDue,
      )
      .toList();

  List<InvoiceInfo> get dueInvoices => [
        ...notDueInvoices,
        ...discountedInvoices,
        ...heldInvoices,
      ];

  List<InvoiceInfo> get discountedInvoices => filteredOpenInvoices
      .where(
        (invoiceInfo) => invoiceInfo.status == InvoiceStatus.discounted,
      )
      .toList();

  List<InvoiceInfo> get processingInvoices => filteredOpenInvoices
      .where(
        (invoiceInfo) => invoiceInfo.status == InvoiceStatus.processing,
      )
      .toList();

  List<InvoiceInfo> get heldInvoices => filteredOpenInvoices
      .where(
        (invoiceInfo) => invoiceInfo.status == InvoiceStatus.onHold,
      )
      .toList();

  void addInvoiceToSelected(InvoiceInfo invoiceInfo) {
    if (!rxSelectedInvoiceInfos.contains(invoiceInfo)) {
      rxSelectedInvoiceInfos.add(invoiceInfo);

      rxSelectedInvoiceInfos.sort(
        (a, b) => a.discountDueDate.compareTo(b.discountDueDate) == 0
            ? a.invoiceNumber.compareTo(b.invoiceNumber)
            : a.discountDueDate.compareTo(b.discountDueDate),
      );
    }
  }

  void removeInvoiceFromSelected(InvoiceInfo invoiceInfo) {
    rxSelectedInvoiceInfos.remove(invoiceInfo);
  }

  double getTotalAmount(InvoiceStatus invoiceStatus) {
    return _rxInvoiceInfos
        .fold(
          0.0,
          (previousValue, invoiceInfo) =>
              previousValue +
              (invoiceInfo.status == invoiceStatus
                  ? invoiceInfo.openAmount
                  : 0),
        )
        .toPrecision(2);
  }

  double get totalOverdueAmount => getTotalAmount(InvoiceStatus.overdue);

  double get totalNotDueAmount => getTotalAmount(InvoiceStatus.notDue);

  double get totalCreditNoteAmount => getTotalAmount(InvoiceStatus.creditNote);

  double get totalDiscountedAmount => getTotalAmount(InvoiceStatus.discounted);

  double get totalProcessingAmount => getTotalAmount(InvoiceStatus.processing);

  double get totalHeldAmount => getTotalAmount(InvoiceStatus.onHold);

  List<InvoiceInfo> get openInvoices => _rxInvoiceInfos
      .where((invoiceInfo) => invoiceInfo.status != InvoiceStatus.paid)
      .toList();

  double get totalOpenAmount => openInvoices
      .where(
        (invoiceInfo) =>
            invoiceInfo.status != InvoiceStatus.processing &&
            invoiceInfo.status != InvoiceStatus.creditNote,
      )
      .fold(
        0.0,
        (previousValue, invoiceInfo) =>
            previousValue +
            (invoiceInfo.status == InvoiceStatus.discounted
                ? invoiceInfo.discountAmount
                : invoiceInfo.openAmount),
      )
      .toPrecision(2);

  double get selectedTotalAmount => rxSelectedInvoiceInfos
      .fold(
        0.0,
        (previousValue, element) => previousValue + element.openAmount,
      )
      .toPrecision(2);

  double get selectedDiscountedAmount => rxSelectedInvoiceInfos.fold(
        0.0,
        (previousValue, invoiceInfo) {
          if (invoiceInfo.status == InvoiceStatus.discounted) {
            return previousValue + invoiceInfo.discountAmount;
          } else {
            return previousValue + invoiceInfo.openAmount;
          }
        },
      ).toPrecision(2);

  bool get hasFilters =>
      areDatesEqual(
        rxInvoiceFromDate.value,
        rxEarliestInvoiceDate.value,
      ) &&
      areDatesEqual(rxInvoiceToDate.value, DateTime.now()) &&
      rxInvoiceNumberInput.value.isEmpty &&
      rxPoNumberInput.value.isEmpty;

  void clearOpenFilters() {
    rxInvoiceFromDate.value = rxEarliestInvoiceDate.value;

    rxInvoiceToDate.value = DateTime.now();

    rxInvoiceNumberInput.value = '';

    invoiceNumberTextEditingController.clear();

    rxPoNumberInput.value = '';

    poNumberTextEditingController.clear();
    invoicesOlderThanTextEditingController.clear();
  }

  void clearPaidFilters() {
    rxReceiptFromDate.value = rxEarliestReceiptDate.value;

    rxReceiptToDate.value = DateTime.now();

    rxInvoiceNumberInput.value = '';

    invoiceNumberTextEditingController.clear();

    rxPoNumberInput.value = '';

    poNumberTextEditingController.clear();
  }

  List<InvoiceInfo> get paidInvoices => _rxInvoiceInfos
      .where((invoiceInfo) => invoiceInfo.status == InvoiceStatus.paid)
      .toList()
    ..sort(
      (a, b) => b.receiptDate.compareTo(a.receiptDate) == 0
          ? a.invoiceNumber.compareTo(b.invoiceNumber)
          : b.receiptDate.compareTo(a.receiptDate),
    );

  List<InvoiceInfo> get filteredPaidInvoices {
    List<InvoiceInfo> filteredInvoices = paidInvoices
        .where(
          (invoiceInfo) =>
              _matchesSearch(invoiceInfo) &&
              invoiceInfo.receiptDate.isAfter(
                rxReceiptFromDate.value.subtract(
                  const Duration(days: 1),
                ),
              ) &&
              invoiceInfo.receiptDate.isBefore(
                rxReceiptToDate.value.add(
                  const Duration(days: 1),
                ),
              ),
        )
        .toList();

    return filteredInvoices;
  }

  List<InvoiceInfo> get filteredOpenInvoices => openInvoices
      .where(
        (invoiceInfo) =>
            _matchesSearch(invoiceInfo) &&
            invoiceInfo.date.isAfter(
              rxInvoiceFromDate.value.subtract(
                const Duration(days: 1),
              ),
            ) &&
            invoiceInfo.date.isBefore(
              rxInvoiceToDate.value.add(
                const Duration(days: 1),
              ),
            ),
      )
      .toList();

  int get daysBetweenNowAndToDate =>
      DateTime.now().difference(rxInvoiceToDate.value).inDays;
}

class KnockOff {
  final String status;

  final double knockedOffAmount;

  /// Current JDE open amount, or null when JDE no longer returns the invoice.
  final double? openAmount;

  final String receiptNumber;

  final DateTime? receiptDate;

  KnockOff({
    required this.status,
    required this.knockedOffAmount,
    required this.openAmount,
    required this.receiptNumber,
    required this.receiptDate,
  });
}
