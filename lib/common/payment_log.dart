import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:universal_html/html.dart' as html;

/// Step-by-step log of payments: JDE requests and responses, the gateway
/// payload, the return from the gateway and the payment status. Kept in
/// localStorage so it survives the round trip to the gateway and reloads,
/// and printed to the browser console with a `[PAYMENT]` prefix (debugPrint
/// works in release builds, `log()` does not).
const _paymentLogKey = 'paymentLog';

/// Oldest entries are dropped beyond this, to keep localStorage small.
const _paymentLogMaxEntries = 300;

void logPayment(
  String stage, {
  String? receiptNumber,
  Object? data,
}) {
  final entry = {
    'at': DateTime.now().toIso8601String(),
    'stage': stage,
    if (receiptNumber != null) 'receiptNumber': receiptNumber,
    if (data != null) 'data': data,
  };

  final json = jsonEncode(entry, toEncodable: (value) => value.toString());

  debugPrint('[PAYMENT] $json');

  try {
    final entries = paymentLogEntries..add(jsonDecode(json));

    final kept = entries.length > _paymentLogMaxEntries
        ? entries.sublist(entries.length - _paymentLogMaxEntries)
        : entries;

    html.window.localStorage[_paymentLogKey] = jsonEncode(kept);
  } catch (e) {
    debugPrint('[PAYMENT] could not save log entry - $e');
  }
}

/// All saved entries, oldest first. Empty when localStorage is unavailable.
List<Map<String, dynamic>> get paymentLogEntries {
  try {
    final json = html.window.localStorage[_paymentLogKey];

    if (json == null) {
      return [];
    }

    return (jsonDecode(json) as List).cast<Map<String, dynamic>>();
  } catch (_) {
    return [];
  }
}

/// Where a gateway form posts to and the fields it sends.
Map<String, dynamic> paymentFormData(html.Element form) => {
      'method': form.getAttribute('method'),
      'action': form.getAttribute('action'),
      'fields': {
        for (final input in form.querySelectorAll('input'))
          input.getAttribute('name') ?? '': input.getAttribute('value'),
      },
    };

void clearPaymentLog() {
  try {
    html.window.localStorage.remove(_paymentLogKey);
  } catch (_) {}
}
