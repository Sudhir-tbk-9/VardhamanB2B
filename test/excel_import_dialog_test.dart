import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:vardhman_b2b/bulk/excel_import_dialog.dart';
import 'package:vardhman_b2b/bulk/excel_line.dart';

ExcelLine _line({
  String article = 'A100',
  String uom = 'CN',
  String shade = 'S1',
  int quantity = 10,
  String poNumber = 'PO1',
}) =>
    ExcelLine(
      merchandiser: 'M',
      poNumber: poNumber,
      article: article,
      uom: uom,
      shade: shade,
      buyer: 'B',
      styleNo: '',
      quantity: quantity,
      lightSources: 'D65',
    );

void main() {
  test('a 0 quantity is its own error, not "Missing Quantity"', () {
    final zero = ExcelLine.fromCells(
      ['PO1', 'M', 'B', 'D65', 'A100', 'CN', 'S1', '', '0'],
    );

    expect(zero.isBlank, isFalse);
    expect(zero.missingRequiredFields, isEmpty);
    expect(zero.quantityError, 'Quantity must be at least 1 (is "0")');
    expect(zero.hasError, isTrue);

    final empty = ExcelLine.fromCells(
      ['PO1', 'M', 'B', 'D65', 'A100', 'CN', 'S1', '', ''],
    );

    expect(empty.missingRequiredFields, ['Quantity']);
    expect(empty.quantityError, isNull);

    // Fixed in the Fix modal.
    final fixed = zero.copyWith(quantity: 12, quantityText: '12');

    expect(fixed.hasError, isFalse);
    expect(fixed.quantityText, '12');

    // A copy that leaves the quantity alone keeps its text.
    expect(zero.copyWith(shade: 'S2').quantityError, isNotNull);
  });

  test('Article, Shade and Quantity are the only required fields', () {
    expect(_line().hasError, isFalse);
    expect(_line(poNumber: '').hasError, isFalse);
    expect(_line(article: '').missingRequiredFields, ['Article']);
    expect(_line(uom: '').hasError, isFalse);
    expect(_line(shade: '').missingRequiredFields, ['Shade']);
    expect(_line(quantity: 0).missingRequiredFields, ['Quantity']);
  });

  Future<List<ExcelImportRow>> pumpDialog(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final rows = [
      ExcelImportRow(rowNumber: 1, line: _line()),
      ExcelImportRow(rowNumber: 2, line: _line(article: 'A200')),
      ExcelImportRow(rowNumber: 3, line: _line(shade: 'X9'))
        ..error = 'Article / Shade not found in JDE or obsolete',
    ];

    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: ExcelImportDialog(rows: rows, onRevalidate: () async {}),
        ),
      ),
    );

    return rows;
  }

  Color? rowColor(WidgetTester tester, int index) => tester
      .widget<DataTable>(find.byType(DataTable))
      .rows[index]
      .color
      ?.resolve({});

  testWidgets('valid rows green, invalid rows red, numbered from 1',
      (tester) async {
    await pumpDialog(tester);

    expect(
      find.text('1 of 3 lines have errors and will not be uploaded. '
          'Upload the other 2?'),
      findsOneWidget,
    );
    expect(find.text('Errors (1)'), findsOneWidget);
    expect(find.textContaining('Row 3 · '), findsOneWidget);
    expect(find.textContaining('Row 2 · '), findsNothing);
    expect(find.byTooltip('Valid'), findsNWidgets(2));
    expect(find.byTooltip('Invalid'), findsOneWidget);
    expect(find.textContaining('Warning'), findsNothing);

    // Light shades: green for valid, red for invalid.
    expect(rowColor(tester, 0), const Color(0xFFEAF6EC));
    expect(rowColor(tester, 1), const Color(0xFFEAF6EC));
    expect(rowColor(tester, 2), const Color(0xFFFDECEC));

    expect(
      find.descendant(of: find.byType(DataTable), matching: find.text('1')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byType(DataTable), matching: find.text('Fix')),
      findsNWidgets(3),
    );
  });

  testWidgets('the Fix modal shows the error, and Delete removes the row',
      (tester) async {
    final rows = await pumpDialog(tester);

    await tester.tap(find.textContaining('Row 3 · '));
    await tester.pumpAndSettle();

    expect(find.text('Fix row 3'), findsOneWidget);
    expect(
      find.text('Article / Shade not found in JDE or obsolete'),
      findsOneWidget,
    );
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Save & validate'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Fix row 3'), findsNothing);
    expect(rows.map((row) => row.rowNumber), [1, 2]);
    expect(find.text('Errors (1)'), findsNothing);
    expect(find.text('Upload all 2 lines?'), findsOneWidget);
  });

  testWidgets(
      'a valid row shows no message in the Fix modal, and can be '
      'deleted', (tester) async {
    final rows = await pumpDialog(tester);

    final firstFix = find
        .descendant(of: find.byType(DataTable), matching: find.text('Fix'))
        .first;

    await tester.ensureVisible(firstFix);
    await tester.pumpAndSettle();
    await tester.tap(firstFix);
    await tester.pumpAndSettle();

    expect(find.text('Fix row 1'), findsOneWidget);
    // Only row 3's line in the errors panel behind: nothing in the modal.
    expect(find.textContaining('JDE'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(rows.map((row) => row.rowNumber), [2, 3]);
  });
}
