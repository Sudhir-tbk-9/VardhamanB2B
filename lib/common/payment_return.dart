import 'dart:convert';
import 'dart:developer';

import 'package:universal_html/html.dart' as html;

/// Leaving for the payment gateway (or any external link opened in the same
/// tab) unloads the Flutter page, so the app boots from scratch when the user
/// comes back. This marker, saved in the tab's sessionStorage just before
/// leaving, lets the app log the user straight back in, reopen the tab they
/// left from and, for a payment, check its status.
const _paymentReturnKey = 'paymentReturn';

/// A marker older than this is ignored: the user did not come back from the
/// gateway, so the normal login (password) screen is shown.
const _paymentReturnMaxAge = Duration(minutes: 30);

/// [receiptNumber] is null when leaving for an external link rather than a
/// payment: the tab is restored but no payment status is checked.
Future<void> savePaymentReturn({
  required int navRailIndex,
  String? receiptNumber,
}) async {
  try {
    html.window.sessionStorage[_paymentReturnKey] = jsonEncode({
      'navRailIndex': navRailIndex,
      if (receiptNumber != null) 'receiptNumber': receiptNumber,
      'savedAt': DateTime.now().toIso8601String(),
    });
  } catch (e) {
    log('savePaymentReturn error - $e');
  }
}

/// The saved marker, or null when no recent payment is pending or
/// sessionStorage is unavailable.
Map<String, dynamic>? get _pendingMarker {
  try {
    final json = html.window.sessionStorage[_paymentReturnKey];

    if (json == null) {
      return null;
    }

    final marker = jsonDecode(json) as Map<String, dynamic>;

    final savedAt = DateTime.parse(marker['savedAt'] as String);

    if (DateTime.now().difference(savedAt) > _paymentReturnMaxAge) {
      return null;
    }

    return marker;
  } catch (e) {
    log('pendingPaymentReturn error - $e');

    return null;
  }
}

/// Nav rail index to return to, or null when no recent payment is pending.
int? get pendingPaymentReturn {
  try {
    return _pendingMarker?['navRailIndex'] as int?;
  } catch (_) {
    return null;
  }
}

/// Receipt number of the pending payment, or null when none is pending.
String? get pendingPaymentReceiptNumber {
  try {
    return _pendingMarker?['receiptNumber'] as String?;
  } catch (_) {
    return null;
  }
}

/// Opens [url] in this tab and brings the user back to [navRailIndex],
/// still logged in, when they return to the app (back button or a redirect
/// to the app's URL).
Future<void> leaveAppTo(String url, {required int navRailIndex}) async {
  await savePaymentReturn(navRailIndex: navRailIndex);

  html.window.location.assign(url);
}

/// What the gateway reported when it sent the user back.
class GatewayResult {
  const GatewayResult({
    required this.isFailed,
    this.errorMessage,
  });

  final bool isFailed;

  /// The gateway's own text, e.g. "Payment Failed"; null when it sent none.
  final String? errorMessage;
}

/// The gateway's result from the return URL's query parameters
/// (`?errorStatus=0&collectResponseMessage=…` on success,
/// `?errorStatus=1&errorMessage=Payment+Failed` on failure), or null when the
/// app was not opened by a gateway return. Any errorStatus other than `0`
/// counts as failed, so a cancel or an unknown code is never shown as paid.
GatewayResult? gatewayResultOf(Uri url) {
  final errorStatus = url.queryParameters['errorStatus']?.trim();

  if (errorStatus == null) {
    return null;
  }

  final errorMessage = url.queryParameters['errorMessage']?.trim();

  return GatewayResult(
    isFailed: errorStatus != '0',
    errorMessage:
        errorMessage == null || errorMessage.isEmpty ? null : errorMessage,
  );
}

/// The gateway's return lands on the app with its response as query
/// parameters (`?errorStatus=…&collectResponseMessage=…`). Once read, drop
/// them from the address bar so it shows the plain app URL again. The history
/// state is kept so Flutter's own navigation entries are untouched.
void clearGatewayQueryFromUrl() {
  try {
    final location = html.window.location;

    if ((location.search ?? '').isEmpty) {
      return;
    }

    html.window.history.replaceState(
      html.window.history.state,
      '',
      '${location.pathname}${location.hash}',
    );
  } catch (e) {
    log('clearGatewayQueryFromUrl error - $e');
  }
}

Future<void> clearPaymentReturn() async {
  try {
    html.window.sessionStorage.remove(_paymentReturnKey);
  } catch (e) {
    log('clearPaymentReturn error - $e');
  }
}
