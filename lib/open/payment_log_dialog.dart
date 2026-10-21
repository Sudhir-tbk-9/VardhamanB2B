import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:toastification/toastification.dart';
import 'package:vardhman_b2b/common/payment_log.dart';
import 'package:vardhman_b2b/common/primary_button.dart';
import 'package:vardhman_b2b/common/secondary_button.dart';
import 'package:vardhman_b2b/constants.dart';

/// Shows the payment log (see payment_log.dart), newest first, grouped by
/// receipt number, with each entry's payload or response.
class PaymentLogDialog extends StatefulWidget {
  const PaymentLogDialog({super.key});

  @override
  State<PaymentLogDialog> createState() => _PaymentLogDialogState();
}

class _PaymentLogDialogState extends State<PaymentLogDialog> {
  var _entries = paymentLogEntries.reversed.toList();

  String? _receiptNumber;

  static const _encoder = JsonEncoder.withIndent('  ');

  List<Map<String, dynamic>> get _shownEntries => _receiptNumber == null
      ? _entries
      : _entries
          .where((entry) => entry['receiptNumber'] == _receiptNumber)
          .toList();

  List<String> get _receiptNumbers => _entries
      .map((entry) => entry['receiptNumber'] as String?)
      .nonNulls
      .toSet()
      .toList();

  Color _colorOf(String stage) =>
      stage.endsWith('_error') || stage.endsWith('_failed')
          ? VardhmanColors.error
          : stage.startsWith('payment_status')
              ? VardhmanColors.green
              : stage.startsWith('gateway')
                  ? VardhmanColors.orange
                  : VardhmanColors.darkGrey;

  String _timeOf(Map<String, dynamic> entry) {
    final at = DateTime.tryParse('${entry['at']}');

    return at == null ? '' : DateFormat('dd/MM HH:mm:ss').format(at);
  }

  @override
  Widget build(BuildContext context) {
    final shownEntries = _shownEntries;

    return Dialog(
      child: Container(
        width: 900,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
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
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Payment log',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                DropdownButton<String?>(
                  value: _receiptNumber,
                  hint: const Text('All receipts'),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('All receipts'),
                    ),
                    for (final receiptNumber in _receiptNumbers)
                      DropdownMenuItem(
                        value: receiptNumber,
                        child: Text(receiptNumber),
                      ),
                  ],
                  onChanged: (value) => setState(() => _receiptNumber = value),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Flexible(
              child: shownEntries.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No payment activity logged yet.'),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: shownEntries.length,
                      itemBuilder: (context, index) {
                        final entry = shownEntries[index];

                        final stage = '${entry['stage']}';

                        // Own Material: the tile's ink would otherwise be
                        // painted under the dialog's white Container.
                        return Material(
                          type: MaterialType.transparency,
                          child: ExpansionTile(
                            dense: true,
                            tilePadding: EdgeInsets.zero,
                            title: Text(
                              stage,
                              style: TextStyle(
                                color: _colorOf(stage),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              '${_timeOf(entry)}'
                              '${entry['receiptNumber'] == null ? '' : '  •  ${entry['receiptNumber']}'}',
                            ),
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(8),
                                color: VardhmanColors.dividerGrey,
                                child: SelectableText(
                                  _encoder.convert(entry['data']),
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SecondaryButton(
                  iconData: Icons.delete_outline,
                  text: 'Clear',
                  onPressed: () async {
                    clearPaymentLog();

                    setState(() {
                      _entries = [];
                      _receiptNumber = null;
                    });
                  },
                ),
                const SizedBox(width: 8),
                SecondaryButton(
                  iconData: Icons.copy,
                  text: 'Copy',
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(
                        text: _encoder.convert(shownEntries.reversed.toList()),
                      ),
                    );

                    toastification.show(
                      autoCloseDuration: const Duration(seconds: 3),
                      primaryColor: VardhmanColors.green,
                      title: const Text('Payment log copied'),
                    );
                  },
                ),
                const SizedBox(width: 8),
                PrimaryButton(
                  text: 'Close',
                  onPressed: () async => Get.back(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
