import 'dart:ffi' show DynamicLibrary;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
// ignore: depend_on_referenced_packages
import 'package:sqlite3/open.dart';
import 'package:vardhman_b2b/api/order_detail_line.dart';
import 'package:vardhman_b2b/api/order_header_line.dart';
import 'package:vardhman_b2b/drift/database.dart';
import 'package:vardhman_b2b/labdip/labdip_controller.dart';
import 'package:vardhman_b2b/orders/order_line_status_filter.dart';
import 'package:vardhman_b2b/sampling/sampling_controller.dart';
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

/// An ORCH5542002 line: [shade] SWT... for the order's
/// own line, or the final shade made for work order [workOrderNumber].
OrderDetailLine _line({
  required double lineNumber,
  required String shade,
  String orderType = 'SA',
  String workOrderType = 'W8',
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
      orderType: orderType,
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
      workOrderType: workOrderType,
      woStatus: woStatus,
      orderLineReference: 'B2BD100',
      catalogName: catalogName,
      buyerCode: '',
      unitPrice: unitPrice,
      extendedPrice: extendedPrice,
      lightSource1: '',
      shipToAttention: '',
    );

/// The chips' logic on its own: each line's status is its item's text.
class _Lines extends GetxController with OrderLineStatusFilter {
  final lines = <OrderDetailLine>[];

  @override
  List<OrderDetailLine> get statusFilterLines => lines;

  @override
  String displayStatusOf(OrderDetailLine orderDetailLine) =>
      orderDetailLine.itemDescription;
}

void main() {
  open.overrideFor(
    OperatingSystem.windows,
    () => DynamicLibrary.open('winsqlite3.dll'),
  );

  late Database database;

  setUp(() {
    database = Get.put(Database.forTesting(NativeDatabase.memory()));
    Get.put<UserController>(_FakeUserController(), tag: 'userController');
    Get.put<OrdersController>(_FakeOrdersController());
  });

  tearDown(() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await database.close();
    Get.reset();
  });

  test('chips count the lines; picking one filters; reset shows All', () {
    final controller = _Lines()
      ..lines.addAll([
        for (final (number, status) in [
          (1.0, 'In Progress'),
          (2.0, 'Dispatched'),
          (3.0, 'In Progress'),
        ])
          _line(lineNumber: number, shade: 'S$number')
              .copyWith(itemDescription: status),
      ]);

    expect(controller.lineStatusCounts, {'In Progress': 2, 'Dispatched': 1});

    controller.rxLineStatusFilter.value = 'In Progress';

    expect(
      controller.visibleOrderDetailLines.map((line) => line.lineNumber),
      [1, 3],
    );

    // A status with no lines shows All.
    controller.rxLineStatusFilter.value = 'Cancelled';

    expect(controller.lineStatusFilter, isNull);
    expect(controller.visibleOrderDetailLines, hasLength(3));

    controller
      ..rxLineStatusFilter.value = 'Dispatched'
      ..resetLineStatusFilter();

    expect(controller.lineStatusFilter, isNull);
  });

  test('Labdip: every line, with its own status', () {
    final controller = LabdipController();

    controller.rxOrderDetailLines.assignAll([
      _line(
        lineNumber: 1,
        shade: 'L1',
        orderType: 'LD',
        workOrderType: 'W6',
        woStatus: '41',
      ),
      _line(
        lineNumber: 2,
        shade: 'L2',
        orderType: 'LD',
        workOrderType: 'W6',
        woStatus: '20',
      ),
    ]);

    expect(controller.lineStatusCounts, {
      'Dispatched By Plant': 1,
      'Order Received By Plant': 1,
    });
  });

  test('Sampling: Dispatched once the final shade is invoiced', () {
    final controller = SamplingController();

    controller.rxOrderDetailLines.assignAll([
      // Sample line 1: final shade made (work order 501) and invoiced.
      _line(lineNumber: 1, shade: 'SWT001', workOrderNumber: 501),
      _line(lineNumber: 1.1, shade: 'P1001', catalogName: 'WO 501'),
      _line(lineNumber: 1.2, shade: 'P1001', invoiceNumber: 9001),
      // Sample line 2: not invoiced: its own status.
      _line(lineNumber: 2, shade: 'SWT002', workOrderNumber: 502),
    ]);

    expect(
      controller.statusFilterLines.map((line) => line.lineNumber),
      [1, 2],
    );
    expect(controller.displayStatusOf(controller.statusFilterLines.first),
        'Dispatched');
    expect(controller.displayStatusOf(controller.statusFilterLines.last),
        'Order Received By Branch');
  });
}
