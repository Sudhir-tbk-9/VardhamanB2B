import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:toastification/toastification.dart';
import 'package:vardhman_b2b/api/api.dart';
import 'package:vardhman_b2b/api/invoice_info.dart';
import 'package:vardhman_b2b/app/theme_variants.dart';
import 'package:vardhman_b2b/common/app_url.dart';
import 'package:vardhman_b2b/common/payment_log.dart';
import 'package:vardhman_b2b/common/payment_return.dart';
import 'package:vardhman_b2b/home/home_controller.dart';
import 'package:vardhman_b2b/common/primary_button.dart';
import 'package:vardhman_b2b/common/rupee_text.dart';
import 'package:vardhman_b2b/constants.dart';
import 'package:vardhman_b2b/invoices/invoices_controller.dart';
import 'package:vardhman_b2b/user/user_controller.dart';
import 'package:universal_html/html.dart' as html;
import 'package:vardhman_b2b/common/adaptive_dialog.dart';

class InvoiceReviewDialog extends StatelessWidget {
  const InvoiceReviewDialog({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final invoicesController = Get.find<InvoicesController>();

    final UserController userController = Get.find<UserController>(
      tag: 'userController',
    );

    return AdaptiveDialog(
      child: Obx(
        () => Container(
          constraints: const BoxConstraints(
            maxWidth: 920,
          ),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text('You are about to initiate a payment of '),
              const SizedBox(
                height: 8,
              ),
              RupeeText(
                amount: invoicesController.selectedDiscountedAmount,
              ),
              const SizedBox(
                height: 8,
              ),
              Text(
                'for ${invoicesController.rxSelectedInvoiceInfos.length} '
                'invoice${invoicesController.rxSelectedInvoiceInfos.length > 1 ? 's' : ''}:',
              ),
              const SizedBox(
                height: 4,
              ),
              _PaymentSummaryTable(
                invoiceInfos: invoicesController.rxSelectedInvoiceInfos,
                poNumberOf: invoicesController.poNumberOf,
              ),
              const SizedBox(
                height: 8,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: PrimaryButton(
                  iconData: Icons.done_outlined,
                  text: 'Proceed',
                  onPressed: () async {
                    toastification.show(
                      autoCloseDuration: Duration(seconds: 3),
                      primaryColor: VardhmanColors.green,
                      title: Text(
                        'Redirecting you to the payment gateway.',
                      ),
                    );
                    Future.delayed(Duration(seconds: 3));
                    final batchNumber = await Api.fetchPaymentBatchNumber();

                    if (batchNumber != null) {
                      final receiptNumber = 'P$batchNumber';

                      final paymentEntryCreated =
                          await Api.createInvoicePaymentEntry(
                        paymentDetails: invoicesController
                            .rxSelectedInvoiceInfos
                            .map(
                              (invoiceInfo) => {
                                "Batch_Number": batchNumber,
                                "Company": invoiceInfo.company,
                                "Source_Mobile_Portal": "P",
                                "Customer_Number": invoiceInfo.customerNumber,
                                "Invoice_Number": invoiceInfo.invoiceNumber,
                                "Invoice_Type": invoiceInfo.docType,
                                "Invoice_Company": invoiceInfo.company,
                                "Receipt_Number": receiptNumber,
                                "Payment_Amount": invoiceInfo.status ==
                                        InvoiceStatus.discounted
                                    ? invoiceInfo.discountAmount
                                        .toStringAsFixed(2)
                                    : invoiceInfo.openAmount.toStringAsFixed(2),
                                "Payment_Reference": "",
                                "Payment_Remark": "",
                                "Bank_Account": "",
                                "Payment_Date": DateFormat('MM/dd/yyyy')
                                    .format(DateTime.now()),
                              },
                            )
                            .toList(),
                      );

                      if (paymentEntryCreated) {
                        // Kept so the knock-off per invoice can be read back
                        // from JDE when the user returns from the gateway.
                        await invoicesController.recordPayment(
                          batchNumber: batchNumber,
                          receiptNumber: receiptNumber,
                          invoiceInfos:
                              invoicesController.rxSelectedInvoiceInfos,
                        );

                        final customerDetail =
                            userController.rxCustomerDetail.value;

                        if (customerDetail.canSendSMS) {
                          Api.sendOrderEntrySMS(
                            orderNumber: receiptNumber,
                            mobileNumber: customerDetail.mobileNumber,
                          );
                        }

                        if (invoicesController.selectedDiscountedAmount == 0) {
                          await Api.updateInvoicePaymentRequest(
                            batchNumber: batchNumber,
                            receiptNumber: receiptNumber,
                            company: userController
                                .rxCustomerDetail.value.companyCode,
                            customerNumber: userController
                                .rxCustomerDetail.value.soldToNumber,
                            sp: 'I',
                            paymentReference: '',
                            paymentRemark: '',
                          );

                          // No gateway step: knock-off can be read now.
                          invoicesController.rxSelectedInvoiceInfos.clear();

                          invoicesController.refreshInvoices();
                        } else {
                          await Api.updateInvoicePaymentRequest(
                            batchNumber: batchNumber,
                            receiptNumber: receiptNumber,
                            company: userController
                                .rxCustomerDetail.value.companyCode,
                            customerNumber: userController
                                .rxCustomerDetail.value.soldToNumber,
                            sp: 'I',
                            paymentReference: '',
                            paymentRemark: '',
                          );
                          // for PD
                          /*final plainText =
                               'txn-id=$receiptNumber|txn-datetime=${DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now())}|txn-amount=${invoicesController.selectedDiscountedAmount.toStringAsFixed(2)}|txn-for=payment|wallet-payment-mode=2|return-url=https://b2b.amefird.in|cancel-url=https://b2b.amefird.in|';*/
                          // for PY
                          // final plainText = {
                          //   "txn-id": receiptNumber,
                          //   "txn-session-id": receiptNumber,
                          //   "user-code": "",
                          //   "clientCode": "WT-2519",
                          //   "txn-amount": "99.00",
                          //   "txn-datetime": DateFormat('dd/MM/yyyy HH:mm:ss')
                          //       .format(DateTime.now()),
                          //   "txn-for": "payment",
                          //   "payment-mode": "1",
                          //   "challan-expiry-date": "",
                          //   // Back to wherever this app is served from
                          //   // (localhost:<port> locally, b2b.amefird.in when
                          //   // deployed).
                          //   "return-url": "https://b2b.amefird.in/vytldev/",
                          //   "cancel-url": "https://b2b.amefird.in/vytldev/",

                          //   "email-id": "",
                          // };

                          final plainText = {
                            "txn-id": receiptNumber,
                            "txn-session-id": receiptNumber,
                            "user-code": "",
                            "clientCode": "WT-2519",
                            "txn-amount": invoicesController
                                .selectedDiscountedAmount
                                .toStringAsFixed(2),
                            "txn-datetime": DateFormat('dd/MM/yyyy HH:mm:ss')
                                .format(DateTime.now()),
                            "txn-for": "payment",
                            "payment-mode": "1",
                            "challan-expiry-date": "",

                            // Back to wherever this app was opened from: the
                            // dev proxy (localhost:8000, see
                            // scripts/run_web_payment_test.ps1) locally,
                            // b2b.amefird.in/vytldev/ when deployed.
                            "return-url": appReturnUrl,
                            "cancel-url": appCancelUrl,

                            "email-id": "",
                          };

                          // 'txn-id=$receiptNumber|txn-datetime=${DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now())}|txn-amount=${invoicesController.selectedDiscountedAmount.toStringAsFixed(2)}|txn-for=payment|wallet-payment-mode=2|return-url=https://b2b.amefird.in/vytldev|cancel-url=https://b2b.amefird.in/vytldev|';
                          // for GITHUB
                          //final plainText =
                          //    'txn-id=$receiptNumber|txn-datetime=${DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now())}|txn-amount=${invoicesController.selectedDiscountedAmount.toStringAsFixed(2)}|txn-for=payment|wallet-payment-mode=2|return-url=https://ausm-infotech.github.io/vardhman_b2b|cancel-url=https://ausm-infotech.github.io/vardhman_b2b|';

                          final encryptedString =
                              await Api.encryptInputString(plainText);

                          log('Encrypted String: $encryptedString');

                          if (encryptedString != null) {
                            // for PD
                            /*final paymentFormElement = html.document
                                 .createElement('form')
                               ..setAttribute('id', 'paymentForm')
                               ..setAttribute('method', "POST")
                               ..setAttribute(
                                   'action', "https://generic.ipay2corp.icici.bank.in/gp2c-api/ws/payment") //https://generic.ipay2corp.icicibank.com/gp2c-api/ws/payment
                               ..setAttribute('target', '_self');

                             final walletClientCodeInput =
                                 html.document.createElement('input')
                                   ..setAttribute('type', 'text')
                                   ..setAttribute('name', 'walletClientCode')
                                   ..setAttribute('value', 'WT-1573');*/
                            // for PD

                            // for PY
                            final paymentFormElement =
                                html.document.createElement('form')
                                  ..setAttribute('id', 'paymentForm')
                                  ..setAttribute('method', "POST")
                                  ..setAttribute('action',
                                      "https://digicxuat.icici.bank.in/finhub-collect/payment")
                                  ..setAttribute('target', '_self');

                            final walletClientCodeInput =
                                html.document.createElement('input')
                                  ..setAttribute('type', 'text')
                                  ..setAttribute('name', 'clientCode')
                                  ..setAttribute('value', 'WT-2519');
                            // for PY

                            paymentFormElement.append(walletClientCodeInput);

                            final walletRequestMessageInput = html.document
                                .createElement('input')
                              ..setAttribute('type', 'text')
                              ..setAttribute('name', 'collectRequestMessage')
                              ..setAttribute(
                                'value',
                                encryptedString,
                              );

                            paymentFormElement
                                .append(walletRequestMessageInput);

                            final paymentForm =
                                html.document.body?.append(paymentFormElement)
                                    as html.FormElement;

                            await savePaymentReturn(
                              navRailIndex: Get.find<HomeController>()
                                  .rxNavRailIndex
                                  .value,
                              receiptNumber: receiptNumber,
                            );

                            logPayment(
                              'gateway_submit',
                              receiptNumber: receiptNumber,
                              data: paymentFormData(paymentFormElement),
                            );

                            paymentForm.submit();
                          }
                        }

                        Get.back();

                        Get.back();

                        toastification.show(
                          autoCloseDuration: Duration(seconds: 3),
                          primaryColor: VardhmanColors.green,
                          title: Text(
                            'Navigating to Payment Gateway, payment confirmation will be sent via E-mail/SMS in some time. ',
                          ),
                        );

                        return;
                      }
                    }

                    toastification.show(
                      autoCloseDuration: Duration(seconds: 3),
                      primaryColor: VardhmanColors.red,
                      title: Text(
                        'Some error initiating payment, please try later.',
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(
                height: 24,
              ),
              const Text(
                  'Payment confirmation will be sent via E-mail/SMS in some time.'),
            ],
          ),
        ),
      ),
    );
  }
}

/// Selected invoices as a table on the Pay confirmation, with a total row,
/// so the user can check every line before Proceed.
class _PaymentSummaryTable extends StatelessWidget {
  final List<InvoiceInfo> invoiceInfos;

  final String Function(InvoiceInfo invoiceInfo) poNumberOf;

  const _PaymentSummaryTable({
    required this.invoiceInfos,
    required this.poNumberOf,
  });

  static double amountToPay(InvoiceInfo invoiceInfo) =>
      invoiceInfo.status == InvoiceStatus.discounted
          ? invoiceInfo.discountAmount
          : invoiceInfo.openAmount;

  static String statusLabel(InvoiceStatus status) => switch (status) {
        InvoiceStatus.overdue => 'Overdue',
        InvoiceStatus.notDue => 'Not Due',
        InvoiceStatus.discounted => 'Discount',
        InvoiceStatus.creditNote => 'Credit Note',
        InvoiceStatus.onHold => 'On Hold',
        InvoiceStatus.processing => 'Processing',
        InvoiceStatus.partiallyPaid => 'Partly Paid',
        InvoiceStatus.paid => 'Paid',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colorScheme = theme.colorScheme;

    final statusColors = theme.extension<StatusColors>();

    final amountFormat = NumberFormat('#,##,##0.00', 'en_IN');

    final dateFormat = DateFormat('dd/MM/yyyy');

    final headerStyle = theme.textTheme.labelMedium?.copyWith(
      color: colorScheme.surface,
      fontWeight: FontWeight.bold,
    );

    final cellStyle = theme.textTheme.bodySmall?.copyWith(
      color: colorScheme.secondary,
      fontSize: 13,
    );

    final totalStyle = cellStyle?.copyWith(fontWeight: FontWeight.bold);

    Color statusColor(InvoiceStatus status) => switch (status) {
          InvoiceStatus.overdue => colorScheme.error,
          InvoiceStatus.discounted =>
            statusColors?.success ?? colorScheme.primary,
          InvoiceStatus.notDue => statusColors?.warning ?? colorScheme.primary,
          _ => colorScheme.secondary,
        };

    DataColumn column(String label, {bool numeric = false}) => DataColumn(
          numeric: numeric,
          label: Text(label, style: headerStyle),
        );

    final totalOpen = invoiceInfos.fold<double>(
      0,
      (sum, invoiceInfo) => sum + invoiceInfo.openAmount,
    );

    final totalToPay = invoiceInfos.fold<double>(
      0,
      (sum, invoiceInfo) => sum + amountToPay(invoiceInfo),
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 320),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.surfaceContainerHighest),
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 38,
              dataRowMinHeight: 36,
              dataRowMaxHeight: 36,
              columnSpacing: 20,
              horizontalMargin: 12,
              headingRowColor: WidgetStatePropertyAll(colorScheme.secondary),
              columns: [
                column('#', numeric: true),
                column('Invoice No.'),
                column('Invoice Date'),
                column('PO No.'),
                column('Due Date'),
                column('Status'),
                column('Open Amount (₹)', numeric: true),
                column('Discount (₹)', numeric: true),
                column('Amount to Pay (₹)', numeric: true),
              ],
              rows: [
                ...invoiceInfos.indexed.map(
                  (entry) {
                    final (index, invoiceInfo) = entry;

                    final toPay = amountToPay(invoiceInfo);

                    final discount = invoiceInfo.openAmount - toPay;

                    DataCell cell(String text) =>
                        DataCell(Text(text, style: cellStyle));

                    return DataRow(
                      color: WidgetStatePropertyAll(
                        index.isOdd
                            ? colorScheme.surfaceContainerHighest
                            : null,
                      ),
                      cells: [
                        cell('${index + 1}'),
                        cell(
                            '${invoiceInfo.invoiceNumber} ${invoiceInfo.docType}'),
                        cell(dateFormat.format(invoiceInfo.date)),
                        cell(poNumberOf(invoiceInfo).isEmpty
                            ? '-'
                            : poNumberOf(invoiceInfo)),
                        cell(dateFormat.format(invoiceInfo.discountDueDate)),
                        DataCell(
                          Text(
                            statusLabel(invoiceInfo.status),
                            style: cellStyle?.copyWith(
                              color: statusColor(invoiceInfo.status),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        cell(amountFormat.format(invoiceInfo.openAmount)),
                        cell(
                            discount > 0 ? amountFormat.format(discount) : '-'),
                        cell(amountFormat.format(toPay)),
                      ],
                    );
                  },
                ),
                DataRow(
                  color: WidgetStatePropertyAll(
                    colorScheme.primary.withAlpha(24),
                  ),
                  cells: [
                    const DataCell(Text('')),
                    DataCell(Text('Total', style: totalStyle)),
                    const DataCell(Text('')),
                    const DataCell(Text('')),
                    const DataCell(Text('')),
                    const DataCell(Text('')),
                    DataCell(Text(amountFormat.format(totalOpen),
                        style: totalStyle)),
                    DataCell(
                      Text(
                        totalOpen - totalToPay > 0
                            ? amountFormat.format(totalOpen - totalToPay)
                            : '-',
                        style: totalStyle,
                      ),
                    ),
                    DataCell(
                      Text(
                        amountFormat.format(totalToPay),
                        style: totalStyle?.copyWith(color: colorScheme.primary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
