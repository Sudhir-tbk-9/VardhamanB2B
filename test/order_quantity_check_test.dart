import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toastification/toastification.dart';
import 'package:vardhman_b2b/common/order_quantity_log.dart';
import 'package:vardhman_b2b/drift/database.dart';

DraftTableData _line(int lineNumber, int quantity) => DraftTableData(
      id: lineNumber,
      soldTo: '1001',
      orderType: 'BK',
      orderNumber: 1,
      merchandiser: 'M',
      lineNumber: lineNumber,
      shade: 'S$lineNumber',
      buyer: 'B',
      buyerCode: '',
      firstLightSource: 'D65',
      secondLightSource: '',
      substrate: '',
      tex: '',
      ticket: '',
      brand: '',
      article: 'A100',
      requestType: '',
      colorName: '',
      lab: ',,',
      remark: '',
      billingType: '',
      uom: 'CN',
      endUse: '',
      quantity: quantity,
      colorRemark: '',
      lastUpdated: DateTime(2026),
      qtxFileName: '',
      poNumber: 'PO1',
      poFileName: '',
    );

void main() {
  Future<void> pumpApp(WidgetTester tester) => tester.pumpWidget(
        const ToastificationWrapper(
          child: MaterialApp(home: Scaffold(body: SizedBox())),
        ),
      );

  testWidgets('every quantity at least 1: the order goes ahead',
      (tester) async {
    await pumpApp(tester);

    expect(
      checkOrderLineQuantities(
        orderType: 'Bulk',
        lines: [_line(1, 5), _line(2, 1)],
      ),
      isTrue,
    );

    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Order not placed: quantity 0'), findsNothing);
  });

  testWidgets('a line with quantity 0 stops the order and is named',
      (tester) async {
    await pumpApp(tester);

    expect(
      checkOrderLineQuantities(
        orderType: 'Bulk',
        lines: [_line(1, 5), _line(2, 0), _line(3, 0)],
      ),
      isFalse,
    );

    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Order not placed: quantity 0'), findsOneWidget);
    expect(
      find.textContaining('Line 2 (A100 S2), Line 3 (A100 S3) have a '
          'quantity of 0'),
      findsOneWidget,
    );

    toastification.dismissAll(delayForAnimation: false);
    await tester.pumpAndSettle();
  });
}
