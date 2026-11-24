import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vardhman_b2b/common/vardhman_loader.dart';

void main() {
  Future<void> pumpOverlay(WidgetTester tester, {required bool isLoading}) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoadingOverlay(
              isLoading: isLoading,
              child: const Center(child: Text('Orders table')),
            ),
          ),
        ),
      );

  testWidgets(
      'while loading: the screen is blurred and only the spinner shows, '
      'no panel and no text', (tester) async {
    await pumpOverlay(tester, isLoading: true);
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.widget<ImageFiltered>(find.byType(ImageFiltered)).enabled,
        isTrue);
    expect(find.byType(VardhmanLoader), findsOneWidget);

    // The only text is the screen's own, under the blur.
    expect(find.byType(Text), findsOneWidget);
    expect(find.text('Orders table'), findsOneWidget);

    // No white card around the spinner.
    expect(
      find.ancestor(
        of: find.byType(VardhmanLoader),
        matching: find.byWidgetPredicate(
          (widget) => widget is Container && widget.decoration != null,
        ),
      ),
      findsNothing,
    );
  });

  testWidgets('not loading: no blur and no spinner, the same child kept',
      (tester) async {
    await pumpOverlay(tester, isLoading: true);

    final childElement = tester.element(find.text('Orders table'));

    await pumpOverlay(tester, isLoading: false);
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.widget<ImageFiltered>(find.byType(ImageFiltered)).enabled,
        isFalse);
    expect(find.byType(VardhmanLoader), findsNothing);

    // The screen under the loader was not rebuilt from scratch.
    expect(tester.element(find.text('Orders table')), same(childElement));
  });
}
