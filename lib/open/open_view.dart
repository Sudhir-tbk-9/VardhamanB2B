import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vardhman_b2b/common/vardhman_loader.dart';
import 'package:vardhman_b2b/constants.dart';
import 'package:vardhman_b2b/invoices/invoices_controller.dart';
import 'package:vardhman_b2b/open/invoice_review_view.dart';
import 'package:vardhman_b2b/open/open_invoices_view.dart';

class OpenView extends StatelessWidget {
  const OpenView({super.key});

  @override
  Widget build(BuildContext context) {
    final invoicesController = Get.find<InvoicesController>();

    return Scaffold(
      body: Obx(
        () => LoadingOverlay(
          isLoading: invoicesController.isLoading,
          message: 'Fetching invoices from JDE',
          child: Row(
            children: <Widget>[
              Expanded(child: OpenInvoicesView()),
              VerticalDivider(
                thickness: 8,
                color: VardhmanColors.darkGrey,
                width: 8,
              ),
              Expanded(child: InvoiceReviewView()),
            ],
          ),
        ),
      ),
    );
  }
}
