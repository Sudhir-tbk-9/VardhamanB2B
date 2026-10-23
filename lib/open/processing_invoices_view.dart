import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:vardhman_b2b/invoices/invoices_controller.dart';
import 'package:vardhman_b2b/open/open_invoices_list.dart';
import 'package:vardhman_b2b/common/min_width_scroll.dart';

class ProcessingInvoicesView extends StatelessWidget {
  const ProcessingInvoicesView({super.key});

  @override
  Widget build(BuildContext context) {
    final invoicesController = Get.find<InvoicesController>();

    // Header and rows scroll sideways together on a narrow window.
    return MinWidthScroll(
      minWidth: OpenInvoicesList.minWidth,
      child: Column(
        children: [
          const OpenInvoicesList(
            invoicesDetails: [],
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  OpenInvoicesList(
                    canSelect: false,
                    showHeader: false,
                    invoicesDetails: invoicesController.processingInvoices,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
