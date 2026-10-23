import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vardhman_b2b/common/master_detail_layout.dart';
import 'package:vardhman_b2b/common/primary_button.dart';
import 'package:vardhman_b2b/common/vardhman_loader.dart';
import 'package:vardhman_b2b/invoices/invoices_controller.dart';
import 'package:vardhman_b2b/open/invoice_review_view.dart';
import 'package:vardhman_b2b/open/open_invoices_view.dart';

class OpenView extends StatefulWidget {
  const OpenView({super.key});

  @override
  State<OpenView> createState() => _OpenViewState();
}

class _OpenViewState extends State<OpenView> {
  /// Narrow window only: the review pane is shown instead of the list.
  /// Invoices are multi-select, so the review opens from a button rather than
  /// by picking a row.
  bool _showReview = false;

  @override
  Widget build(BuildContext context) {
    final invoicesController = Get.find<InvoicesController>();

    return Scaffold(
      body: Obx(
        () {
          final selectedCount =
              invoicesController.rxSelectedInvoiceInfos.length;

          return LoadingOverlay(
            isLoading: invoicesController.isLoading,
            message: 'Fetching invoices from JDE',
            child: MasterDetailLayout(
              master: OpenInvoicesView(),
              detail: InvoiceReviewView(),
              showDetail: _showReview,
              onBack: () => setState(() => _showReview = false),
              backLabel: 'Open Invoices',
              masterBar: Align(
                alignment: Alignment.centerRight,
                child: PrimaryButton(
                  text: selectedCount > 0
                      ? 'Review & Pay ($selectedCount)'
                      : invoicesController.rxLastPayment.value != null
                          ? 'Last Payment'
                          : 'Review',
                  onPressed: () async => setState(() => _showReview = true),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
