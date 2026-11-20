import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';
import 'package:vardhman_b2b/constants.dart';
import 'package:vardhman_b2b/drift/database.dart';

/// Checks every line's quantity before an order is placed: each must be at
/// least 1. Logs each line, tagged `[ORDER]` (debugPrint, so release builds
/// log too). With a line below 1 (e.g. a 0 from an older Excel upload) it
/// shows those lines in a red message and returns false: the order is not
/// placed until they are fixed or deleted.
bool checkOrderLineQuantities({
  required String orderType,
  required List<DraftTableData> lines,
}) {
  final zeroLines = lines.where((line) => line.quantity < 1).toList();

  // Numbered as in the lines table: 1 for the first line added.
  String lineLabel(DraftTableData line) =>
      'Line ${lines.indexOf(line) + 1} (${line.article} ${line.shade})';

  debugPrint(
    '[ORDER] $orderType order quantity check, ${lines.length} line(s), each '
    'must be at least 1:\n'
    '${lines.map((line) => '  ${lineLabel(line)} ${line.uom}: Quantity '
        '${line.quantity} → ${line.quantity >= 1 ? 'OK' : 'NOT OK'}').join('\n')}\n'
    '${zeroLines.isEmpty ? 'All quantities OK' : 'Order NOT placed: ${zeroLines.length} line(s) with a quantity below 1'}',
  );

  if (zeroLines.isEmpty) {
    return true;
  }

  toastification.show(
    autoCloseDuration: const Duration(seconds: 10),
    primaryColor: VardhmanColors.red,
    title: const Text('Order not placed: quantity 0'),
    description: Text(
      '${zeroLines.map(lineLabel).join(', ')} '
      '${zeroLines.length == 1 ? 'has' : 'have'} a quantity of 0. Select '
      '${zeroLines.length == 1 ? 'it' : 'them'} to update the quantity, or '
      'delete ${zeroLines.length == 1 ? 'it' : 'them'}.',
    ),
  );

  return false;
}
