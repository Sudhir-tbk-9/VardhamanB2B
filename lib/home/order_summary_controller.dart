import 'package:get/get.dart';
import 'package:vardhman_b2b/api/api.dart';
import 'package:vardhman_b2b/api/order_summary.dart';
import 'package:vardhman_b2b/user/user_controller.dart';

class OrderSummaryController extends GetxController {
  final UserController userController = Get.find(tag: 'userController');
  final rxOrderCustomersList = RxList<String>();
  final soldToNumber = RxString;
  final rxOrderCustomersNameMap = RxMap<String, String>();

  final Rxn<DateTime> rxOrderSummaryFromDate =
      Rxn<DateTime>(DateTime.now().subtract(Duration(days: 7)));
  final Rxn<DateTime> rxOrderSummaryThroughDate = Rxn<DateTime>(DateTime.now());

  final rxOrderSummaryLines = <OrderSummary>[].obs;

  OrderSummaryController() {
    rxOrderSummaryFromDate.listenAndPump(orderSummaryDateListener);
    rxOrderSummaryThroughDate.listenAndPump(orderSummaryDateListener);
  }

  Future<void> fetchSalsemanCode() async {
    rxOrderCustomersList.value = await Api.fetchSalsemanCode(
      soldToNumber: userController.rxUserDetail.value.soldToNumber,
    );
  }

  Future<void> fetchCustomersName() async {
    rxOrderCustomersNameMap.value = await Api.fetchCustomersName(
      salsemanCustomerList: rxOrderCustomersList,
    );
  }

  final _rxLoadCount = 0.obs;

  /// True while the summary is being fetched from JDE.
  bool get isLoading => _rxLoadCount.value > 0;

  Future<void> orderSummaryDateListener(DateTime? newDate) async {
    _rxLoadCount.value++;
    try {
      await fetchSalsemanCode();
      await fetchCustomersName();
      rxOrderSummaryLines.value = await Api.fetchOrderCustomersByDate(
          salsemanCustomerList: rxOrderCustomersList,
          orderCustomersNameMap: rxOrderCustomersNameMap,
          fromDate: rxOrderSummaryFromDate.value!,
          throughDate: rxOrderSummaryThroughDate.value!);
    } finally {
      _rxLoadCount.value--;
    }
  }
}
