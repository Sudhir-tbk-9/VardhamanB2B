import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vardhman_b2b/common/master_detail_layout.dart';
import 'package:vardhman_b2b/constants.dart';
import 'package:vardhman_b2b/sampling/sampling_controller.dart';
import 'package:vardhman_b2b/sampling/sampling_order_details_view.dart';
import 'package:vardhman_b2b/sampling/sampling_orders_view.dart';
import 'package:vardhman_b2b/orders/orders_controller.dart';

class SamplingView extends StatelessWidget {
  const SamplingView({super.key});

  @override
  Widget build(BuildContext context) {
    Get.find<OrdersController>();

    final samplingController = Get.find<SamplingController>();

    return Container(
      color: VardhmanColors.dividerGrey,
      child: Obx(
        () => MasterDetailLayout(
          master: SamplingOrdersView(),
          detail: SamplingOrderDetailsView(),
          detailFlex: 2,
          storageKey: 'samplingOrders',
          // One pane at a time: picking an order opens its details, and back
          // clears the pick so the same order can be opened again.
          showDetail:
              samplingController.rxSelectedOrderHeaderLine.value != null,
          onBack: () =>
              samplingController.rxSelectedOrderHeaderLine.value = null,
          backLabel: 'Sampling Orders',
        ),
      ),
    );
  }
}
