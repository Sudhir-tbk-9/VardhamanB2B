import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vardhman_b2b/app/app_router.dart';
import 'package:vardhman_b2b/bulk/bulk_entry_controller.dart';
import 'package:vardhman_b2b/bulk/create_bulk_order_view.dart';
import 'package:vardhman_b2b/common/adaptive_dialog.dart';
import 'package:vardhman_b2b/dtm/create_dtm_order_view.dart';
import 'package:vardhman_b2b/dtm/dtm_entry_controller.dart';
import 'package:vardhman_b2b/labdip/create_labdip_order_view.dart';
import 'package:vardhman_b2b/labdip/labdip_entry_controller.dart';
import 'package:vardhman_b2b/segment/segment_controller.dart';

/// Opens [draftOrder] in its order entry dialog, on its own tab, so it can
/// be submitted or deleted: what clicking a draft row in that tab's list
/// does. Called from the segment dialog's lock warning, which is closed
/// first.
///
/// Labdip and Sampling drafts are both saved as LD and listed on both
/// tabs; they open on the Labdip tab.
Future<void> openDraftOrder(DraftOrder draftOrder) async {
  logSegment('Opening $draftOrder on the ${draftOrder.tabName} tab to '
      'submit or delete it');

  // The segment dialog.
  Get.back();

  final tabPath = draftOrder.tabPath;

  if (tabPath != null &&
      appRouter.routerDelegate.currentConfiguration.uri.path != tabPath) {
    appRouter.go(tabPath);

    // A dialog pushed before the new tab's page is built would be dropped
    // with the old page.
    await WidgetsBinding.instance.endOfFrame;
  }

  final orderNumber = draftOrder.orderNumber;

  final Widget view;

  switch (draftOrder.orderType) {
    case 'BK':
      if (Get.isRegistered<BulkEntryController>()) {
        Get.delete<BulkEntryController>();
      }

      Get.put(BulkEntryController(orderNumber: orderNumber));

      view = const CreateBulkOrderView();

    case 'DT':
      if (Get.isRegistered<DtmEntryController>()) {
        Get.delete<DtmEntryController>();
      }

      Get.put(DtmEntryController(orderNumber: orderNumber));

      view = const CreateDtmOrderView();

    case 'LD':
      if (Get.isRegistered<LabdipEntryController>()) {
        Get.delete<LabdipEntryController>();
      }

      Get.put(LabdipEntryController(orderNumber: orderNumber));

      view = const CreateLabdipOrderView();

    default:
      logSegment('No order screen for draft type ${draftOrder.orderType}');

      return;
  }

  Get.dialog(AdaptiveDialog(clipBehavior: Clip.hardEdge, child: view));
}
