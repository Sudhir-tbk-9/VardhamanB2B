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

    // Plain example values: no "..." / "…" after them.
    expect(sheetRows, [
      _header,
      ['ABC123', 'ABC', 'XYZ', 'D65,U35', 'A8930', 'P91', '1A2B3', '123'],
      ['ABC123', 'ABC', 'XYZ', 'U35,INCA', 'RP924', 'W32117', '1A2B3', '123'],
    ]);

    final rows = importRowsFromSheet(sheetRows);

    expect(rows.map((row) => row.rowNumber), [1, 2]);
    expect(rows.map((row) => row.line.article), ['A8930', 'RP924']);
    expect(rows.map((row) => row.line.shade), ['P91', 'W32117']);
    expect(rows.map((row) => row.line.quantity), [123, 123]);
    expect(rows.every((row) => row.line.uom.isEmpty), isTrue);
    expect(rows.every((row) => !row.line.hasError), isTrue);
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

  ExcelLine withQuantity(String text) => ExcelLine.fromCells(
        ['PO1', 'M', 'B', 'D65', 'A100', 'S1', '', text],
      );

  test(
      'Quantity: digits only, at least 1; no negative, decimal or other '
      'characters', () {
    for (final ok in ['1', '12', '0012', ' 25 ']) {
      expect(withQuantity(ok).quantityError, isNull, reason: ok);
    }

    expect(withQuantity('0012').quantity, 12);

    final expected = {
      '0': 'Quantity must be at least 1 (is "0")',
      '000': 'Quantity must be at least 1 (is "000")',
      '-5': 'Quantity cannot be negative (is "-5")',
      '-2.5': 'Quantity cannot be negative (is "-2.5")',
      '12.5': 'Quantity must be a whole number, no decimals (is "12.5")',
      '12.0': 'Quantity must be a whole number, no decimals (is "12.0")',
      '12a': 'Quantity must be numbers only, no other characters (is "12a")',
      '+5': 'Quantity must be numbers only, no other characters (is "+5")',
      '1e2': 'Quantity must be numbers only, no other characters (is "1e2")',
      '0x10':
          'Quantity must be numbers only, no other characters (is "0x10")',
      '1,000':
          'Quantity must be numbers only, no other characters (is "1,000")',
      '1 000':
          'Quantity must be numbers only, no other characters (is "1 000")',
      'abc': 'Quantity must be numbers only, no other characters (is "abc")',
    };

    expected.forEach((text, error) {
      final line = withQuantity(text);

      expect(line.quantityError, error, reason: text);
      expect(line.quantityProblem, error, reason: text);
      // Never taken as a quantity.
      expect(line.quantity, 0, reason: text);
    });
  });

  test(
      'all problems are kept together, Article / Shade first, then the '
      'Quantity', () {
    final row = ExcelImportRow(rowNumber: 1, line: withQuantity('12.5'))
      ..error = 'Article QQ1 and Shade RR2 not found in JDE'
      ..isNotFoundInJde = true;

    expect(row.problems, [
      'Article QQ1 and Shade RR2 not found in JDE',
      'Quantity must be a whole number, no decimals (is "12.5")',
    ]);

    // Red: the Article / Shade error decides the colour, not the Quantity.
    expect(row.isValid, isFalse);
    expect(row.hasWarning, isFalse);
    expect(row.canUpload, isFalse);

    // A yellow JDE note also comes before the Quantity.
    final yellow = ExcelImportRow(rowNumber: 2, line: withQuantity('-5'))
      ..warning = 'Article / Shade combination not found in JDE';

    expect(yellow.problems, [
      'Article / Shade combination not found in JDE',
      'Quantity cannot be negative (is "-5")',
    ]);
    expect(yellow.hasWarning, isTrue);
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

  test('a Quantity problem is yellow and keeps the line from upload', () {
    final noQuantity = ExcelImportRow(rowNumber: 1, line: _line(quantity: 0));

    expect(noQuantity.line.quantityProblem, 'Missing Quantity');
    expect(noQuantity.problems, ['Missing Quantity']);
    expect(noQuantity.isValid, isTrue);
    expect(noQuantity.hasWarning, isTrue);
    expect(noQuantity.canUpload, isFalse);

    final zero = ExcelImportRow(
      rowNumber: 2,
      line: ExcelLine.fromCells(['PO1', 'M', 'B', 'D65', 'A100', 'S1', '', '0']),
    );

    expect(zero.line.quantityProblem, 'Quantity must be at least 1 (is "0")');
    expect(zero.canUpload, isFalse);

    // A combination warning alone does not keep it from upload.
    final combination = ExcelImportRow(rowNumber: 3, line: _line())
      ..warning = 'Article / Shade combination not found in JDE';

    expect(combination.canUpload, isTrue);
  });

  /// Row 1 valid, row 2 a combination warning, row 3 a Quantity to fix
  /// (yellow), row 4 a Shade not in JDE (red, Delete in the grid), row 5 a
  /// missing Shade (red, no Delete in the grid).
  Future<List<ExcelImportRow>> pumpDialog(
    WidgetTester tester, {
    bool withBlocking = true,
  }) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final rows = [
      ExcelImportRow(rowNumber: 1, line: _line()),
      ExcelImportRow(rowNumber: 2, line: _line(article: 'A200'))
        ..warning = 'Article / Shade combination not found in JDE',
      if (withBlocking) ...[
        ExcelImportRow(rowNumber: 3, line: _line(quantity: 0)),
        ExcelImportRow(rowNumber: 4, line: _line(shade: 'ZZ9'))
          ..error = 'Shade ZZ9 not found in JDE'
          ..isNotFoundInJde = true,
        ExcelImportRow(rowNumber: 5, line: _line(shade: ''))
          ..error = 'Missing Shade',
      ],
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

  Finder inFixModal(String text) => find.descendant(
        of: find.byType(AlertDialog).last,
        matching: find.text(text),
      );

  testWidgets(
      'colours: a Quantity to fix is yellow, a Shade not in JDE red; Yes is '
      'off while either is left', (tester) async {
    await pumpDialog(tester);

    expect(
      find.text('3 of 5 lines need fixing. Fix the red lines and the '
          'quantity of the yellow lines to upload the other 2.'),
      findsOneWidget,
    );
    expect(find.text('Errors (2) · Warnings (2)'), findsOneWidget);
    expect(find.textContaining('Row 3 · '), findsOneWidget);
    expect(find.textContaining('Row 4 · '), findsOneWidget);
    expect(find.textContaining('Row 1 · '), findsNothing);

    // Light shades: green valid, yellow warning or Quantity, red error.
    expect(rowColor(tester, 0), const Color(0xFFEAF6EC));
    expect(rowColor(tester, 1), const Color(0xFFFFF8E1));
    expect(rowColor(tester, 2), const Color(0xFFFFF8E1));
    expect(rowColor(tester, 3), const Color(0xFFFDECEC));
    expect(rowColor(tester, 4), const Color(0xFFFDECEC));

    expect(inGrid('Fix'), findsNWidgets(5));

    // Delete in the grid only on the row whose Shade is not in JDE.
    expect(inGrid('Delete'), findsOneWidget);

    expect(yesEnabled(tester), isFalse);
  });

  testWidgets('a combination warning alone does not block Yes',
      (tester) async {
    await pumpDialog(tester, withBlocking: false);

    expect(find.text('Upload all 2 lines? (1 with warnings)'), findsOneWidget);
    expect(find.text('Warnings (1)'), findsOneWidget);
    expect(inGrid('Delete'), findsNothing);
    expect(yesEnabled(tester), isTrue);
  });

  testWidgets('Delete in the grid removes a not-in-JDE row and renumbers',
      (tester) async {
    final rows = await pumpDialog(tester);

    final delete = inGrid('Delete');

    await tester.ensureVisible(delete);
    await tester.pumpAndSettle();
    await tester.tap(delete);
    await tester.pumpAndSettle();

    expect(rows.map((row) => row.rowNumber), [1, 2, 3, 5]);
    expect(inGrid('Delete'), findsNothing);

    // The missing-Shade row is now shown as row 4.
    expect(find.textContaining('Row 4 · '), findsOneWidget);
  });

  testWidgets(
      'a yellow Quantity row: fixed and deleted only from its Fix modal',
      (tester) async {
    final rows = await pumpDialog(tester);

    await tester.tap(find.textContaining('Row 3 · '));
    await tester.pumpAndSettle();

    expect(find.text('Fix row 3'), findsOneWidget);
    expect(inFixModal('Missing Quantity'), findsOneWidget);
    expect(inFixModal('Save & validate'), findsOneWidget);

    await tester.tap(inFixModal('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Fix row 3'), findsNothing);
    expect(rows.map((row) => row.rowNumber), [1, 2, 4, 5]);
  });

  testWidgets(
      'a red row with a bad Quantity too: the Article / Shade error shows '
      'first, the Quantity under it', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final row = ExcelImportRow(rowNumber: 1, line: withQuantity('12.5'))
      ..error = 'Article A100 and Shade S1 not found in JDE'
      ..isNotFoundInJde = true;

    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: ExcelImportDialog(rows: [row], onRevalidate: () async {}),
        ),
      ),
    );

    const error = 'Article A100 and Shade S1 not found in JDE';
    const quantity = 'Quantity must be a whole number, no decimals (is "12.5")';

    // The issues list: one red entry naming both, error first.
    expect(find.text('Errors (1)'), findsOneWidget);
    expect(find.textContaining('$error; $quantity'), findsOneWidget);

    // The grid shows the Quantity as written.
    expect(inGrid('12.5'), findsOneWidget);

    await tester.tap(find.textContaining('Row 1 · '));
    await tester.pumpAndSettle();

    final errorBox = inFixModal(error);
    final quantityBox = inFixModal(quantity);

    expect(errorBox, findsOneWidget);
    expect(quantityBox, findsOneWidget);
    expect(
      tester.getTopLeft(errorBox).dy,
      lessThan(tester.getTopLeft(quantityBox).dy),
    );
  });

  testWidgets('a yellow combination row is deleted from its Fix modal',
      (tester) async {
    final rows = await pumpDialog(tester);

    await tester.tap(find.textContaining('Row 2 · '));
    await tester.pumpAndSettle();

    expect(
      inFixModal('Article / Shade combination not found in JDE'),
      findsOneWidget,
    );

    await tester.tap(inFixModal('Delete'));
    await tester.pumpAndSettle();

    expect(rows.map((row) => row.line.article), isNot(contains('A200')));
  });

  testWidgets(
      'Save & validate re-checks the line; a random Article and Shade stay '
      'red in the modal, then a fixed line closes it', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final row = ExcelImportRow(rowNumber: 1, line: _line(shade: ''))
      ..error = 'Missing Shade';

    final rows = [row];

    var validations = 0;

    // Stands in for the controller's validation: the Article and the Shade
    // each checked on their own in JDE, where only A100 / S1 exist.
    Future<void> revalidate() async {
      validations++;

      final missing = [
        if (row.line.article != 'A100') 'Article ${row.line.article}',
        if (row.line.shade != 'S1') 'Shade ${row.line.shade}',
      ];

      row
        ..error = missing.isEmpty
            ? null
            : '${missing.join(' and ')} not found in JDE'
        ..isNotFoundInJde = missing.isNotEmpty;
    }

    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: ExcelImportDialog(rows: rows, onRevalidate: revalidate),
        ),
      ),
    );

    await tester.tap(find.textContaining('Row 1 · '));
    await tester.pumpAndSettle();

    final fields = find.descendant(
      of: find.byType(AlertDialog).last,
      matching: find.byType(TextFormField),
    );

    // Article and Shade are the 5th and 6th fields.
    await tester.enterText(fields.at(4), 'QQ1');
    await tester.enterText(fields.at(5), 'RR2');
    await tester.tap(inFixModal('Save & validate'));
    await tester.pumpAndSettle();

    expect(validations, 1);
    expect(find.text('Fix row 1'), findsOneWidget);
    expect(
      inFixModal('Article QQ1 and Shade RR2 not found in JDE'),
      findsOneWidget,
    );

    await tester.enterText(fields.at(4), 'A100');
    await tester.enterText(fields.at(5), 'S1');
    await tester.tap(inFixModal('Save & validate'));
    await tester.pumpAndSettle();

    expect(validations, 2);
    expect(find.text('Fix row 1'), findsNothing);
    expect(row.canUpload, isTrue);
  });

  testWidgets(
      'a failed Save & validate keeps the row as it was: Cancel shows the '
      'old values, not the wrong ones', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // Valid Article and Shade, a Quantity to fix (yellow).
    final row = ExcelImportRow(rowNumber: 1, line: _line(quantity: 0));

    // Stands in for the controller: only A100 / S1 exist in JDE.
    Future<void> revalidate() async {
      final missing = [
        if (row.line.article != 'A100') 'Article ${row.line.article}',
        if (row.line.shade != 'S1') 'Shade ${row.line.shade}',
      ];

      row
        ..error = missing.isEmpty
            ? null
            : '${missing.join(' and ')} not found in JDE'
        ..isNotFoundInJde = missing.isNotEmpty;
    }

    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: ExcelImportDialog(rows: [row], onRevalidate: revalidate),
        ),
      ),
    );

    await tester.tap(find.textContaining('Row 1 · '));
    await tester.pumpAndSettle();

    final fields = find.descendant(
      of: find.byType(AlertDialog).last,
      matching: find.byType(TextFormField),
    );

    // A random Shade and a decimal Quantity.
    await tester.enterText(fields.at(5), 'ZZ9');
    await tester.enterText(fields.at(8), '2.5');
    await tester.tap(inFixModal('Save & validate'));
    await tester.pumpAndSettle();

    // The modal stays open with the edited values' problems, Shade first.
    expect(find.text('Fix row 1'), findsOneWidget);
    expect(inFixModal('Shade ZZ9 not found in JDE'), findsOneWidget);
    expect(
      inFixModal('Quantity must be a whole number, no decimals (is "2.5")'),
      findsOneWidget,
    );

    // The row itself is unchanged: its old Shade, Quantity and status.
    expect(row.line.shade, 'S1');
    expect(row.line.quantityText, '');
    expect(row.isValid, isTrue);
    expect(row.problems, ['Missing Quantity']);

    await tester.tap(inFixModal('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Fix row 1'), findsNothing);

    // The upload list shows the old values, not ZZ9 / 2.5.
    expect(inGrid('S1'), findsOneWidget);
    expect(inGrid('ZZ9'), findsNothing);
    expect(inGrid('2.5'), findsNothing);
    expect(find.textContaining('Missing Quantity'), findsOneWidget);
    expect(find.textContaining('ZZ9'), findsNothing);
  });

  /// The dialog as the controller shows it: TC Required offered when the
  /// uploaded sheet is all "R" articles.
  Future<void> pumpTcDialog(
    WidgetTester tester, {
    required List<ExcelImportRow> rows,
    Future<void> Function()? onRevalidate,
  }) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: ExcelImportDialog(
            rows: rows,
            offersTc: offersTcRequired(rows),
            onRevalidate: onRevalidate ?? () async {},
          ),
        ),
      ),
    );
  }

  /// Every line an "R" article.
  List<ExcelImportRow> allRRows() => [
        ExcelImportRow(rowNumber: 1, line: _line(article: 'RS826')),
        ExcelImportRow(rowNumber: 2, line: _line(article: 'HR8933')),
        ExcelImportRow(rowNumber: 3, line: _line(article: 'MAR235')),
      ];

  /// "R" articles mixed with a normal one (A100).
  List<ExcelImportRow> mixedRows() => [
        ExcelImportRow(rowNumber: 1, line: _line(article: 'RS826')),
        ExcelImportRow(rowNumber: 2, line: _line(article: 'A100')),
        ExcelImportRow(rowNumber: 3, line: _line(article: 'MAR235')),
      ];

  List<bool> tcLines(List<ExcelImportRow> rows) =>
      rows.map((row) => row.isTcLineIn(rows)).toList();

  Finder allCheckboxes() => find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(Checkbox),
      );

  test('TC Required is offered only when every line is an "R" article', () {
    expect(offersTcRequired(allRRows()), isTrue);
    expect(offersTcRequired(mixedRows()), isFalse);
    expect(offersTcRequired(const []), isFalse);

    // Ticked lines of a mixed sheet still go in as normal lines.
    final mixed = mixedRows()..forEach((row) => row.tcRequired = true);

    expect(tcLines(mixed), [false, false, false]);
  });

  testWidgets(
      'every line an "R" article: one box ticks or unticks all lines, no '
      'tick per line', (tester) async {
    final rows = allRRows();

    await pumpTcDialog(tester, rows: rows);

    expect(find.text('Tick if TC Required'), findsOneWidget);
    expect(find.text('(3 "R" article lines)'), findsOneWidget);
    expect(allCheckboxes(), findsOneWidget);
    expect(
      find.descendant(of: find.byType(DataTable), matching: find.text('TC')),
      findsNothing,
    );
    expect(tcLines(rows), [false, false, false]);

    await tester.tap(find.text('Tick if TC Required'));
    await tester.pump();

    expect(tcLines(rows), [true, true, true]);
    expect(tester.widget<Checkbox>(allCheckboxes()).value, isTrue);

    await tester.tap(find.text('Tick if TC Required'));
    await tester.pump();

    expect(tcLines(rows), [false, false, false]);
    expect(tester.widget<Checkbox>(allCheckboxes()).value, isFalse);
  });

  testWidgets('a sheet mixing "R" and normal articles: no TC box, normal order',
      (tester) async {
    final rows = mixedRows();

    await pumpTcDialog(tester, rows: rows);

    expect(find.text('Tick if TC Required'), findsNothing);
    expect(allCheckboxes(), findsNothing);
    expect(tcLines(rows), [false, false, false]);
  });

  testWidgets(
      'a mixed sheet stays a normal order after its normal line is deleted',
      (tester) async {
    final rows = mixedRows();

    // A100 not in JDE: Delete in the grid.
    rows[1]
      ..error = 'Article A100 not found in JDE'
      ..isNotFoundInJde = true;

    await pumpTcDialog(tester, rows: rows);

    final delete = find.descendant(
      of: find.byType(DataTable),
      matching: find.text('Delete'),
    );

    await tester.ensureVisible(delete);
    await tester.pumpAndSettle();
    await tester.tap(delete);
    await tester.pumpAndSettle();

    // RS826 and MAR235 left, but the uploaded sheet was mixed.
    expect(rows.length, 2);
    expect(find.text('Tick if TC Required'), findsNothing);
  });

  testWidgets('no "R" article: no TC Required box', (tester) async {
    await pumpTcDialog(
      tester,
      rows: [ExcelImportRow(rowNumber: 1, line: _line(article: 'A100'))],
    );

    expect(find.text('Tick if TC Required'), findsNothing);
    expect(allCheckboxes(), findsNothing);
  });

  testWidgets('a TC Required order: the box starts ticked and can be unticked',
      (tester) async {
    // As the controller sets them for a TC order.
    final rows = allRRows()..forEach((row) => row.tcRequired = true);

    await pumpTcDialog(tester, rows: rows);

    expect(tester.widget<Checkbox>(allCheckboxes()).value, isTrue);

    await tester.tap(find.text('Tick if TC Required'));
    await tester.pump();

    expect(tcLines(rows), [false, false, false]);
  });

  Future<Finder> openFix(WidgetTester tester, int index) async {
    final fix = find
        .descendant(of: find.byType(DataTable), matching: find.text('Fix'))
        .at(index);

    await tester.ensureVisible(fix);
    await tester.pumpAndSettle();
    await tester.tap(fix);
    await tester.pumpAndSettle();

    return find.descendant(
      of: find.byType(AlertDialog).last,
      matching: find.byType(TextFormField),
    );
  }

  testWidgets(
      'TC Required ticked: Fix replaces an "R" article only with an "R" '
      'article', (tester) async {
    final rows = allRRows();

    var validations = 0;

    await pumpTcDialog(
      tester,
      rows: rows,
      onRevalidate: () async => validations++,
    );

    await tester.tap(find.text('Tick if TC Required'));
    await tester.pump();

    var fields = await openFix(tester, 0);

    expect(inFixModal('TC Required: "R" articles only'), findsOneWidget);

    // Article is the 5th field: a normal article is refused.
    await tester.enterText(fields.at(4), 'A100');
    await tester.tap(inFixModal('Save & validate'));
    await tester.pumpAndSettle();

    expect(validations, 0);
    expect(find.text('Fix row 1'), findsOneWidget);
    expect(
      find.textContaining('can only be replaced with an "R" article'),
      findsOneWidget,
    );
    expect(rows.first.line.article, 'RS826');

    // Another "R" article is saved.
    fields = find.descendant(
      of: find.byType(AlertDialog).last,
      matching: find.byType(TextFormField),
    );

    await tester.enterText(fields.at(4), 'RS900');
    await tester.tap(inFixModal('Save & validate'));
    await tester.pumpAndSettle();

    expect(validations, 1);
    expect(find.text('Fix row 1'), findsNothing);
    expect(rows.first.line.article, 'RS900');
    expect(tcLines(rows), [true, true, true]);
  });

  testWidgets(
      'TC Required unticked: Fix may change to a normal article, and the '
      'order becomes a normal one', (tester) async {
    final rows = allRRows();

    await pumpTcDialog(tester, rows: rows);

    final fields = await openFix(tester, 0);

    expect(inFixModal('TC Required: "R" articles only'), findsNothing);

    await tester.enterText(fields.at(4), 'A100');
    await tester.tap(inFixModal('Save & validate'));
    await tester.pumpAndSettle();

    expect(rows.first.line.article, 'A100');
    expect(find.text('Tick if TC Required'), findsNothing);
    expect(tcLines(rows), [false, false, false]);
  });
}
