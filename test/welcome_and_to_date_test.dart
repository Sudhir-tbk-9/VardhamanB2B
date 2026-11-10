import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:vardhman_b2b/api/order_header_line.dart';
import 'package:vardhman_b2b/constants.dart';
import 'package:vardhman_b2b/home/home_scaffold.dart';
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
  final Rx<DateTime> rxOrderToDate;

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

  _OrderList(DateTime toDate) : rxOrderToDate = toDate.obs;

  @override
  bool isListOrder(OrderHeaderLine orderHeaderLine) => true;

  @override
  bool get hasDefaultValues => true;

  @override
  Future<void> setDefaultValues() async {}
}

OrderHeaderLine _order(int orderNumber, DateTime orderDate) => OrderHeaderLine(
      orderNumber: orderNumber,
      orderType: 'SW',
      orderCompany: '00001',
      orderDate: orderDate,
      orderReference: '',
      holdCode: '',
      shipTo: 105911,
      quantityOrdered: 1,
      quantityShipped: 0,
      quantityCancelled: 0,
      orderStatus: 'In Progress',
      orderAmount: 0,
      quantityBackOrdered: 0,
      canIndent: false,
      isDTM: false,
      poNumber: '',
      merchandiser: '',
    );

void main() {
  group('welcomeText', () {
    test('login ID with the customer number in brackets', () {
      expect(
        welcomeText(
            loginId: 'RISHIK', userName: '105911', soldToNumber: '105911'),
        'Welcome! RISHIK (105911)',
      );
    });

    test('user name when the login ID is the customer number', () {
      expect(
        welcomeText(
            loginId: '105911', userName: 'Rishik', soldToNumber: '105911'),
        'Welcome! Rishik (105911)',
      );
    });

    test('just the number when there is no other name', () {
      expect(
        welcomeText(loginId: '105911', userName: '', soldToNumber: '105911'),
        'Welcome! 105911',
      );
    });
  });

  group('To date', () {
    final today = DateTime.now();

    final todaysOrder = _order(2, DateTime(today.year, today.month, today.day));

    final olderOrder =
        _order(1, DateTime(today.year, today.month, today.day - 5));

    test('left on the day the list opened, it moves on to today', () {
      // Opened two days ago and never changed.
      final list = _OrderList(today.subtract(const Duration(days: 2)))
        ..initOrderListFilters();

      list.assignListOrders([olderOrder]);

      expect(areDatesEqual(list.rxOrderToDate.value, today), isTrue);

      // An order placed today, after a reload, is listed.
      list.assignListOrders([todaysOrder, olderOrder]);

      expect(list.rxFilteredOrders, [todaysOrder, olderOrder]);
    });

    test('a To date the user picked is kept', () {
      final list = _OrderList(today)..initOrderListFilters();

      list.assignListOrders([olderOrder]);

      final picked = DateTime(today.year, today.month, today.day - 3);

      list.rxOrderToDate.value = picked;

      list.assignListOrders([todaysOrder, olderOrder]);

      expect(list.rxOrderToDate.value, picked);
      expect(list.rxFilteredOrders, [olderOrder]);
    });
  });
}
