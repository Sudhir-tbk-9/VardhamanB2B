import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vardhman_b2b/constants.dart';

/// Order list table that builds only the rows of the page on screen: a
/// customer can have well over a thousand orders, and building them all at
/// once froze the screen.
class PagedOrdersTable extends StatefulWidget {
  final double minWidth;

  final List<DataColumn> columns;

  final int Function() rowCount;

  final DataRow Function(int index) rowBuilder;

  /// Redraws the page on screen when any of these change (rows are read
  /// through [rowBuilder], outside any Obx).
  final List<RxInterface> refreshOn;

  /// Goes back to the first page when any of these change, e.g. the filtered
  /// orders, whose old page may no longer exist.
  final List<RxInterface> firstPageOn;

  const PagedOrdersTable({
    super.key,
    required this.minWidth,
    required this.columns,
    required this.rowCount,
    required this.rowBuilder,
    required this.refreshOn,
    required this.firstPageOn,
  });

  @override
  State<PagedOrdersTable> createState() => _PagedOrdersTableState();
}

class _PagedOrdersTableState extends State<PagedOrdersTable> {
  late final _source = _RowsSource(this);

  final _paginatorController = PaginatorController();

  final _workers = <Worker>[];

  int _rowsPerPage = 50;

  @override
  void initState() {
    super.initState();

    for (final rx in widget.refreshOn) {
      _workers.add(ever(rx, (_) => _source.refresh()));
    }

    for (final rx in widget.firstPageOn) {
      _workers.add(
        ever(rx, (_) {
          if (_paginatorController.isAttached) {
            _paginatorController.goToFirstPage();
          }
        }),
      );
    }
  }

  @override
  void dispose() {
    for (final worker in _workers) {
      worker.dispose();
    }

    _paginatorController.dispose();

    _source.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PaginatedDataTable2(
      source: _source,
      controller: _paginatorController,
      wrapInCard: false,
      renderEmptyRowsInTheEnd: false,
      showFirstLastButtons: true,
      rowsPerPage: _rowsPerPage,
      availableRowsPerPage: const [25, 50, 100],
      onRowsPerPageChanged: (rowsPerPage) {
        if (rowsPerPage != null) {
          setState(() => _rowsPerPage = rowsPerPage);
        }
      },
      minWidth: widget.minWidth,
      isHorizontalScrollBarVisible: true,
      isVerticalScrollBarVisible: true,
      columnSpacing: 16,
      horizontalMargin: 16,
      headingRowHeight: 40,
      dataRowHeight: 40,
      headingRowColor: WidgetStatePropertyAll(Colors.grey),
      headingTextStyle: TextStyle(
        fontSize: 13,
        color: Colors.white,
        fontWeight: FontWeight.w500,
      ),
      dataTextStyle: TextStyle(
        fontSize: 13,
        color: VardhmanColors.darkGrey,
      ),
      border: TableBorder.symmetric(
        inside: BorderSide(
          width: 0.1,
          color: VardhmanColors.darkGrey,
        ),
      ),
      showCheckboxColumn: false,
      columns: widget.columns,
    );
  }
}

class _RowsSource extends DataTableSource {
  final _PagedOrdersTableState _state;

  _RowsSource(this._state);

  void refresh() => notifyListeners();

  @override
  DataRow? getRow(int index) =>
      index < rowCount ? _state.widget.rowBuilder(index) : null;

  @override
  int get rowCount => _state.widget.rowCount();

  @override
  bool get isRowCountApproximate => false;

  @override
  int get selectedRowCount => 0;
}
