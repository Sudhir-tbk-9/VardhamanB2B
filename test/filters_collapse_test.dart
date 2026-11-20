import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:vardhman_b2b/api/order_header_line.dart';
import 'package:vardhman_b2b/common/date_range_menu.dart';
import 'package:vardhman_b2b/common/order_filters_panel.dart';
import 'package:vardhman_b2b/constants.dart';
import 'package:vardhman_b2b/orders/order_list_filters.dart';
import 'package:vardhman_b2b/orders/orders_controller.dart';

/// A list with the shared filters and nothing else.
class _OrderList extends GetxController with OrderListFilters {
  @override
  OrdersController get ordersController => throw UnimplementedError();

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

  @override
  final rxLineSearchMatches = Rxn<Set<int>>();

  @override
  final rxSelectedOrderHeaderLine = Rxn<OrderHeaderLine>();

  @override
  bool isListOrder(OrderHeaderLine orderHeaderLine) => true;

  @override
  bool get hasDefaultValues => rxOrderNumberInput.value.isEmpty;

  int resets = 0;

  @override
  Future<void> setDefaultValues() async {
    resets++;

    rxOrderNumberInput.value = '';
  }
}

void main() {
  Future<_OrderList> pumpPanel(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final list = _OrderList()..rxFiltersExpanded.value = true;

    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: OrderFiltersPanel(
            filters: list,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (value) =>
                        list.rxOrderNumberInput.value = value,
                    onSubmitted: (_) => list.collapseFilters(),
                  ),
                ),
                DateRangeMenu(filters: list),
              ],
            ),
          ),
        ),
      ),
    );

    return list;
  }

  testWidgets('Apply closes the panel', (tester) async {
    final list = await pumpPanel(tester);

    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(list.rxFiltersExpanded.value, isFalse);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('Enter in a filter field closes the panel', (tester) async {
    final list = await pumpPanel(tester);

    await tester.enterText(find.byType(TextField), '1024');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(list.rxOrderNumberInput.value, '1024');
    expect(list.rxFiltersExpanded.value, isFalse);
  });

  testWidgets('Reset clears the filters and closes the panel', (tester) async {
    final list = await pumpPanel(tester);

    await tester.enterText(find.byType(TextField), '1024');
    await tester.pump();

    await tester.tap(find.byTooltip('Reset filters'));
    await tester.pumpAndSettle();

    expect(list.resets, 1);
    expect(list.rxOrderNumberInput.value, '');
    expect(list.rxFiltersExpanded.value, isFalse);
  });

  testWidgets('a quick date range closes the panel', (tester) async {
    final list = await pumpPanel(tester);

    await tester.tap(find.byTooltip('Quick date range'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(OrderDateRange.lastSevenDays.label));
    await tester.pumpAndSettle();

    expect(list.rxDateRange.value, OrderDateRange.lastSevenDays);
    expect(list.rxFiltersExpanded.value, isFalse);
  });

  testWidgets('typing alone keeps the panel open', (tester) async {
    final list = await pumpPanel(tester);

    await tester.enterText(find.byType(TextField), '10');
    await tester.pumpAndSettle();

    expect(list.rxFiltersExpanded.value, isTrue);
  });
}
