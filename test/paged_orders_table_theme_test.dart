import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vardhman_b2b/app/theme_variants.dart';
import 'package:vardhman_b2b/common/paged_orders_table.dart';
import 'package:vardhman_b2b/constants.dart';

void main() {
  tearDown(() => ThemeVariants.current = ThemeVariants.vardhmanRed);

  testWidgets('rows already built take the new theme colour', (tester) async {
    final controller = PaginatorController();

    Widget table() => MaterialApp(
          home: Scaffold(
            body: PagedOrdersTable(
              minWidth: 300,
              columns: const [DataColumn2(label: Text('Order No.'))],
              controller: controller,
              rowCount: () => 1,
              rowBuilder: (index) => DataRow(
                color: WidgetStatePropertyAll(VardhmanColors.red),
                cells: const [DataCell(Text('1001'))],
              ),
              refreshOn: const [],
              firstPageOn: const [],
            ),
          ),
        );

    Color? rowColor() => tester
        .widget<DataTable2>(find.byType(DataTable2))
        .rows
        .single
        .color
        ?.resolve({});

    await tester.pumpWidget(table());

    expect(rowColor(), ThemeVariants.vardhmanRed.primary);

    final other = ThemeVariants.all.firstWhere(
      (variant) => variant.primary != ThemeVariants.vardhmanRed.primary,
    );

    // As ThemeController.select does before rebuilding the screen.
    ThemeVariants.current = other;

    ThemeVariants.generation++;

    await tester.pumpWidget(table());

    expect(rowColor(), other.primary);

    // The table tells the pager about the change on a zero-length timer.
    await tester.pump(const Duration(milliseconds: 1));
  });
}
