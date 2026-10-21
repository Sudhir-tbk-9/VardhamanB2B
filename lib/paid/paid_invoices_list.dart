import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:toastification/toastification.dart';
import 'package:vardhman_b2b/api/api.dart';
import 'package:vardhman_b2b/api/invoice_info.dart';
import 'package:vardhman_b2b/common/rupee_text.dart';
import 'package:vardhman_b2b/common/secondary_button.dart';
import 'package:vardhman_b2b/constants.dart';
import 'package:vardhman_b2b/invoices/invoices_controller.dart';

class PaidInvoicesList extends StatelessWidget {
  /// Narrowest the table gets before scrolling sideways (MinWidthScroll):
  /// its columns are shares of the width.
  static const minWidth = 720.0;

  const PaidInvoicesList({
    super.key,
    required this.invoicesDetails,
    this.showHeader = true,
  });

  final bool showHeader;

  final List<InvoiceInfo> invoicesDetails;

  @override
  Widget build(BuildContext context) {
    final InvoicesController invoicesController = Get.find();

    return LayoutBuilder(
      builder: (context, constraints) {
        return DataTable(
          showCheckboxColumn: false,
          headingRowHeight: showHeader ? 40 : 0,
          dataRowMinHeight: 40,
          dataRowMaxHeight: 40,
          columnSpacing: 0,
          horizontalMargin: 0,
          dataTextStyle: TextStyle(
            fontSize: 13,
            color: VardhmanColors.darkGrey,
          ),
          border: TableBorder.all(
            color: VardhmanColors.dividerGrey,
            width: 0.5,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
          ),
          columns: [
            // DataColumn(
            //   label: SizedBox(
            //     width: constraints.maxWidth * .06,
            //     child: const Text(' Download '),
            //   ),
            // ),
            DataColumn(
              label: SizedBox(
                width: constraints.maxWidth * .14,
                child: const Text(
                  'Invoice No.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            DataColumn(
              label: Container(
                padding: const EdgeInsets.only(right: 4),
                width: constraints.maxWidth * .14,
                child: const Text(
                  'Invoice Date',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            DataColumn(
              label: Container(
                padding: const EdgeInsets.only(right: 4),
                width: constraints.maxWidth * .14,
                child: const Text(
                  'Receipt No.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            DataColumn(
              label: Container(
                padding: const EdgeInsets.only(right: 4),
                width: constraints.maxWidth * .14,
                child: const Text(
                  'Receipt Date',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            DataColumn(
              label: Container(
                padding: const EdgeInsets.only(right: 4),
                width: constraints.maxWidth * .14,
                child: const Text(
                  'Sales Order No.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            DataColumn(
              label: Container(
                padding: const EdgeInsets.only(right: 4),
                width: constraints.maxWidth * .14,
                child: const Text(
                  'PO No.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            DataColumn(
              label: Container(
                width: constraints.maxWidth * .14,
                padding: const EdgeInsets.only(right: 4),
                child: const Text(
                  'Amount',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
          rows: invoicesDetails.map(
            (invoiceInfo) {
              return DataRow(
                color: const WidgetStatePropertyAll(Colors.white),
                cells: [
                 /* DataCell(
                    Align(
                      child: SizedBox(
                        width: constraints.maxWidth * .04,
                        child: Align(
                          child: SecondaryButton(
                            text: '',
                            iconData: FontAwesomeIcons.filePdf.data,
                            onPressed: () async {
                              final file = await Api.downloadInvoice(
                                invoiceNumber: invoiceInfo.invoiceNumber,
                                invoiceType: invoiceInfo.docType,
                              );

                              if (file != null) {
                                log('File downloaded!');
                              } else {
                                toastification.show(
                                  autoCloseDuration: Duration(seconds: 3),
                                  primaryColor: VardhmanColors.red,
                                  title: Text('Invoice not found'),
                                );
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ),*/
                  DataCell(
                    SizedBox(
                      width: constraints.maxWidth * .14,
                      child: Text(
                        "${invoiceInfo.invoiceNumber} ${invoiceInfo.docType}",
                        textAlign: TextAlign.center,
                        softWrap: false,
                        style: const TextStyle(
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.only(right: 4),
                      width: constraints.maxWidth * .14,
                      // color: Colors.deepOrange,
                      child: Text(
                        DateFormat('d MMM yyyy').format(invoiceInfo.date),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: VardhmanColors.darkGrey,
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.only(right: 4),
                      width: constraints.maxWidth * .14,
                      // color: Colors.amber,
                      child: Text(
                        invoiceInfo.receiptNumber,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.only(right: 4),
                      width: constraints.maxWidth * .14,
                      // color: Colors.deepOrange,
                      child: Text(
                        DateFormat('d MMM yyyy')
                            .format(invoiceInfo.receiptDate),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: VardhmanColors.darkGrey,
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    Container(
                      width: constraints.maxWidth * .14,
                      padding: const EdgeInsets.only(right: 4),
                      child: Align(
                        alignment: Alignment.center,
                        child: Text(
                          '${invoiceInfo.salesOrderNumber} ${invoiceInfo.salesOrderType}',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    Container(
                      width: constraints.maxWidth * .14,
                      padding: const EdgeInsets.only(right: 4),
                      child: Obx(
                        () => Text(
                          invoicesController.poNumberOf(invoiceInfo),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    Container(
                      width: constraints.maxWidth * .14,
                      padding: const EdgeInsets.only(right: 4),
                      child: Align(
                        alignment: Alignment.center,
                        child: RupeeText(
                          iconSize: 0,
                          fontSize: 13,
                          amount: invoiceInfo.grossAmount,
                          discountAmount: 0,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ).toList(),
        );
      },
    );
  }
}
