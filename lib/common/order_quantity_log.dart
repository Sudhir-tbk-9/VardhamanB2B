import 'package:flutter/foundation.dart';
import 'package:vardhman_b2b/drift/database.dart';

/// Logs each line's quantity as an order is placed, and whether it is at
/// least 1, tagged `[ORDER]` (debugPrint, so release builds log too). Only
/// a log: placing the order does not depend on it.
void logOrderLineQuantities({
  required String orderType,
  required String b2bOrderNumber,
  required List<DraftTableData> lines,
}) {
  final notOk = lines.where((line) => line.quantity < 1).toList();

  debugPrint(
    '[ORDER] $orderType order $b2bOrderNumber quantity check, '
    '${lines.length} line(s), each must be at least 1:\n'
    '${lines.map((line) => '  Line ${line.lineNumber} ${line.article} '
        '${line.uom} ${line.shade}: Quantity ${line.quantity} → '
        '${line.quantity >= 1 ? 'OK' : 'NOT OK'}').join('\n')}\n'
    '${notOk.isEmpty ? 'All quantities OK' : '${notOk.length} line(s) with a quantity below 1'}',
  );
}
