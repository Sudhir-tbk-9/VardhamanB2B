import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:toastification/toastification.dart';
import 'package:vardhman_b2b/api/api.dart';
import 'package:vardhman_b2b/common/app_url.dart';
import 'package:vardhman_b2b/common/payment_log.dart';
import 'package:vardhman_b2b/common/payment_return.dart';
import 'package:vardhman_b2b/home/home_controller.dart';
import 'package:vardhman_b2b/common/primary_button.dart';
import 'package:vardhman_b2b/constants.dart';
import 'package:vardhman_b2b/invoices/invoices_controller.dart';
import 'package:vardhman_b2b/user/user_controller.dart';
import 'package:universal_html/html.dart' as html;
import 'package:vardhman_b2b/common/adaptive_dialog.dart';

class AdvancePaymentDialog extends StatelessWidget {
  const AdvancePaymentDialog({
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
                height: 24,
              ),
              TextField(
                controller: invoicesController.advancePaymentInputController,
                onChanged: (value) {
                  invoicesController.rxAdvancePaymentAmount.value =
                      double.tryParse(value) ?? 0;
                },
                decoration: const InputDecoration(
                  isDense: true,
                  label: Text(
                    'Amount',
                  ),
                  hintText: 'Enter the advance payment amount',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(
                height: 8,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: PrimaryButton(
                  iconData: Icons.done_outlined,
                  text: 'Proceed',
                  onPressed: invoicesController.rxAdvancePaymentAmount.value < 1
                      ? null
                      : () async {
                          final batchNumber =
                              await Api.fetchPaymentBatchNumber();

                          if (batchNumber != null) {
                            final receiptNumber = 'M$batchNumber';

                            final paymentEntryCreated =
                                await Api.createInvoicePaymentEntry(
                              paymentDetails: [
                                {
                                  "Batch_Number": batchNumber,
                                  "Company": userController
                                      .rxCustomerDetail.value.companyCode,
                                  "Source_Mobile_Portal": "B",
                                  "Customer_Number": userController
                                      .rxCustomerDetail.value.soldToNumber,
                                  "Receipt_Number": receiptNumber,
                                  "Payment_Amount": invoicesController
                                      .rxAdvancePaymentAmount.value
                                      .toStringAsFixed(2),
                                  "Payment_Date": DateFormat('MM/dd/yyyy')
                                      .format(DateTime.now()),
                                },
                              ],
                            );

                            if (paymentEntryCreated) {
                              final customerDetail =
                                  userController.rxCustomerDetail.value;

                              if (customerDetail.canSendSMS) {
                                Api.sendOrderEntrySMS(
                                  orderNumber: receiptNumber,
                                  mobileNumber: customerDetail.mobileNumber,
                                );
                              }

                              // for PD
                              /*final plainText =
                                   'txn-id=$receiptNumber|txn-datetime=${DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now())}|txn-amount=${invoicesController.selectedDiscountedAmount.toStringAsFixed(2)}|txn-for=payment|wallet-payment-mode=2|return-url=https://b2b.amefird.in|cancel-url=https://b2b.amefird.in|';*/
                              // for PY
                              // final plainText =
                              //     'txn-id=$receiptNumber|txn-datetime=${DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now())}|txn-amount=${invoicesController.selectedDiscountedAmount.toStringAsFixed(2)}|txn-for=payment|wallet-payment-mode=2|return-url=https://b2b.amefird.in/vytldev/|cancel-url=https://b2b.amefird.in/vytldev/|';

                              final plainText = {
                                "txn-id": receiptNumber,
                                "txn-session-id": receiptNumber,
                                "user-code": "",
                                "clientCode": "WT-2519",
                                // Same amount as the JDE entry's
                                // Payment_Amount above.
                                "txn-amount": invoicesController
                                    .rxAdvancePaymentAmount.value
                                    .toStringAsFixed(2),
                                "txn-datetime":
                                    DateFormat('dd/MM/yyyy HH:mm:ss')
                                        .format(DateTime.now()),
                                "txn-for": "payment",
                                "payment-mode": "1",
                                "challan-expiry-date": "",

                                // Back to wherever this app was opened from:
                                // the dev proxy (localhost:8000, see
                                // scripts/run_web_payment_test.ps1) locally,
                                // b2b.amefird.in/vytldev/ when deployed.
                                "return-url": appReturnUrl,
                                "cancel-url": appCancelUrl,

                                "email-id": "",
                              };

                              // for GITHUB
                              // final plainText =
                              //   'txn-id=$receiptNumber|txn-datetime=${DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now())}|txn-amount=${invoicesController.selectedDiscountedAmount.toStringAsFixed(2)}|txn-for=payment|wallet-payment-mode=2|return-url=https://ausm-infotech.github.io/vardhman_b2b|cancel-url=https://ausm-infotech.github.io/vardhman_b2b|';

                              final encryptedString =
                                  await Api.encryptInputString(plainText);

                              log('Encrypted String: $encryptedString');

                              if (encryptedString != null) {
                                // for PD
                                /*final paymentFormElement =
                                    html.document.createElement('form')
                                      ..setAttribute('id', 'paymentForm')
                                      ..setAttribute('method', "POST")
                                      ..setAttribute('action',
                                          "https://generic.ipay2corp.icici.bank.in/gp2c-api/ws/payment") // "https://generic.ipay2corp.icicibank.com/gp2c-api/ws/payment"
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

                                paymentFormElement
                                    .append(walletClientCodeInput);

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

                                final paymentForm = html.document.body
                                        ?.append(paymentFormElement)
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
              )
            ],
          ),
        ),
      ),
    );
  }
}
