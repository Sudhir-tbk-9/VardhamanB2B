import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:vardhman_b2b/api/invoice_info.dart';
import 'package:vardhman_b2b/invoices/invoices_controller.dart';
import 'package:vardhman_b2b/open/open_invoices_list.dart';

/// Only the selection the list uses.
class _FakeInvoicesController extends GetxController
    implements InvoicesController {
  @override
  final rxSelectedInvoiceInfos = <InvoiceInfo>[].obs;

  @override
  void addInvoiceToSelected(InvoiceInfo invoiceInfo) {
    if (!rxSelectedInvoiceInfos.contains(invoiceInfo)) {
      rxSelectedInvoiceInfos.add(invoiceInfo);
    }
  }

  @override
  void removeInvoiceFromSelected(InvoiceInfo invoiceInfo) =>
      rxSelectedInvoiceInfos.remove(invoiceInfo);

  @override
  final rxPoNumbers = <String, String>{}.obs;

  // Reads rxPoNumbers like the real one: the PO cell is an Obx.
  @override
  String poNumberOf(InvoiceInfo invoiceInfo) =>
      rxPoNumbers['${invoiceInfo.invoiceNumber}'] ?? '';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

InvoiceInfo _invoice(int invoiceNumber) => InvoiceInfo(
      openAmount: 1000,
      grossAmount: 1000,
      discountAmount: 0,
      taxableAmount: 847,
      tax: 153,
      customerNumber: '105911',
      company: '10901',
      docType: 'RI',
      invoiceNumber: invoiceNumber,
      salesOrderNumber: 1,
      salesOrderType: 'SW',
      date: DateTime(2026, 11, 1),
      discountDueDate: DateTime(2026, 12, 1),
      isOpen: true,
      status: InvoiceStatus.notDue,
      receiptNumber: '',
      receiptDate: DateTime(2026, 11, 1),
    );

void main() {
  tearDown(Get.reset);

  Future<_FakeInvoicesController> pumpList(
    WidgetTester tester, {
    bool canSelect = true,
  }) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final controller = Get.put<InvoicesController>(_FakeInvoicesController())
        as _FakeInvoicesController;

    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 900,
            child: Obx(
              () => OpenInvoicesList(
                // Read here so the list rebuilds on a pick, as in the app.
                key: ValueKey(controller.rxSelectedInvoiceInfos.length),
                invoicesDetails: [_invoice(101), _invoice(102)],
                canSelect: canSelect,
              ),
            ),
          ),
        ),
      ),
    );

    return controller;
  }

  bool? ticked(WidgetTester tester, int row) =>
      tester.widgetList<Checkbox>(find.byType(Checkbox)).elementAt(row).value;

  testWidgets('every row has a checkbox; ticking it selects the invoice',
      (tester) async {
    final controller = await pumpList(tester);

    expect(find.byType(Checkbox), findsNWidgets(2));
    expect(ticked(tester, 0), isFalse);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();

    expect(
        controller.rxSelectedInvoiceInfos.map((i) => i.invoiceNumber), [101]);
    expect(ticked(tester, 0), isTrue);
    expect(ticked(tester, 1), isFalse);

    // Unticked again.
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();

    expect(controller.rxSelectedInvoiceInfos, isEmpty);
  });

  testWidgets('a tap on the row still selects it, and ticks its checkbox',
      (tester) async {
    final controller = await pumpList(tester);

    await tester.tap(find.text('102 RI'));
    await tester.pump();

    expect(
        controller.rxSelectedInvoiceInfos.map((i) => i.invoiceNumber), [102]);
    expect(ticked(tester, 1), isTrue);
  });

  testWidgets('no checkboxes where invoices cannot be picked', (tester) async {
    await pumpList(tester, canSelect: false);

    expect(find.byType(Checkbox), findsNothing);
  });
}
