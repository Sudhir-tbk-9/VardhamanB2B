import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:vardhman_b2b/common/new_order_text_field.dart';
import 'package:vardhman_b2b/orders/direct_delivery_tc.dart';

void main() {
  test('the hint follows a Remark of only "TC Required"', () {
    expect(
      DirectDeliveryTc.tcRemarkHint('TC Required'),
      ', add your own remark here (optional)',
    );
    expect(
      DirectDeliveryTc.tcRemarkHint('TC Required,'),
      ' add your own remark here (optional)',
    );
    expect(DirectDeliveryTc.tcRemarkHint('TC Required, RUSH'), isNull);
    expect(DirectDeliveryTc.tcRemarkHint(''), isNull);
    expect(DirectDeliveryTc.tcRemarkHint('RUSH'), isNull);
  });

  testWidgets('shown in the field after the text, never in its value',
      (tester) async {
    final remark = DirectDeliveryTc.tcRequiredRemark.obs;

    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 450,
            child: NewOrderTextField(
              labelText: 'Remark',
              rxString: remark,
              minLines: 2,
              inlineHint: DirectDeliveryTc.tcRemarkHint,
            ),
          ),
        ),
      ),
    );

    EditableText editable() =>
        tester.widget<EditableText>(find.byType(EditableText));

    // Drawn: the field's text, then the hint, in one line of the field.
    expect(
      editable()
          .controller
          .buildTextSpan(
            context: tester.element(find.byType(EditableText)),
            withComposing: false,
          )
          .toPlainText(),
      'TC Required, add your own remark here (optional)',
    );

    // The value, and so the remark saved, is only the text.
    expect(editable().controller.text, 'TC Required');
    expect(remark.value, 'TC Required');

    // Once the user types a remark, the hint goes.
    await tester.enterText(find.byType(EditableText), 'TC Required, RUSH');
    await tester.pump();

    expect(remark.value, 'TC Required, RUSH');
    expect(
      editable()
          .controller
          .buildTextSpan(
            context: tester.element(find.byType(EditableText)),
            withComposing: false,
          )
          .toPlainText(),
      'TC Required, RUSH',
    );
  });
}
