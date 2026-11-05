import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:vardhman_b2b/common/new_order_text_field.dart';
import 'package:vardhman_b2b/common/secondary_button.dart';

void main() {
  testWidgets('buttons inside a field clear its border', (tester) async {
    final rxFileName = ''.obs;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: NewOrderTextField(
              labelText: 'File Upload',
              isEnabled: false,
              rxString: rxFileName,
              trailingWidget: SecondaryButton(
                text: 'Choose File',
                onPressed: () async {},
              ),
            ),
          ),
        ),
      ),
    );

    final box = tester.getRect(find.byType(FieldBox));

    final button = tester.getRect(
      find
          .descendant(
            of: find.byType(SecondaryButton),
            matching: find.byType(Container),
          )
          .first,
    );

    expect(box.height, 36);

    // Room above, below and to the right of the button.
    expect(button.top - box.top, greaterThanOrEqualTo(4));
    expect(box.bottom - button.bottom, greaterThanOrEqualTo(4));
    expect(box.right - button.right, greaterThanOrEqualTo(4));
  });
}
