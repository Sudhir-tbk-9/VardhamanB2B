import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vardhman_b2b/common/master_detail_layout.dart';
import 'package:vardhman_b2b/constants.dart';
import 'package:vardhman_b2b/dtm/dtm_controller.dart';
import 'package:vardhman_b2b/dtm/dtm_order_details_view.dart';
import 'package:vardhman_b2b/dtm/dtm_orders_view.dart';
import 'package:vardhman_b2b/orders/orders_controller.dart';

class DtmView extends StatelessWidget {
  const DtmView({super.key});

  @override
  Widget build(BuildContext context) {
    Get.find<OrdersController>();

    final dtmController = Get.find<DtmController>();

    return Container(
      color: VardhmanColors.dividerGrey,
      child: Obx(
        () => MasterDetailLayout(
          master: DtmOrdersView(),
          detail: DtmOrderDetailsView(),
          detailFlex: 3,
          // One pane at a time: picking an order opens its details, and back
          // clears the pick so the same order can be opened again.
          showDetail: dtmController.rxSelectedOrderHeaderLine.value != null,
          onBack: () => dtmController.rxSelectedOrderHeaderLine.value = null,
          backLabel: 'DTM Orders',
        ),
      ),
    );
  }
}
