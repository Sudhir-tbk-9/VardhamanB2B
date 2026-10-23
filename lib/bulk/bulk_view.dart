import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vardhman_b2b/common/master_detail_layout.dart';
import 'package:vardhman_b2b/constants.dart';
import 'package:vardhman_b2b/bulk/bulk_controller.dart';
import 'package:vardhman_b2b/bulk/bulk_order_details_view.dart';
import 'package:vardhman_b2b/bulk/bulk_orders_view.dart';
import 'package:vardhman_b2b/orders/orders_controller.dart';

class BulkView extends StatelessWidget {
  const BulkView({super.key});

  @override
  Widget build(BuildContext context) {
    Get.find<OrdersController>();

    final bulkController = Get.find<BulkController>();

    return Container(
      color: VardhmanColors.dividerGrey,
      child: Obx(
        () => MasterDetailLayout(
          master: BulkOrdersView(),
          detail: BulkOrderDetailsView(),
          detailFlex: 3,
          // One pane at a time: picking an order opens its details, and back
          // clears the pick so the same order can be opened again.
          showDetail: bulkController.rxSelectedOrderHeaderLine.value != null,
          onBack: () => bulkController.rxSelectedOrderHeaderLine.value = null,
          backLabel: 'Bulk Orders',
        ),
      ),
    );
  }
}
