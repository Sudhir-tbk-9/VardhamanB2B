import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:vardhman_b2b/bulk/excel_import_dialog.dart';
import 'package:vardhman_b2b/bulk/excel_line.dart';
import 'package:vardhman_b2b/bulk/spreadsheet_reader.dart';
import 'package:vardhman_b2b/common/primary_button.dart';

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

const _header = [
  'po_no',
  'Merchandiser',
  'buyer_name',
  'light_sources',
  'article',
  'shade',
  'style_no',
  'quantity',
];

void main() {
  test('the Sample Excel file: sheet bulk_csv_demo, 8 columns, 2 lines', () {
    final bytes = File('assets/Stitch Connect Orders.xlsx').readAsBytesSync();

    expect(Excel.decodeBytes(bytes).tables.keys, ['bulk_csv_demo']);

    final sheetRows = readSpreadsheetRows(
      bytes: bytes,
      fileName: 'Stitch Connect Orders.xlsx',
    );

    expect(sheetRows, [
      _header,
      ['ABC123...', 'ABC', 'XYZ', 'D65,U35', 'A8930', 'P91', '1A2B3…', '123…'],
      [
        'ABC123...',
        'ABC',
        'XYZ',
        'U35,INCA',
        'RP924',
        'W32117',
        '1A2B3…',
        '123…',
      ],
    ]);

    final rows = importRowsFromSheet(sheetRows);

    expect(rows.map((row) => row.rowNumber), [1, 2]);
    expect(rows.map((row) => row.line.article), ['A8930', 'RP924']);
    expect(rows.map((row) => row.line.shade), ['P91', 'W32117']);
    expect(rows.every((row) => row.line.uom.isEmpty), isTrue);
  });

  test('the sample layout has no uom column: the UOM is left to the lookup',
      () {
    final line = ExcelLine.fromCells(
      ['ABC123', 'ABC', 'XYZ', 'D65,U35', 'a8930', 'p91', '1A2B3', '123'],
    );

    expect(line.poNumber, 'ABC123');
    expect(line.merchandiser, 'ABC');
    expect(line.buyer, 'XYZ');
    expect(line.lightSources, 'D65,U35');
    expect(line.article, 'A8930');
    expect(line.shade, 'P91');
    expect(line.styleNo, '1A2B3');
    expect(line.quantity, 123);
    expect(line.uom, '');
    expect(line.hasError, isFalse);
  });

  test('a 0 quantity is its own error, not "Missing Quantity"', () {
    final zero = ExcelLine.fromCells(
      ['PO1', 'M', 'B', 'D65', 'A100', 'S1', '', '0'],
    );

    expect(zero.isBlank, isFalse);
    expect(zero.missingRequiredFields, isEmpty);
    expect(zero.quantityError, 'Quantity must be at least 1 (is "0")');
    expect(zero.hasError, isTrue);

    final empty = ExcelLine.fromCells(
      ['PO1', 'M', 'B', 'D65', 'A100', 'S1', '', ''],
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

  test(
      'rows are numbered 1, 2, 3 whatever the sheet has; empty and '
      'repeated header rows are skipped', () {
    final rows = importRowsFromSheet([
      [],
      _header,
      ['PO1', 'M', 'B', 'D65', 'A100', 'S1', '', '5'],
      ['', '', '', '', '', '', '', ''],
      _header.map((cell) => cell.toUpperCase()).toList(),
      ['PO2', 'M', 'B', 'D65', 'A200', 'S2', '', '6'],
      ['   '],
      ['PO3', 'M', 'B', 'D65', 'A300', 'S3', '', '7'],
    ]);

    expect(rows.map((row) => row.rowNumber), [1, 2, 3]);
    expect(rows.map((row) => row.line.article), ['A100', 'A200', 'A300']);
  });

  test('a header read by name: a Sr. No. column and a uom column are fine', () {
    final rows = importRowsFromSheet([
      ['Sr No', 'PO No', 'Article', 'UOM', 'Shade', 'Qty'],
      ['17', 'PO1', 'A100', 'cn', 'S1', '4'],
      ['42', 'PO2', 'A200', '', 'S2', '9'],
    ]);

    expect(rows.map((row) => row.rowNumber), [1, 2]);
    expect(rows.first.line.poNumber, 'PO1');
    expect(rows.first.line.uom, 'CN');
    expect(rows.first.line.shade, 'S1');
    expect(rows.first.line.quantity, 4);
    expect(rows.last.line.uom, '');
  });

  test('without a recognised header the first row is a line', () {
    final rows = importRowsFromSheet([
      ['PO1', 'M', 'B', 'D65', 'A100', 'S1', '', '5'],
      ['PO2', 'M', 'B', 'D65', 'A200', 'S2', '', '6'],
    ]);

    expect(rows.map((row) => row.line.article), ['A100', 'A200']);
  });

  Future<List<ExcelImportRow>> pumpDialog(
    WidgetTester tester, {
    bool withError = true,
  }) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final rows = [
      ExcelImportRow(rowNumber: 1, line: _line()),
      ExcelImportRow(rowNumber: 2, line: _line(article: 'A200'))
        ..warning = 'Article / Shade combination not found in JDE',
      if (withError)
        ExcelImportRow(rowNumber: 3, line: _line(shade: ''))
          ..error = 'Missing Shade',
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

  bool yesEnabled(WidgetTester tester) =>
      tester
          .widget<PrimaryButton>(
            find.widgetWithText(PrimaryButton, 'Yes'),
          )
          .onPressed !=
      null;

  Finder inGrid(String text) =>
      find.descendant(of: find.byType(DataTable), matching: find.text(text));

  testWidgets(
      'green valid, yellow warning, red error rows; Yes is disabled while a '
      'red row is left', (tester) async {
    await pumpDialog(tester);

    expect(
      find.text('1 of 3 lines have errors. Fix or delete the red lines to '
          'upload the other 2.'),
      findsOneWidget,
    );
    expect(find.text('Errors (1) · Warnings (1), uploaded'), findsOneWidget);
    expect(find.textContaining('Row 3 · '), findsOneWidget);
    expect(find.textContaining('Row 2 · '), findsOneWidget);
    expect(find.textContaining('Row 1 · '), findsNothing);
    expect(find.byTooltip('Valid'), findsOneWidget);
    expect(
      find.byTooltip('Article / Shade combination not found in JDE'),
      findsOneWidget,
    );
    expect(find.byTooltip('Missing Shade'), findsOneWidget);

    // Light shades: green for valid, yellow for a warning, red for invalid.
    expect(rowColor(tester, 0), const Color(0xFFEAF6EC));
    expect(rowColor(tester, 1), const Color(0xFFFFF8E1));
    expect(rowColor(tester, 2), const Color(0xFFFDECEC));

    expect(inGrid('Fix'), findsNWidgets(3));
    expect(inGrid('Delete'), findsNWidgets(3));

    expect(yesEnabled(tester), isFalse);
    expect(
      tester
          .widget<PrimaryButton>(find.widgetWithText(PrimaryButton, 'Yes'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('yellow lines alone do not block Yes', (tester) async {
    await pumpDialog(tester, withError: false);

    expect(find.text('Upload all 2 lines? (1 with warnings)'), findsOneWidget);
    expect(find.text('Warnings (1), uploaded'), findsOneWidget);
    expect(yesEnabled(tester), isTrue);
  });

  testWidgets(
      'Delete on a row removes it, renumbers the rest and enables Yes once '
      'no red row is left', (tester) async {
    final rows = await pumpDialog(tester);

    final deleteRow3 = inGrid('Delete').last;

    await tester.ensureVisible(deleteRow3);
    await tester.pumpAndSettle();
    await tester.tap(deleteRow3);
    await tester.pumpAndSettle();

    expect(rows.map((row) => row.line.article), ['A100', 'A200']);
    expect(find.text('Upload all 2 lines? (1 with warnings)'), findsOneWidget);
    expect(find.textContaining('Errors'), findsNothing);
    expect(yesEnabled(tester), isTrue);

    // Deleting the first row renumbers the one left as 1.
    final deleteRow1 = inGrid('Delete').first;

    await tester.ensureVisible(deleteRow1);
    await tester.pumpAndSettle();
    await tester.tap(deleteRow1);
    await tester.pumpAndSettle();

    expect(rows.single.line.article, 'A200');
    expect(find.text('Upload the line? (1 with warnings)'), findsOneWidget);
    expect(inGrid('1'), findsOneWidget);
    expect(find.textContaining('Row 1 · '), findsOneWidget);
  });

  testWidgets('the Fix modal shows the error, and its Delete removes the row',
      (tester) async {
    final rows = await pumpDialog(tester);

    await tester.tap(find.textContaining('Row 3 · '));
    await tester.pumpAndSettle();

    expect(find.text('Fix row 3'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog).last,
        matching: find.text('Missing Shade'),
      ),
      findsOneWidget,
    );
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Save & validate'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog).last,
        matching: find.text('Delete'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Fix row 3'), findsNothing);
    expect(rows.map((row) => row.rowNumber), [1, 2]);
    expect(find.text('Upload all 2 lines? (1 with warnings)'), findsOneWidget);
    expect(yesEnabled(tester), isTrue);
  });

  testWidgets('the Fix modal of a yellow row shows its warning',
      (tester) async {
    await pumpDialog(tester);

    await tester.tap(find.textContaining('Row 2 · '));
    await tester.pumpAndSettle();

    expect(find.text('Fix row 2'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog).last,
        matching: find.text('Article / Shade combination not found in JDE'),
      ),
      findsOneWidget,
    );
  });
}
