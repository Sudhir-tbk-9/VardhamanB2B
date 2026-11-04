import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:vardhman_b2b/common/catalog_search_field.dart';

void main() {
  const shades = ['SWT1', 'SWT2', 'SWT3'];

  late RxString rxShade;

  late List<String> picked;

  late GlobalKey<DropdownSearchState<String>> dropdownKey;

  Future<void> openShade(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            child: CatalogSearchField(
              labelText: 'Shade',
              rxString: rxShade,
              searchList: shades,
              dropdownKey: dropdownKey,
              onChanged: picked.add,
            ),
          ),
        ),
      ),
    );

    // As the controller does after an Article is picked.
    dropdownKey.currentState!.openDropDownSearch();

    await tester.pumpAndSettle();
  }

  setUp(() {
    rxShade = ''.obs;

    picked = [];

    dropdownKey = GlobalKey<DropdownSearchState<String>>();
  });

  testWidgets('arrow keys move through the options and Enter picks one',
      (tester) async {
    await openShade(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(rxShade.value, 'SWT2');
    expect(picked, ['SWT2']);
    expect(find.text('SWT3'), findsNothing, reason: 'popup closed');
  });

  testWidgets('Enter without arrows picks the first option', (tester) async {
    await openShade(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(rxShade.value, 'SWT1');
  });

  testWidgets('clicking the field opens it ready to type, arrow and Enter',
      (tester) async {
    final rxArticle = ''.obs;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            child: CatalogSearchField(
              labelText: 'Article',
              rxString: rxArticle,
              searchList: const ['A100', 'A200', 'B300'],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('select'));
    await tester.pumpAndSettle();

    // The search box has the cursor without being clicked.
    final searchBox = tester.widget<EditableText>(find.byType(EditableText));

    expect(searchBox.focusNode.hasFocus, isTrue);

    // Typed into whatever has focus.
    tester.testTextInput.enterText('A');
    await tester.pumpAndSettle();

    expect(find.text('B300'), findsNothing, reason: 'search narrowed');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(rxArticle.value, 'A200');
  });

  testWidgets('Enter picks the first match of the search', (tester) async {
    await openShade(tester);

    await tester.enterText(find.byType(TextField), '3');
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(rxShade.value, 'SWT3');
  });
}
