import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

/// Logs the user out after [timeout] without any activity: a mouse move,
/// click, scroll, touch or key press anywhere in the app counts.
///
/// Activity only records a time; a periodic check compares it with
/// [timeout], so a moving mouse does not restart a timer on every event, and
/// a tab left in the background (where browsers slow timers down) is still
/// logged out on the next check.
class IdleLogout {
  IdleLogout({
    required this.isLoggedIn,
    required this.onTimeout,
    this.timeout = const Duration(minutes: 5),
    this.checkEvery = const Duration(seconds: 15),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// No timeout while logged out (login, OTP, password screens).
  final bool Function() isLoggedIn;

  /// Called once per idle period, while logged in.
  final void Function() onTimeout;

  final Duration timeout;

  final Duration checkEvery;

  final DateTime Function() _clock;

  late DateTime _lastActivity = _clock();

  Timer? _timer;

  bool _wasLoggedIn = false;

  void start() {
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointerEvent);

    HardwareKeyboard.instance.addHandler(_onKeyEvent);

    _timer = Timer.periodic(checkEvery, (_) => check());
  }

  void stop() {
    _timer?.cancel();

    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointerEvent);

    HardwareKeyboard.instance.removeHandler(_onKeyEvent);
  }

  /// Records activity now.
  void touch() => _lastActivity = _clock();

  void _onPointerEvent(PointerEvent event) => touch();

  bool _onKeyEvent(KeyEvent event) {
    touch();

    // Not handled here: the key goes on to the focused field.
    return false;
  }

  /// Logs out when logged in and idle for [timeout]. A fresh login starts
  /// the idle time from the login itself.
  void check() {
    final loggedIn = isLoggedIn();

    if (loggedIn && !_wasLoggedIn) {
      touch();
    }

    _wasLoggedIn = loggedIn;

    if (loggedIn && _clock().difference(_lastActivity) >= timeout) {
      _wasLoggedIn = false;

      onTimeout();
    }
  }
}
