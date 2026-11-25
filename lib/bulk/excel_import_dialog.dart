import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vardhman_b2b/bulk/excel_line.dart';
import 'package:vardhman_b2b/common/primary_button.dart';
import 'package:vardhman_b2b/common/secondary_button.dart';
import 'package:vardhman_b2b/constants.dart';
import 'package:vardhman_b2b/orders/direct_delivery_tc.dart';
import 'package:vardhman_b2b/common/table_header.dart';

/// Light row shades, so the dark text stays readable on them, and the
/// stronger colours of the status text.
abstract final class _Status {
  static const validFill = Color(0xFFEAF6EC);

  static const validText = Color(0xFF1E7B34);

  static const errorFill = Color(0xFFFDECEC);

  static const errorBorder = Color(0xFFE57373);

  static const errorText = Color(0xFFC62828);

  static const warningFill = Color(0xFFFFF8E1);

  static const warningBorder = Color(0xFFFFCA28);

  static const warningText = Color(0xFF8D6E00);
}

/// Shows every imported line in a grid, numbered 1, 2, 3… in display order:
/// valid lines in green, lines with a warning in yellow (a Quantity to fix,
/// or the Article and Shade in JDE but not together), lines with an error
/// in red (no Article or Shade, the Article or the Shade not in JDE, …).
/// Every line can be fixed (and re-validated against JDE via
/// [onRevalidate]) and deleted from its Fix modal; only the red lines whose
/// Article or Shade is not in JDE have a Delete button in the grid too. Yes
/// uploads the green and yellow lines, and is enabled once no red line and
/// no Quantity to fix is left.
///
/// TC Required: each "R" article line has its own tick in the TC column
/// ([ExcelImportRow.tcRequired]); ticked, it is uploaded as a TC line
/// (direct delivery, "TC Required"). "Tick if TC Required" in the header
/// (shown when a line has an "R" article) ticks or unticks all of them at
/// once. Lines without an "R" are always normal lines.
///
/// Pops with `true` for Yes (insert the valid lines) and `false` for No.
class ExcelImportDialog extends StatefulWidget {
  final List<ExcelImportRow> rows;

  /// Re-runs the validation on every line not yet found valid.
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

  final _issuesScrollController = ScrollController();

  List<ExcelImportRow> get _rArticleRows => widget.rows
      .where((row) => DirectDeliveryTc.isRArticle(row.line.article))
      .toList();

  /// The header box: ticked when every "R" line is, a dash when some are.
  bool? get _allTcState {
    final rRows = _rArticleRows;

    final tickedCount = rRows.where((row) => row.tcRequired).length;

    return tickedCount == 0
        ? false
        : tickedCount == rRows.length
            ? true
            : null;
  }

  void _logTc() => debugPrint(
        '[BULK IMPORT] TC Required: '
        '${widget.rows.where((row) => row.isTcLine).length} of '
        '${_rArticleRows.length} "R" article line(s) ticked as TC lines, the '
        'others as normal lines',
      );

  /// Header box: ticks every "R" line, or unticks them all when all are.
  void _toggleAllTc() {
    final tick = _allTcState != true;

    setState(() {
      for (final row in _rArticleRows) {
        row.tcRequired = tick;
      }
    });

    _logTc();
  }

  void _toggleTc(ExcelImportRow row) {
    setState(() => row.tcRequired = !row.tcRequired);

    _logTc();
  }

  @override
  void dispose() {
    _gridScrollController.dispose();

    _issuesScrollController.dispose();

    super.dispose();
  }

  /// The row's number as shown: its position in the list, from 1.
  int _numberOf(ExcelImportRow row) => widget.rows.indexOf(row) + 1;

  Future<void> _fix(ExcelImportRow row) async {
    await Get.dialog<void>(
      _FixLineDialog(
        row: row,
        number: _numberOf(row),
        onRevalidate: widget.onRevalidate,
        onDelete: () => widget.rows.remove(row),
      ),
      barrierDismissible: false,
    );

    if (mounted) {
      setState(() {});
    }
  }

  void _delete(ExcelImportRow row) {
    setState(() => widget.rows.remove(row));

    debugPrint('[BULK IMPORT] Row ${row.rowNumber} deleted from the import');
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.rows.length;

    final errorRows = widget.rows.where((row) => !row.isValid).toList();

    final warningRows = widget.rows.where((row) => row.hasWarning).toList();

    // Red lines, and yellow lines with a Quantity to fix.
    final blockingRows = widget.rows.where((row) => !row.canUpload).toList();

    final validCount = total - blockingRows.length;

    final quantityCount = blockingRows.length - errorRows.length;

    final String title;

    if (total == 0) {
      title = 'No lines left to upload';
    } else if (blockingRows.isNotEmpty) {
      final what = [
        if (errorRows.isNotEmpty) 'the red lines',
        if (quantityCount > 0) 'the quantity of the yellow lines',
      ].join(' and ');

      title = '${blockingRows.length} of $total lines need fixing. Fix '
          '$what to upload the other $validCount.';
    } else {
      title = '${total == 1 ? 'Upload the line?' : 'Upload all $total lines?'}'
          '${warningRows.isEmpty ? '' : ' (${warningRows.length} with warnings)'}';
    }

    final rArticleCount = _rArticleRows.length;

    return AlertDialog(
      title: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          if (rArticleCount > 0) ...[
            const SizedBox(width: 16),
            _TcRequiredBox(
              value: _allTcState,
              rArticleCount: rArticleCount,
              onTap: _toggleAllTc,
            ),
          ],
        ],
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
                    child: _LinesGrid(
                      rows: widget.rows,
                      onToggleTc: _toggleTc,
                      onFix: _fix,
                      onDelete: _delete,
                    ),
                  ),
                ),
              ),
            ),
            if (errorRows.isNotEmpty || warningRows.isNotEmpty) ...[
              const SizedBox(height: 12),
              _IssuesPanel(
                errorRows: errorRows,
                warningRows: warningRows,
                numberOf: _numberOf,
                scrollController: _issuesScrollController,
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
        // Disabled while a red line or a Quantity to fix is left; other
        // yellow lines do not block it.
        PrimaryButton(
          wait: false,
          text: 'Yes',
          onPressed: blockingRows.isNotEmpty || validCount == 0
              ? null
              : () async {
                  Get.back(result: true);
                },
        ),
      ],
    );
  }
}

/// "Tick if TC Required" in the import header: ticks or unticks every "R"
/// article line at once; a dash when only some are ticked.
class _TcRequiredBox extends StatelessWidget {
  final bool? value;

  final int rArticleCount;

  final VoidCallback onTap;

  const _TcRequiredBox({
    required this.value,
    required this.rArticleCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Ticks or unticks all $rArticleCount line(s) with an "R" '
          'article; each can also be ticked on its own in the TC column. '
          'Ticked lines are uploaded as TC Required (direct delivery), the '
          'others as normal lines',
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(2, 2, 8, 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Checkbox(
                value: value,
                tristate: true,
                activeColor: VardhmanColors.red,
                visualDensity: VisualDensity.compact,
                onChanged: (_) => onTap(),
              ),
              Text(
                'Tick if TC Required',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: VardhmanColors.darkGrey,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '($rArticleCount "R" article line${rArticleCount == 1 ? '' : 's'})',
                style: TextStyle(
                  fontSize: 12,
                  color: VardhmanColors.darkGrey.withAlpha(170),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LinesGrid extends StatelessWidget {
  final List<ExcelImportRow> rows;

  /// The row's own TC tick ("R" articles only).
  final void Function(ExcelImportRow row) onToggleTc;

  final void Function(ExcelImportRow row) onFix;

  final void Function(ExcelImportRow row) onDelete;

  const _LinesGrid({
    required this.rows,
    required this.onToggleTc,
    required this.onFix,
    required this.onDelete,
  });

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
            headingRowColor: TableHeader.color,
            columns: [
              column('Row', numeric: true),
              column('PO No.'),
              column('Merchandiser'),
              column('Buyer'),
              column('Light Source'),
              column('Article'),
              column('TC'),
              column('Shade'),
              column('UOM'),
              column('Style No.'),
              column('Qty', numeric: true),
              column('Unit Price', numeric: true),
              column('Status'),
            ],
            rows: rows.indexed.map(
              ((int, ExcelImportRow) entry) {
                final (index, row) = entry;

                final isValid = row.isValid;

                final hasWarning = row.hasWarning;

                final statusColor = !isValid
                    ? _Status.errorText
                    : hasWarning
                        ? _Status.warningText
                        : _Status.validText;

                // Dark text on the light shades, for readability.
                final textStyle = TextStyle(
                  fontSize: 12,
                  color: VardhmanColors.darkGrey,
                );

                DataCell cell(String text) =>
                    DataCell(Text(text, style: textStyle));

                return DataRow(
                  color: WidgetStatePropertyAll(
                    !isValid
                        ? _Status.errorFill
                        : hasWarning
                            ? _Status.warningFill
                            : _Status.validFill,
                  ),
                  cells: [
                    // 1, 2, 3… in display order, also after a delete.
                    cell('${index + 1}'),
                    cell(row.line.poNumber),
                    cell(row.line.merchandiser),
                    cell(row.line.buyer),
                    cell(row.line.lightSources),
                    cell(row.line.article),
                    // The line's own TC Required tick, "R" articles only;
                    // other lines are always normal lines.
                    DirectDeliveryTc.isRArticle(row.line.article)
                        ? DataCell(
                            Tooltip(
                              message: 'TC Required for this line',
                              child: Checkbox(
                                value: row.tcRequired,
                                activeColor: VardhmanColors.red,
                                visualDensity: VisualDensity.compact,
                                onChanged: (_) => onToggleTc(row),
                              ),
                            ),
                          )
                        : cell(''),
                    cell(row.line.shade),
                    cell(row.line.uom),
                    cell(row.line.styleNo),
                    // As written, so a wrong one ("12.5", "-5", "12a")
                    // shows what is to fix.
                    cell(row.line.quantityText),
                    cell(row.unitPrice?.toStringAsFixed(2) ?? ''),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // An icon only, so the buttons stay in view; the
                          // row's shade shows the status too.
                          Tooltip(
                            // Every problem, Article / Shade first.
                            message: row.problems.isEmpty
                                ? 'Valid'
                                : row.problems.join('\n'),
                            child: Icon(
                              !isValid
                                  ? Icons.error_outline
                                  : hasWarning
                                      ? Icons.warning_amber_rounded
                                      : Icons.check_circle,
                              size: 16,
                              color: statusColor,
                            ),
                          ),
                          const SizedBox(width: 2),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: isValid
                                  ? VardhmanColors.darkGrey
                                  : _Status.errorText,
                              visualDensity: VisualDensity.compact,
                            ),
                            icon: const Icon(Icons.edit, size: 16),
                            label: const Text('Fix'),
                            onPressed: () => onFix(row),
                          ),
                          // Only for an Article or Shade not in JDE; any
                          // other line is deleted from its Fix modal.
                          if (row.isNotFoundInJde)
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: VardhmanColors.darkGrey,
                                visualDensity: VisualDensity.compact,
                              ),
                              icon:
                                  const Icon(Icons.delete_outline, size: 16),
                              label: const Text('Delete'),
                              onPressed: () => onDelete(row),
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

/// Lists the rows with an error (red) and those with a warning (yellow);
/// tapping one opens its Fix modal.
class _IssuesPanel extends StatelessWidget {
  final List<ExcelImportRow> errorRows;

  final List<ExcelImportRow> warningRows;

  final int Function(ExcelImportRow row) numberOf;

  final ScrollController scrollController;

  final void Function(ExcelImportRow row) onFix;

  const _IssuesPanel({
    required this.errorRows,
    required this.warningRows,
    required this.numberOf,
    required this.scrollController,
    required this.onFix,
  });

  Widget _issue(ExcelImportRow row, {required bool isError}) {
    final color = isError ? _Status.errorText : _Status.warningText;

    final itemNumber = row.line.itemNumber.trim();

    return InkWell(
      onTap: () => onFix(row),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        child: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.warning_amber_rounded,
              size: 14,
              color: color,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                // Every problem of the row, Article / Shade first, then
                // Quantity.
                'Row ${numberOf(row)} · ${itemNumber.isEmpty ? '-' : itemNumber}'
                ' — ${row.problems.join('; ')}',
                style: TextStyle(fontSize: 12, color: color),
              ),
            ),
            Text(
              'Fix',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
                decoration: TextDecoration.underline,
                decorationColor: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasErrors = errorRows.isNotEmpty;

    return Container(
      constraints: const BoxConstraints(maxHeight: 150),
      decoration: BoxDecoration(
        color: hasErrors ? _Status.errorFill : _Status.warningFill,
        border: Border.all(
          color: hasErrors ? _Status.errorBorder : _Status.warningBorder,
          width: 0.8,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
            child: Text(
              [
                if (hasErrors) 'Errors (${errorRows.length})',
                if (warningRows.isNotEmpty)
                  'Warnings (${warningRows.length})',
              ].join(' · '),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: hasErrors ? _Status.errorText : _Status.warningText,
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
                children: [
                  for (final row in errorRows) _issue(row, isError: true),
                  for (final row in warningRows) _issue(row, isError: false),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// What a failed Save & validate found for the Fix modal's edited values.
class _DraftProblems {
  final String? error;

  final String? warning;

  final String? quantityProblem;

  const _DraftProblems({this.error, this.warning, this.quantityProblem});

  List<String> get all =>
      [error, warning, quantityProblem].whereType<String>().toList();
}

/// A row's values and check results, to put back after a failed Save &
/// validate.
class _RowState {
  final ExcelLine line;

  final String? error;

  final bool isNotFoundInJde;

  final String? warning;

  final double? unitPrice;

  final bool isChecked;

  final bool uomLookedUp;

  _RowState.of(ExcelImportRow row)
      : line = row.line,
        error = row.error,
        isNotFoundInJde = row.isNotFoundInJde,
        warning = row.warning,
        unitPrice = row.unitPrice,
        isChecked = row.isChecked,
        uomLookedUp = row.uomLookedUp;

  void restore(ExcelImportRow row) {
    row
      ..line = line
      ..error = error
      ..isNotFoundInJde = isNotFoundInJde
      ..warning = warning
      ..unitPrice = unitPrice
      ..isChecked = isChecked
      ..uomLookedUp = uomLookedUp;
  }
}

/// Edits one line. Save writes the edits to the line and re-validates it
/// against JDE, the Article and the Shade each on its own when they are not
/// found together. It closes once the line can be uploaded (a warning other
/// than a Quantity one does not keep it open), otherwise it shows the new
/// error or warning so the user can keep fixing. Delete removes the line
/// from the upload: the only Delete for most lines (see [ExcelImportDialog]).
class _FixLineDialog extends StatefulWidget {
  final ExcelImportRow row;

  /// The row's number as shown in the list.
  final int number;

  final Future<void> Function() onRevalidate;

  final VoidCallback onDelete;

  const _FixLineDialog({
    required this.row,
    required this.number,
    required this.onRevalidate,
    required this.onDelete,
  });

  @override
  State<_FixLineDialog> createState() => _FixLineDialogState();
}

class _FixLineDialogState extends State<_FixLineDialog> {
  late ExcelLine _draft = widget.row.line;

  /// The problems found for the edited values by the last Save & validate
  /// that failed; null until then (the row's own problems are shown). The
  /// row itself keeps its earlier values: Cancel leaves it unchanged.
  _DraftProblems? _draftProblems;

  Widget _field({
    required String label,
    required String initialValue,
    required ValueChanged<String> onChanged,
    bool isNumber = false,
    bool upperCase = false,
    String? helperText,
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
            helperText: helperText,
            border: const OutlineInputBorder(),
          ),
        ),
      ),
    );
  }

  Widget _message(String text, {required bool isError}) {
    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isError ? _Status.errorFill : _Status.warningFill,
        border: Border.all(
          color: isError ? _Status.errorBorder : _Status.warningBorder,
          width: 0.8,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          color: isError ? _Status.errorText : _Status.warningText,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // All of the line's problems, in order: the red Article / Shade error
    // first, then the yellow JDE note, then the Quantity. After a failed
    // Save & validate, those of the edited values.
    final draftProblems = _draftProblems;

    final error =
        draftProblems == null ? widget.row.error : draftProblems.error;

    final warning =
        draftProblems == null ? widget.row.warning : draftProblems.warning;

    final quantityProblem = draftProblems == null
        ? widget.row.line.quantityProblem
        : draftProblems.quantityProblem;

    return AlertDialog(
      title: Text(
        'Fix row ${widget.number}',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: 760,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (error != null) _message(error, isError: true),
            if (warning != null) _message(warning, isError: false),
            if (quantityProblem != null)
              _message(quantityProblem, isError: false),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _field(
                  label: 'Article',
                  upperCase: true,
                  initialValue: _draft.article,
                  onChanged: (value) =>
                      _draft = _draft.copyWith(article: value.trim()),
                ),
                _field(
                  label: 'Shade',
                  upperCase: true,
                  initialValue: _draft.shade,
                  onChanged: (value) =>
                      _draft = _draft.copyWith(shade: value.trim()),
                ),
                // Looked up from the Article and Shade; entered here only
                // when JDE has several.
                _field(
                  label: 'UOM',
                  upperCase: true,
                  helperText: 'Empty: from Article + Shade',
                  initialValue: _draft.uom,
                  onChanged: (value) =>
                      _draft = _draft.copyWith(uom: value.trim()),
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
                  initialValue: _draft.quantityText,
                  onChanged: (value) => _draft = _draft.copyWith(
                    quantity: ExcelLine.parseQuantity(value),
                    quantityText: value.trim(),
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
        SecondaryButton(
          wait: false,
          text: 'Delete',
          iconData: Icons.delete_outline,
          onPressed: () async {
            widget.onDelete();

            Get.back();
          },
        ),
        PrimaryButton(
          text: 'Save & validate',
          onPressed: () async {
            final row = widget.row;

            // The row as it was: put back when the edited values fail, so
            // a wrong Shade (or anything else) typed here never reaches the
            // upload list, also after Cancel.
            final saved = _RowState.of(row);

            // A UOM typed here is kept; an unchanged looked-up one is
            // looked up again for the (maybe fixed) Article and Shade.
            if (_draft.uom != row.line.uom) {
              row.uomLookedUp = false;
            }

            row
              ..line = _draft
              ..isChecked = false;

            await widget.onRevalidate();

            if (row.canUpload) {
              debugPrint('[BULK IMPORT] Fix row ${widget.number}: saved');

              if (mounted) {
                Get.back();
              }

              return;
            }

            final problems = _DraftProblems(
              error: row.error,
              warning: row.warning,
              quantityProblem: row.line.quantityProblem,
            );

            saved.restore(row);

            debugPrint(
              '[BULK IMPORT] Fix row ${widget.number}: not saved, the row '
              'keeps its values (${problems.all.join('; ')})',
            );

            if (mounted) {
              setState(() => _draftProblems = problems);
            }
          },
        ),
      ],
    );
  }
}
