import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vardhman_b2b/common/vardhman_loader.dart';
import 'package:vardhman_b2b/invoices/invoices_controller.dart';
import 'package:vardhman_b2b/paid/paid_invoices_view.dart';

class PaidView extends StatelessWidget {
  const PaidView({super.key});

  @override
  Widget build(BuildContext context) {
    final invoicesController = Get.find<InvoicesController>();

    return Obx(
      () => LoadingOverlay(
        isLoading: invoicesController.isLoading,
        message: 'Fetching invoices from JDE',
        child: const PaidInvoicesView(),
      ),
    );
  }
}
