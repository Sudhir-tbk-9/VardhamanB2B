import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vardhman_b2b/common/master_detail_layout.dart';
import 'package:vardhman_b2b/constants.dart';
import 'package:vardhman_b2b/labdip/labdip_controller.dart';
import 'package:vardhman_b2b/labdip/labdip_order_details_view.dart';
import 'package:vardhman_b2b/labdip/labdip_orders_view.dart';
import 'package:vardhman_b2b/orders/orders_controller.dart';

class LabdipView extends StatelessWidget {
  const LabdipView({super.key});

  @override
  Widget build(BuildContext context) {
    Get.find<OrdersController>();

    final labdipController = Get.find<LabdipController>();

    return Container(
      color: VardhmanColors.dividerGrey,
      child: Obx(
        () => MasterDetailLayout(
          master: LabdipOrdersView(),
          detail: LabdipOrderDetailsView(),
          detailFlex: 2,
          storageKey: 'labdipOrders',
          // One pane at a time: picking an order opens its details, and back
          // clears the pick so the same order can be opened again.
          showDetail: labdipController.rxSelectedOrderHeaderLine.value != null,
          onBack: () => labdipController.rxSelectedOrderHeaderLine.value = null,
          backLabel: 'Labdip Orders',
        ),
      ),
    );
  }
}
