import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toastification/toastification.dart';
import 'package:vardhman_b2b/common/order_placed_toast.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester) => tester.pumpWidget(
        const ToastificationWrapper(
          child: MaterialApp(home: Scaffold(body: SizedBox())),
        ),
      );

  testWidgets('the message closes by itself after 10 seconds', (tester) async {
    await pumpApp(tester);

    showOrderPlacedToast('Order B2BB1024 placed successfully!');
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Order B2BB1024 placed successfully!'), findsOneWidget);

    await tester.pump(orderPlacedToastDuration);
    await tester.pumpAndSettle();

    // ignore: avoid_print
    print(tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).toList());
    expect(find.text('Order B2BB1024 placed successfully!'), findsNothing);
  });

  testWidgets('a new order replaces the last message instead of stacking',
      (tester) async {
    await pumpApp(tester);

    showOrderPlacedToast('Order B2BB1024 placed successfully!');
    await tester.pump(const Duration(seconds: 1));

    showOrderPlacedToast('Order B2BD2048 placed successfully!');

    // Frame by frame, as in the app: the old message animates out.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Order B2BB1024 placed successfully!'), findsNothing);
    expect(find.text('Order B2BD2048 placed successfully!'), findsOneWidget);

    await tester.pump(orderPlacedToastDuration);
    await tester.pumpAndSettle();
  });

  testWidgets('all messages close on logout (dismissAll)', (tester) async {
    await pumpApp(tester);

    showOrderPlacedToast('Order B2BB1024 placed successfully!');
    await tester.pump(const Duration(seconds: 1));

    toastification.dismissAll(delayForAnimation: false);
    await tester.pumpAndSettle();

    // ignore: avoid_print
    print(tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).toList());
    expect(find.text('Order B2BB1024 placed successfully!'), findsNothing);
  });
}
