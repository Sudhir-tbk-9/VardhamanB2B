import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:vardhman_b2b/common/paged_orders_table.dart';

void main() {
  // As many orders as one customer's GetOrderStatus response returned.
  final rxOrders = List.generate(1500, (index) => index).obs;

  final rxSelected = RxnInt();

  final builtRows = <int>{};

  late PaginatorController paginatorController;

  Future<void> pumpTable(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PagedOrdersTable(
            minWidth: 600,
            controller: paginatorController,
            columns: const [DataColumn2(label: Text('Order No.'))],
            rowCount: () => rxOrders.length,
            rowBuilder: (int rowIndex) {
              builtRows.add(rowIndex);

              final order = rxOrders[rowIndex];

              return DataRow(
                selected: rxSelected.value == order,
                cells: [DataCell(Text('order $order'))],
              );
            },
            refreshOn: [rxOrders, rxSelected],
            firstPageOn: [rxOrders],
          ),
        ),
      ),
    );

    // PaginatedDataTable2 applies source changes on a zero-length timer.
    await tester.pumpAndSettle();
  }

  setUp(() {
    paginatorController = PaginatorController();
    rxOrders.assignAll(List.generate(1500, (index) => index));
    rxSelected.value = null;
    builtRows.clear();
  });

  testWidgets('builds only the first page of 1500 orders', (tester) async {
    await pumpTable(tester);

    expect(builtRows, Set.of(List.generate(50, (index) => index)));
    expect(find.text('order 0'), findsOneWidget);
    expect(find.text('order 50'), findsNothing);
  });

  testWidgets('selecting an order redraws only the page on screen',
      (tester) async {
    await pumpTable(tester);

    builtRows.clear();

    rxSelected.value = 3;
    await tester.pumpAndSettle();

    expect(builtRows.length, 50);
    expect(builtRows, contains(3));
  });

  testWidgets('new filtered orders go back to the first page', (tester) async {
    await pumpTable(tester);

    paginatorController.goToNextPage();
    await tester.pumpAndSettle();

    expect(find.text('order 50'), findsOneWidget);

    rxOrders.assignAll(List.generate(20, (index) => 1000 + index));
    await tester.pumpAndSettle();

    expect(find.text('order 1000'), findsOneWidget);
    expect(find.text('order 1019'), findsOneWidget);
  });
}
