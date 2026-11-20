import 'dart:ffi' show DynamicLibrary;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
// ignore: depend_on_referenced_packages
import 'package:sqlite3/open.dart';
import 'package:vardhman_b2b/api/order_detail_line.dart';
import 'package:vardhman_b2b/api/order_header_line.dart';
import 'package:vardhman_b2b/drift/database.dart';
import 'package:vardhman_b2b/dtm/dtm_controller.dart';
import 'package:vardhman_b2b/orders/orders_controller.dart';
import 'package:vardhman_b2b/user/user_controller.dart';

class _FakeUserController extends GetxController implements UserController {
  @override
  final rxUserDetail = UserDetail(
    soldToNumber: '1001',
    isMobileUser: false,
    mobileNumber: '',
    canSendSMS: false,
    whatsAppNumber: '',
    canSendWhatsApp: false,
    email: '',
    name: 'Buyer',
    companyCode: '',
    companyName: '',
    role: '',
    category: '',
    discountPercent: 0,
  ).obs;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeOrdersController extends GetxController implements OrdersController {
  @override
  final rxOrderHeaderLines = <OrderHeaderLine>[].obs;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// An ORCH5542002 line of a DTM order (SW): [shade] SWT... for the order's
/// own line, or the final shade made for work order [workOrderNumber].
OrderDetailLine _line({
  required double lineNumber,
  required String shade,
  int workOrderNumber = 0,
  String woStatus = '10',
  String catalogName = '',
  int invoiceNumber = 0,
  int quantityShipped = 0,
  double unitPrice = 10,
  double extendedPrice = 0,
}) =>
    OrderDetailLine(
      company: '00001',
      orderNumber: 26036776,
      orderType: 'SW',
      lineNumber: lineNumber,
      dateShipped: null,
      dateInvoiced: invoiceNumber > 0 ? DateTime(2026, 11, 2) : null,
      item: 'RS826 CN $shade',
      itemDescription: '',
      userComment: '',
      nextStatus: '',
      nextStatusDescription: '',
      lastStatus: '',
      lastStatusDescription: '',
      quantityOrdered: 5,
      quantityShipped: quantityShipped,
      quantityCancelled: 0,
      quantityBackordered: 0,
      invoiceNumber: invoiceNumber,
      invoiceType: invoiceNumber > 0 ? 'RI' : '',
      invoiceCompany: '',
      workOrderNumber: workOrderNumber,
      workOrderType: 'W4',
      woStatus: woStatus,
      orderLineReference: 'B2BD100',
      catalogName: catalogName,
      buyerCode: '',
      unitPrice: unitPrice,
      extendedPrice: extendedPrice,
      lightSource1: '',
      shipToAttention: '',
    );

void main() {
  open.overrideFor(
    OperatingSystem.windows,
    () => DynamicLibrary.open('winsqlite3.dll'),
  );

  late Database database;

  late DtmController controller;

  setUp(() {
    database = Get.put(Database.forTesting(NativeDatabase.memory()));
    Get.put<UserController>(_FakeUserController(), tag: 'userController');
    Get.put<OrdersController>(_FakeOrdersController());
    controller = DtmController();

    controller.rxOrderDetailLines.assignAll([
      // Line 1: final shade made (work order 501) and invoiced twice.
      _line(lineNumber: 1, shade: 'SWT001', workOrderNumber: 501),
      _line(lineNumber: 1.1, shade: 'P1001', catalogName: 'WO 501'),
      _line(
        lineNumber: 1.2,
        shade: 'P1001',
        invoiceNumber: 9001,
        quantityShipped: 2,
        unitPrice: 12,
        extendedPrice: 24,
      ),
      _line(
        lineNumber: 1.3,
        shade: 'P1001',
        invoiceNumber: 9002,
        quantityShipped: 3,
        unitPrice: 12,
        extendedPrice: 36,
      ),
      // Line 2: final shade made, not invoiced yet: its status.
      _line(lineNumber: 2, shade: 'SWT002', workOrderNumber: 502),
      _line(
        lineNumber: 2.1,
        shade: 'P2002',
        catalogName: 'WO 502',
        woStatus: '20',
      ),
      // Line 3: no final shade from JDE yet: the line's own status.
      _line(lineNumber: 3, shade: 'SWT003', workOrderNumber: 503),
    ]);
  });

  tearDown(() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await database.close();
    Get.reset();
  });

  test('line values come from the ORCH5542002 lines', () {
    final lines = controller.primaryOrderDetailLines;

    expect(lines.map((line) => line.lineNumber), [1, 2, 3]);

    final invoiced = controller.lineValuesOf(lines[0]);

    expect(invoiced.finalShade, 'P1001');
    expect(invoiced.status, 'Dispatched');
    expect(invoiced.quantityShipped, 5);
    expect(invoiced.unitPrice, 12);
    expect(invoiced.totalPrice, 60);
    expect(
      invoiced.invoicedLines.map((line) => line.invoiceNumber),
      [9001, 9002],
    );

    final made = controller.lineValuesOf(lines[1]);

    expect(made.finalShade, 'P2002');
    expect(made.status, 'Order Received By Plant');
    expect(made.invoicedLines, isEmpty);

    final notMade = controller.lineValuesOf(lines[2]);

    expect(notMade.finalShade, '');
    expect(notMade.status, 'Order Received By Branch');
    expect(notMade.unitPrice, 10);
    expect(notMade.totalPrice, 0);
  });

  test('status chips count the lines; picking one filters the table', () {
    expect(controller.lineStatusCounts, {
      'Dispatched': 1,
      'Order Received By Plant': 1,
      'Order Received By Branch': 1,
    });
    expect(controller.visibleOrderDetailLines, hasLength(3));

    controller.rxLineStatusFilter.value = 'Dispatched';

    expect(controller.lineStatusFilter, 'Dispatched');
    expect(
      controller.visibleOrderDetailLines.map((line) => line.lineNumber),
      [1],
    );

    // A status with no lines (e.g. after a refresh) shows All.
    controller.rxLineStatusFilter.value = 'In Progress';

    expect(controller.lineStatusFilter, isNull);
    expect(controller.visibleOrderDetailLines, hasLength(3));
  });
}
