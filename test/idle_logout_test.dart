import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vardhman_b2b/login/idle_logout.dart';

void main() {
  late DateTime now;
  late bool loggedIn;
  late int logouts;
  late IdleLogout idle;

  setUp(() {
    now = DateTime(2026, 11, 19, 10);
    loggedIn = true;
    logouts = 0;
    idle = IdleLogout(
      isLoggedIn: () => loggedIn,
      onTimeout: () {
        logouts++;
        loggedIn = false;
      },
      clock: () => now,
    );
  });

  void wait(Duration duration) {
    now = now.add(duration);
    idle.check();
  }

  test('logged out after 5 minutes without activity', () {
    idle.check();

    wait(const Duration(minutes: 4, seconds: 59));
    expect(logouts, 0);

    wait(const Duration(seconds: 1));
    expect(logouts, 1);
  });

  test('activity restarts the 5 minutes', () {
    idle.check();

    wait(const Duration(minutes: 4));
    idle.touch();

    wait(const Duration(minutes: 4));
    expect(logouts, 0);

    wait(const Duration(minutes: 1));
    expect(logouts, 1);
  });

  test('no timeout while logged out; a login starts the 5 minutes', () {
    loggedIn = false;
    idle.check();

    wait(const Duration(minutes: 30));
    expect(logouts, 0);

    // Logged in after a long time on the login screen.
    loggedIn = true;
    wait(const Duration(seconds: 15));
    expect(logouts, 0);

    wait(const Duration(minutes: 4));
    expect(logouts, 0);

    wait(const Duration(minutes: 1));
    expect(logouts, 1);
  });

  testWidgets('a tap or a key press in the app counts as activity',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: TextField(autofocus: true))),
    );

    idle.start();

    idle.check();

    now = now.add(const Duration(minutes: 4));
    await tester.tap(find.byType(TextField));

    now = now.add(const Duration(minutes: 4));
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);

    now = now.add(const Duration(minutes: 4));
    idle.check();
    expect(logouts, 0);

    now = now.add(const Duration(minutes: 1));
    idle.check();
    expect(logouts, 1);

    idle.stop();
  });
}
