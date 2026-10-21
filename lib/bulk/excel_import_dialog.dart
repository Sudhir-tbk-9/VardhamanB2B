import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vardhman_b2b/bulk/excel_line.dart';
import 'package:vardhman_b2b/common/primary_button.dart';
import 'package:vardhman_b2b/common/secondary_button.dart';
import 'package:vardhman_b2b/constants.dart';

/// Shows every imported line in a grid with error lines highlighted in red,
/// lists the errors in a panel, lets the user fix an error line (which is
/// re-validated against JDE via [onRevalidate]) and asks whether to proceed
/// with only the valid lines.
///
/// Pops with `true` for Yes (insert the valid lines) and `false` for No.
class ExcelImportDialog extends StatefulWidget {
  final List<ExcelImportRow> rows;

  /// Re-runs the JDE validation chain on every line that is not yet valid.
  final Future<void> Function() onRevalidate;

  const ExcelImportDialog({
    super.key,
    required this.rows,
    required this.onRevalidate,
  });

  @override
  State<ExcelImportDialog> createState() => _ExcelImportDialogState();
}

class _ExcelImportDialogState extends State<ExcelImportDialog> {
  final _gridScrollController = ScrollController();

  final _errorsScrollController = ScrollController();

  @override
  void dispose() {
    _gridScrollController.dispose();

    _errorsScrollController.dispose();

    super.dispose();
  }

  Future<void> _fix(ExcelImportRow row) async {
    await Get.dialog<void>(
      _FixLineDialog(row: row, onRevalidate: widget.onRevalidate),
      barrierDismissible: false,
    );

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.rows.length;

    final errorRows = widget.rows.where((row) => !row.isValid).toList();

    final validCount = total - errorRows.length;

    return AlertDialog(
      title: Text(
        errorRows.isEmpty
            ? 'All $total lines are valid. Upload them?'
            : '${errorRows.length} of $total lines have errors. '
                'Proceed with the $validCount valid lines?',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: 1100,
        height: 540,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: VardhmanColors.dividerGrey),
                ),
                child: Scrollbar(
                  controller: _gridScrollController,
                  child: SingleChildScrollView(
                    controller: _gridScrollController,
                    child: _LinesGrid(rows: widget.rows, onFix: _fix),
                  ),
                ),
              ),
            ),
            if (errorRows.isNotEmpty) ...[
              const SizedBox(height: 12),
              _ErrorsPanel(
                errorRows: errorRows,
                scrollController: _errorsScrollController,
                onFix: _fix,
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        SecondaryButton(
          wait: false,
          text: 'No',
          onPressed: () async {
            Get.back(result: false);
          },
        ),
        PrimaryButton(
          wait: false,
          text: 'Yes',
          onPressed: validCount == 0
              ? null
              : () async {
                  Get.back(result: true);
                },
        ),
      ],
    );
  }
}

class _LinesGrid extends StatelessWidget {
  final List<ExcelImportRow> rows;

  final void Function(ExcelImportRow row) onFix;

  const _LinesGrid({required this.rows, required this.onFix});

  @override
  Widget build(BuildContext context) {
    const headerStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    );

    DataColumn column(String label, {bool numeric = false}) => DataColumn(
          numeric: numeric,
          label: Text(label, style: headerStyle),
        );

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth),
          child: DataTable(
            headingRowHeight: 36,
            dataRowMinHeight: 34,
            dataRowMaxHeight: 34,
            columnSpacing: 16,
            horizontalMargin: 10,
            headingRowColor:
                WidgetStatePropertyAll(VardhmanColors.darkGrey),
            columns: [
              column('Row', numeric: true),
              column('PO No.'),
              column('Merchandiser'),
              column('Buyer'),
              column('Light Source'),
              column('Article'),
              column('UOM'),
              column('Shade'),
              column('Style No.'),
              column('Qty', numeric: true),
              column('Unit Price', numeric: true),
              column('Status'),
            ],
            rows: rows.map(
              (row) {
                final hasError = !row.isValid;

                final textStyle = TextStyle(
                  fontSize: 12,
                  color:
                      hasError ? VardhmanColors.red : VardhmanColors.darkGrey,
                  fontWeight: hasError ? FontWeight.w600 : FontWeight.normal,
                );

                DataCell cell(String text) =>
                    DataCell(Text(text, style: textStyle));

                return DataRow(
                  color: WidgetStatePropertyAll(
                    hasError ? VardhmanColors.red.withAlpha(28) : null,
                  ),
                  cells: [
                    cell('${row.rowNumber}'),
                    cell(row.line.poNumber),
                    cell(row.line.merchandiser),
                    cell(row.line.buyer),
                    cell(row.line.lightSources),
                    cell(row.line.article),
                    cell(row.line.uom),
                    cell(row.line.shade),
                    cell(row.line.styleNo),
                    cell(row.line.quantity > 0 ? '${row.line.quantity}' : ''),
                    cell(row.unitPrice?.toStringAsFixed(2) ?? ''),
                    DataCell(
                      hasError
                          ? TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: VardhmanColors.red,
                                visualDensity: VisualDensity.compact,
                              ),
                              icon: const Icon(Icons.edit, size: 16),
                              label: const Text('Fix'),
                              onPressed: () => onFix(row),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  size: 16,
                                  color: VardhmanColors.green,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Valid',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: VardhmanColors.green,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                );
              },
            ).toList(),
          ),
        ),
      ),
    );
  }
}

class _ErrorsPanel extends StatelessWidget {
  final List<ExcelImportRow> errorRows;

  final ScrollController scrollController;

  final void Function(ExcelImportRow row) onFix;

  const _ErrorsPanel({
    required this.errorRows,
    required this.scrollController,
    required this.onFix,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 150),
      decoration: BoxDecoration(
        color: VardhmanColors.red.withAlpha(14),
        border: Border.all(color: VardhmanColors.red, width: 0.8),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
            child: Text(
              'Errors (${errorRows.length})',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: VardhmanColors.red,
              ),
            ),
          ),
          Flexible(
            child: Scrollbar(
              controller: scrollController,
              child: ListView(
                controller: scrollController,
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 6),
                children: errorRows
                    .map(
                      (row) => InkWell(
                        onTap: () => onFix(row),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 14,
                                color: VardhmanColors.red,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Row ${row.rowNumber} · '
                                  '${row.line.itemNumber.trim().isEmpty ? '-' : row.line.itemNumber.trim()}'
                                  ' — ${row.error}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: VardhmanColors.red,
                                  ),
                                ),
                              ),
                              Text(
                                'Fix',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: VardhmanColors.red,
                                  decoration: TextDecoration.underline,
                                  decorationColor: VardhmanColors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Edits one error line. Save writes the edits to the line and re-validates
/// it against JDE; the dialog closes once the line is valid, otherwise it
/// shows the new error so the user can keep fixing.
class _FixLineDialog extends StatefulWidget {
  final ExcelImportRow row;

  final Future<void> Function() onRevalidate;

  const _FixLineDialog({required this.row, required this.onRevalidate});

  @override
  State<_FixLineDialog> createState() => _FixLineDialogState();
}

class _FixLineDialogState extends State<_FixLineDialog> {
  late ExcelLine _draft = widget.row.line;

  Widget _field({
    required String label,
    required String initialValue,
    required ValueChanged<String> onChanged,
    bool isNumber = false,
    bool upperCase = false,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: TextFormField(
          initialValue: initialValue,
          onChanged: onChanged,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          inputFormatters: upperCase ? [capitalFormatter] : null,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            isDense: true,
            labelText: label,
            border: const OutlineInputBorder(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final error = widget.row.error;

    return AlertDialog(
      title: Text(
        'Fix row ${widget.row.rowNumber}',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: 760,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (error != null)
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: VardhmanColors.red.withAlpha(20),
                  border: Border.all(color: VardhmanColors.red, width: 0.8),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  error,
                  style: TextStyle(
                    fontSize: 13,
                    color: VardhmanColors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            Row(
              children: [
                _field(
                  label: 'PO Number',
                  initialValue: _draft.poNumber,
                  onChanged: (value) =>
                      _draft = _draft.copyWith(poNumber: value.trim()),
                ),
                _field(
                  label: 'Merchandiser',
                  initialValue: _draft.merchandiser,
                  onChanged: (value) =>
                      _draft = _draft.copyWith(merchandiser: value.trim()),
                ),
                _field(
                  label: 'Buyer',
                  initialValue: _draft.buyer,
                  onChanged: (value) =>
                      _draft = _draft.copyWith(buyer: value.trim()),
                ),
                _field(
                  label: 'Light Source',
                  initialValue: _draft.lightSources,
                  onChanged: (value) =>
                      _draft = _draft.copyWith(lightSources: value.trim()),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _field(
                  label: 'Article',
                  upperCase: true,
                  initialValue: _draft.article,
                  onChanged: (value) =>
                      _draft = _draft.copyWith(article: value.trim()),
                ),
                _field(
                  label: 'UOM',
                  upperCase: true,
                  initialValue: _draft.uom,
                  onChanged: (value) =>
                      _draft = _draft.copyWith(uom: value.trim()),
                ),
                _field(
                  label: 'Shade',
                  upperCase: true,
                  initialValue: _draft.shade,
                  onChanged: (value) =>
                      _draft = _draft.copyWith(shade: value.trim()),
                ),
                _field(
                  label: 'Style No.',
                  initialValue: _draft.styleNo,
                  onChanged: (value) =>
                      _draft = _draft.copyWith(styleNo: value.trim()),
                ),
                _field(
                  label: 'Quantity',
                  isNumber: true,
                  initialValue:
                      _draft.quantity > 0 ? _draft.quantity.toString() : '',
                  onChanged: (value) => _draft = _draft.copyWith(
                    quantity: ExcelLine.parseQuantity(value),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: <Widget>[
        SecondaryButton(
          wait: false,
          text: 'Cancel',
          onPressed: () async {
            Get.back();
          },
        ),
        PrimaryButton(
          text: 'Save & validate',
          onPressed: () async {
            widget.row.line = _draft;

            await widget.onRevalidate();

            if (!mounted) {
              return;
            }

            if (widget.row.isValid) {
              Get.back();
            } else {
              setState(() {});
            }
          },
        ),
      ],
    );
  }
}
