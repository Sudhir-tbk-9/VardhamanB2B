import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:toastification/toastification.dart';
import 'package:vardhman_b2b/common/secondary_button.dart';
import 'package:vardhman_b2b/constants.dart';
import 'package:vardhman_b2b/invoices/invoices_controller.dart';

/// Payment section field: selects every payable open invoice of a PO.
class SelectByPoField extends StatefulWidget {
  const SelectByPoField({super.key});

  @override
  State<SelectByPoField> createState() => _SelectByPoFieldState();
}

class _SelectByPoFieldState extends State<SelectByPoField> {
  final _textEditingController = TextEditingController();

  @override
  void dispose() {
    _textEditingController.dispose();

    super.dispose();
  }

  void _select() {
    final invoicesController = Get.find<InvoicesController>();

    final poNumber = _textEditingController.text.trim();

    if (poNumber.isEmpty) {
      return;
    }

    final added = invoicesController.selectInvoicesByPoNumber(poNumber);

    toastification.show(
      autoCloseDuration: const Duration(seconds: 3),
      primaryColor: added > 0 ? VardhmanColors.green : VardhmanColors.red,
      title: Text(
        added > 0
            ? '$added invoice${added > 1 ? 's' : ''} of PO $poNumber selected'
            : 'No payable open invoice found for PO $poNumber',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textEditingController,
              onSubmitted: (_) => _select(),
              decoration: InputDecoration(
                isDense: true,
                label: Text('Select by PO No.'),
                labelStyle: TextStyle(
                  color: VardhmanColors.darkGrey,
                  fontSize: 14,
                ),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SecondaryButton(
            wait: false,
            iconData: Icons.playlist_add_check,
            text: 'Select',
            onPressed: () async => _select(),
          ),
        ],
      ),
    );
  }
}

/// Knock-off of the last payment per invoice, read back from JDE after
/// refresh (see [InvoicesController.knockOffOf]).
class PaymentKnockOffView extends StatelessWidget {
  const PaymentKnockOffView({super.key});

  @override
  Widget build(BuildContext context) {
    final invoicesController = Get.find<InvoicesController>();

    return Obx(
      () {
        final payment = invoicesController.rxLastPayment.value;

        if (payment == null) {
          return const Center(child: Text('No Invoices Selected'));
        }

        final invoices =
            (payment['invoices'] as List).cast<Map<String, dynamic>>().toList();

        final amountFormat = NumberFormat('#,##,##0.00', 'en_IN');

        const headerStyle = TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        );

        final cellStyle = TextStyle(
          fontSize: 12,
          color: VardhmanColors.darkGrey,
        );

        DataColumn column(String label, {bool numeric = false}) => DataColumn(
              numeric: numeric,
              label: Text(label, style: headerStyle),
            );

        return Container(
          color: Colors.white,
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Last payment ${payment['receiptNumber']} · '
                      '${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(payment['date']))}'
                      ' · knock-off from JDE',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: VardhmanColors.darkGrey,
                      ),
                    ),
                  ),
                  SecondaryButton(
                    iconData: Icons.refresh,
                    text: 'Refresh',
                    onPressed: invoicesController.refreshInvoices,
                  ),
                  const SizedBox(width: 8),
                  SecondaryButton(
                    wait: false,
                    iconData: Icons.close,
                    text: 'Dismiss',
                    onPressed: invoicesController.dismissLastPayment,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowHeight: 36,
                      dataRowMinHeight: 34,
                      dataRowMaxHeight: 40,
                      columnSpacing: 16,
                      horizontalMargin: 10,
                      headingRowColor:
                          WidgetStatePropertyAll(VardhmanColors.darkGrey),
                      columns: [
                        column('Invoice'),
                        column('PO No.'),
                        column('Paid', numeric: true),
                        column('Knocked off', numeric: true),
                        column('Open in JDE', numeric: true),
                        column('JDE Receipt'),
                        column('Status'),
                      ],
                      rows: invoices.map(
                        (invoice) {
                          final knockOff =
                              invoicesController.knockOffOf(invoice);

                          final statusColor = switch (knockOff.status) {
                            'Knocked off' => VardhmanColors.green,
                            'Not knocked off yet' ||
                            'Not returned by JDE' =>
                              VardhmanColors.red,
                            _ => VardhmanColors.orange,
                          };

                          DataCell cell(String text) =>
                              DataCell(Text(text, style: cellStyle));

                          return DataRow(
                            cells: [
                              cell(
                                  '${invoice['invoiceNumber']} ${invoice['docType']}'),
                              cell(invoice['poNumber'] ?? ''),
                              cell(amountFormat.format(
                                  (invoice['paymentAmount'] as num)
                                      .toDouble())),
                              cell(amountFormat
                                  .format(knockOff.knockedOffAmount)),
                              cell(knockOff.openAmount == null
                                  ? '-'
                                  : amountFormat.format(knockOff.openAmount)),
                              cell(
                                knockOff.receiptNumber.isEmpty
                                    ? '-'
                                    : '${knockOff.receiptNumber}'
                                        '${knockOff.receiptDate == null ? '' : ' (${DateFormat('dd/MM/yyyy').format(knockOff.receiptDate!)})'}',
                              ),
                              DataCell(
                                Text(
                                  knockOff.status,
                                  style: cellStyle.copyWith(
                                    color: statusColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ).toList(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
