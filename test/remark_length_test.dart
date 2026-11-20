import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:vardhman_b2b/common/new_order_text_field.dart';
import 'package:vardhman_b2b/constants.dart';
import 'package:vardhman_b2b/orders/direct_delivery_tc.dart';

void main() {
  test('a Remark is at most 35 characters', () {
    expect(remarkMaxLength, 35);
  });

  test('"TC Required, " counts: the remark after it is cut to fit', () {
    final long = 'A' * 35;
    final withTc = DirectDeliveryTc.withTcRemark(long);

    expect(withTc, startsWith('TC Required, '));
    expect(withTc.length, 35);
    expect(DirectDeliveryTc.withTcRemark('RUSH'), 'TC Required, RUSH');
    expect(DirectDeliveryTc.withTcRemark(''), 'TC Required');
  });

  testWidgets('typing stops at 35, with a count beside the label',
      (tester) async {
    final remark = ''.obs;

    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 450,
            child: NewOrderTextField(
              labelText: 'Remark',
              rxString: remark,
              maxLength: remarkMaxLength,
              showLength: true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('0/35'), findsOneWidget);

    await tester.enterText(find.byType(EditableText), 'RUSH');
    await tester.pump();

    expect(remark.value, 'RUSH');
    expect(find.text('4/35'), findsOneWidget);

    // Typed or pasted: anything past 35 is dropped.
    await tester.enterText(find.byType(EditableText), 'B' * 50);
    await tester.pump();

    expect(remark.value, 'B' * 35);
    expect(find.text('35/35'), findsOneWidget);
  });
}
