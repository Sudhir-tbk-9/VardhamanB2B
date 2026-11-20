import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';
import 'package:vardhman_b2b/constants.dart';

/// The "Order ... placed successfully!" message last shown, replaced by the
/// next one so placed orders do not pile up messages.
ToastificationItem? _orderPlacedToast;

/// How long the order placed message stays. It used to be 15 minutes: it
/// then followed the user to other screens and orders, even past a logout,
/// and showed up as if out of nowhere.
const orderPlacedToastDuration = Duration(seconds: 10);

/// Shows [message] (e.g. "Order B2BB1024 placed successfully!") in green
/// for [orderPlacedToastDuration], with a countdown bar and a close button,
/// in place of any earlier order placed message.
void showOrderPlacedToast(String message) {
  final previous = _orderPlacedToast;

  if (previous != null) {
    toastification.dismiss(previous);
  }

  debugPrint('[ORDERS] $message');

  _orderPlacedToast = toastification.show(
    autoCloseDuration: orderPlacedToastDuration,
    primaryColor: VardhmanColors.green,
    showProgressBar: true,
    closeButtonShowType: CloseButtonShowType.always,
    title: Text(message),
  );
}
