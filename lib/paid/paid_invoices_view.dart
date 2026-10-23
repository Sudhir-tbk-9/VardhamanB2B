import 'package:date_field/date_field.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:vardhman_b2b/common/header_view.dart';
import 'package:vardhman_b2b/common/secondary_button.dart';
import 'package:vardhman_b2b/constants.dart';
import 'package:vardhman_b2b/invoices/invoices_controller.dart';
import 'package:vardhman_b2b/paid/paid_invoices_list.dart';
import 'package:vardhman_b2b/common/min_width_scroll.dart';
import 'package:vardhman_b2b/common/adaptive_row.dart';

class PaidInvoicesView extends StatelessWidget {
  const PaidInvoicesView({super.key});

  @override
  Widget build(BuildContext context) {
    final invoicesController = Get.find<InvoicesController>();

    return Scaffold(
      backgroundColor: VardhmanColors.dividerGrey,
      body: DefaultTextStyle(
        style: const TextStyle(
          color: Colors.white,
        ),
        child: Obx(
          () => Column(
            children: <Widget>[
              HeaderView(
                leading: SecondaryButton(
                  iconData: FontAwesomeIcons.arrowRotateRight.data,
                  text: 'Refresh',
                  onPressed: invoicesController.refreshInvoices,
                ),
                title: const Text(
                  'Paid Invoices',
                  textAlign: TextAlign.center,
                ),
                trailing: Text(
                  '${invoicesController.paidInvoices.length} invoice${invoicesController.paidInvoices.length > 1 ? 's' : ''} found',
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.symmetric(
                      horizontal: BorderSide(
                        color: VardhmanColors.dividerGrey,
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: invoicesController.paidInvoices.isEmpty
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'No Paid Invoices',
                              style: TextStyle(color: VardhmanColors.darkGrey),
                            ),
                            SizedBox(
                              height: 16,
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            Expanded(
                              child: MinWidthScroll(
                                minWidth: PaidInvoicesList.minWidth,
                                child: SingleChildScrollView(
                                  child: PaidInvoicesList(
                                    invoicesDetails:
                                        invoicesController.paidInvoices,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              Container(
                padding: const EdgeInsets.only(
                    top: 16, right: 8, left: 8, bottom: 8),
                decoration: const BoxDecoration(
                  color: Colors.white,
                ),
                // Filters wrap onto more lines on a narrow pane instead of
                // squeezing each field.
                child: AdaptiveRow(
                  narrowLayout: NarrowLayout.wrap,
                  breakpoint: 560,
                  children: <Widget>[
                    Flexible(
                      child: TextField(
                        controller: invoicesController
                            .invoiceNumberTextEditingController,
                        onChanged: (String invoiceNumber) {
                          invoicesController.rxInvoiceNumberInput.value =
                              invoiceNumber;
                        },
                        keyboardType: TextInputType.text,
                        decoration: InputDecoration(
                          isDense: true,
                          label: Text('Invoice No.'),
                          labelStyle: TextStyle(
                            color: VardhmanColors.darkGrey,
                            fontSize: 14,
                          ),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(
                      width: 8,
                    ),
                    Flexible(
                      child: TextField(
                        controller:
                            invoicesController.poNumberTextEditingController,
                        onChanged: (String poNumber) {
                          invoicesController.rxPoNumberInput.value = poNumber;
                        },
                        keyboardType: TextInputType.text,
                        decoration: InputDecoration(
                          isDense: true,
                          label: Text('PO No.'),
                          labelStyle: TextStyle(
                            color: VardhmanColors.darkGrey,
                            fontSize: 14,
                          ),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(
                      width: 8,
                    ),
                    Flexible(
                      child: DateTimeField(
                        mode: DateTimeFieldPickerMode.date,
                        decoration: InputDecoration(
                          isDense: true,
                          labelText: 'Invoices From',
                          border: const OutlineInputBorder(),
                          suffixIcon: Container(),
                          prefixText: DateFormat('d MMM yyyy').format(
                            invoicesController.rxInvoiceFromDate.value,
                          ),
                          prefixStyle: TextStyle(
                            color: invoicesController.rxInvoiceFromDate.value
                                    .isAtSameMomentAs(oldestDateTime)
                                ? Colors.white
                                : VardhmanColors.darkGrey,
                          ),
                        ),
                        dateFormat: DateFormat('d MMM yyyy'),
                        firstDate:
                            invoicesController.rxEarliestInvoiceDate.value,
                        lastDate: invoicesController.rxInvoiceToDate.value,
                        value: invoicesController.rxInvoiceFromDate.value,
                        onChanged: (DateTime? date) {
                          if (date != null) {
                            invoicesController.rxInvoiceFromDate.value = date;
                          }
                        },
                      ),
                    ),
                    const SizedBox(
                      width: 8,
                    ),
                    Flexible(
                      child: DateTimeField(
                        mode: DateTimeFieldPickerMode.date,
                        decoration: InputDecoration(
                          isDense: true,
                          labelText: 'Invoices Till',
                          border: const OutlineInputBorder(),
                          suffixIcon: Container(),
                          prefixText: DateFormat('d MMM yyyy').format(
                            invoicesController.rxInvoiceToDate.value,
                          ),
                          prefixStyle: TextStyle(
                            color: VardhmanColors.darkGrey,
                          ),
                        ),
                        dateFormat: DateFormat('d MMM yyyy'),
                        firstDate: invoicesController.rxInvoiceFromDate.value,
                        lastDate: DateTime.now(),
                        value: invoicesController.rxInvoiceToDate.value,
                        initialPickerDateTime:
                            invoicesController.rxInvoiceToDate.value,
                        onChanged: (DateTime? date) {
                          if (date != null) {
                            invoicesController.rxInvoiceToDate.value = date;
                          }
                        },
                      ),
                    ),
                    const SizedBox(
                      width: 8,
                    ),
                    SecondaryButton(
                      text: '',
                      onPressed: invoicesController.hasFilters
                          ? null
                          : () async {
                              invoicesController.clearOpenFilters();
                            },
                      iconData: FontAwesomeIcons.arrowRotateLeft.data,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
