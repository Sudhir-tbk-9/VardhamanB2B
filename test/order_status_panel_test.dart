import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vardhman_b2b/api/order_header_line.dart';
import 'package:vardhman_b2b/common/order_status_panel.dart';

void main() {
  final header = OrderHeaderLine(
    orderNumber: 26036776,
    orderType: 'SW',
    orderCompany: '00001',
    orderDate: DateTime(2026, 10, 31),
    orderReference: 'B2BS4006',
    holdCode: '',
    shipTo: 105911,
    quantityOrdered: 18,
    quantityShipped: 5,
    quantityCancelled: 2,
    orderStatus: 'Partially Dispatched',
    orderAmount: 1234.5,
    quantityBackOrdered: 0,
    canIndent: false,
    isDTM: false,
    poNumber: 'PO-1',
    merchandiser: 'TEST',
  );

  const counts = {'In Progress': 10, 'Dispatched': 5, 'Order Received By Plant': 3};

  /// The panel with its filter held here, as the controller holds it.
  Future<List<String?>> pumpPanel(WidgetTester tester, {double width = 1200}) async {
    tester.view.physicalSize = Size(width, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final picks = <String?>[];

    String? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => OrderStatusPanel(
              orderHeaderLine: header,
              lineStatusCounts: counts,
              selectedLineStatus: selected,
              onLineStatusSelected: (status) {
                picks.add(status);
                setState(() => selected = status);
              },
            ),
          ),
        ),
      ),
    );

    return picks;
  }

  bool isSelected(WidgetTester tester, String label) => tester
      .widget<ChoiceChip>(
        find.ancestor(of: find.text(label), matching: find.byType(ChoiceChip)),
      )
      .selected;

  testWidgets('no order status or quantity chips; All plus one per status',
      (tester) async {
    await pumpPanel(tester);

    expect(find.textContaining('Status:'), findsNothing);
    expect(find.textContaining('Ordered'), findsNothing);
    expect(find.textContaining('Shipped'), findsNothing);
    expect(find.textContaining('Cancelled'), findsNothing);

    expect(find.byType(ChoiceChip), findsNWidgets(4));
    expect(find.text('All 18'), findsOneWidget);
    expect(find.text('In Progress 10'), findsOneWidget);
    expect(find.text('Dispatched 5'), findsOneWidget);
    expect(find.text('Order Received By Plant 3'), findsOneWidget);

    // All by default.
    expect(isSelected(tester, 'All 18'), isTrue);
    expect(isSelected(tester, 'Dispatched 5'), isFalse);
  });

  testWidgets('one chip at a time; All shows every line again', (tester) async {
    final picks = await pumpPanel(tester);

    await tester.tap(find.text('Dispatched 5'));
    await tester.pump();

    expect(picks, ['Dispatched']);
    expect(isSelected(tester, 'Dispatched 5'), isTrue);
    expect(isSelected(tester, 'All 18'), isFalse);

    await tester.tap(find.text('In Progress 10'));
    await tester.pump();

    expect(isSelected(tester, 'In Progress 10'), isTrue);
    expect(isSelected(tester, 'Dispatched 5'), isFalse);

    await tester.tap(find.text('All 18'));
    await tester.pump();

    expect(picks, ['Dispatched', 'In Progress', null]);
    expect(isSelected(tester, 'All 18'), isTrue);
  });

  testWidgets('chips work from the keyboard and show the click cursor',
      (tester) async {
    final picks = await pumpPanel(tester);

    // Tab to All, then on to In Progress, and pick it with Enter.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(picks, ['In Progress']);

    final gesture =
        await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      pointer: 1,
    );
    addTearDown(gesture.removePointer);
    await gesture.addPointer(location: Offset.zero);
    await gesture.moveTo(tester.getCenter(find.text('All 18')));
    await tester.pump();

    expect(
      RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
      SystemMouseCursors.click,
    );
  });

  testWidgets('chips wrap on a narrow screen', (tester) async {
    await pumpPanel(tester, width: 360);

    expect(tester.takeException(), isNull);

    final first = tester.getTopLeft(find.text('All 18')).dy;
    final last = tester.getTopLeft(find.text('Order Received By Plant 3')).dy;

    expect(last, greaterThan(first), reason: 'later chips on a new row');
  });
}
