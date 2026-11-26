import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vardhman_b2b/bulk/excel_line.dart';
import 'package:vardhman_b2b/common/primary_button.dart';
import 'package:vardhman_b2b/common/secondary_button.dart';
import 'package:vardhman_b2b/constants.dart';
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
/// [onRevalidate]) and deleted from its Fix modal; every red line has a
/// Delete button in the grid too. Yes
/// uploads the green and yellow lines, and is enabled once no red line and
/// no Quantity to fix is left.
///
/// TC Required, only when every uploaded line has an "R" article
/// ([offersTc]): one "Tick if TC Required" box in the header, for all lines
/// at once; ticked, every line is uploaded as a TC line (direct delivery),
/// unticked, all as normal lines. No box for a sheet of normal articles or
/// one mixing normal and "R" articles: a normal order. While it is ticked,
/// Fix only accepts an "R" article in place of an "R" article.
///
/// Duplicates, as the form refuses a line whose Article and Shade the
/// order already has: a line with the Article and Shade of an earlier line
/// is red ([markDuplicates]), and "Delete duplicates" in the header deletes
/// them all at once, the first of each staying. Fix does not save an
/// Article and Shade another line has.
///
/// Pops with `true` for Yes (insert the valid lines) and `false` for No.
class ExcelImportDialog extends StatefulWidget {
  final List<ExcelImportRow> rows;

  /// Re-runs the validation on every line not yet found valid.
  final Future<void> Function() onRevalidate;

  /// Whether the uploaded sheet offers TC Required: every line an "R"
  /// article ([offersTcRequired]), decided when it is uploaded.
  final bool offersTc;

  const ExcelImportDialog({
    super.key,
    required this.rows,
    required this.onRevalidate,
    this.offersTc = false,
  });

  @override
  State<ExcelImportDialog> createState() => _ExcelImportDialogState();
}

class _ExcelImportDialogState extends State<ExcelImportDialog> {
  final _gridScrollController = ScrollController();

  final _issuesScrollController = ScrollController();

  /// The TC box is shown: an all "R" sheet, still all "R" (an article
  /// fixed to a normal one while unticked makes it a normal order).
  bool get _showsTc => widget.offersTc && offersTcRequired(widget.rows);

  /// TC Required ticked: all lines at once, never some.
  bool get _tcTicked =>
      _showsTc && widget.rows.every((row) => row.tcRequired);

  /// Header box: ticks or unticks every line.
  void _toggleTc() {
    final tick = !_tcTicked;

    setState(() {
      for (final row in widget.rows) {
        row.tcRequired = tick;
      }
    });

    debugPrint(
      '[BULK IMPORT] TC Required ${tick ? 'ticked' : 'unticked'}: all '
      '${widget.rows.length} line(s) as ${tick ? 'TC' : 'normal'} lines',
    );
  }

  /// Whether Yes was on at the last build; null before the first.
  bool? _wasReady;

  /// The "All lines are ready" notice is shown: Yes has just come on.
  bool _showsReady = false;

  Timer? _readyTimer;

  /// Shows the notice when Yes comes on after a fix or a delete (not when
  /// the dialog opens with every line ready: its title says so), for a
  /// few seconds or until tapped.
  void _noticeReady(bool isReady) {
    final wasReady = _wasReady;

    _wasReady = isReady;

    if (wasReady == false && isReady) {
      _showsReady = true;

      _readyTimer?.cancel();

      _readyTimer = Timer(const Duration(seconds: 3), _hideReady);

      debugPrint('[BULK IMPORT] Every line can be uploaded: Yes is on');
    } else if (!isReady) {
      _showsReady = false;
    }
  }

  void _hideReady() {
    _readyTimer?.cancel();

    if (mounted && _showsReady) {
      setState(() => _showsReady = false);
    }
  }

  @override
  void dispose() {
    _readyTimer?.cancel();

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
        rArticleOnly: _tcTicked,
        duplicateRowNumberOf: (draft) => _duplicateRowNumberOf(row, draft),
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

  /// Header "Delete duplicates": every line with the Article and Shade of
  /// an earlier one; the first of each stays.
  void _deleteDuplicates() {
    final duplicates = widget.rows.where((row) => row.isDuplicate).toList();

    setState(() => widget.rows.removeWhere((row) => row.isDuplicate));

    debugPrint(
      '[BULK IMPORT] ${duplicates.length} duplicate line(s) deleted '
      '(sheet rows ${duplicates.map((row) => row.rowNumber).join(', ')})',
    );
  }

  /// The number (as shown) of another line with [draft]'s Article and
  /// Shade, which Fix does not save for [row], or null. The first of
  /// repeated lines may keep its Article and Shade: its repeats are the
  /// ones marked.
  int? _duplicateRowNumberOf(ExcelImportRow row, ExcelLine draft) {
    final isChanged = !isSameArticleShade(draft, row.line);

    final index = widget.rows.indexOf(row);

    for (final (otherIndex, other) in widget.rows.indexed) {
      if (other != row &&
          isSameArticleShade(other.line, draft) &&
          (isChanged || otherIndex < index)) {
        return otherIndex + 1;
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    // Worked out from the lines as they are now (after a delete or a fix).
    final duplicateCount = markDuplicates(widget.rows);

    final total = widget.rows.length;

    // Errors and duplicates.
    final errorRows = widget.rows.where((row) => row.isRed).toList();

    final warningRows = widget.rows.where((row) => row.hasWarning).toList();

    // Red lines, and yellow lines with a Quantity to fix.
    final blockingRows =
        widget.rows.where((row) => !row.isUploadable).toList();

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

    // Only when every line is an "R" article; mixed, a normal order.
    final showsTc = _showsTc;

    final isReady = blockingRows.isEmpty && validCount > 0;

    _noticeReady(isReady);

    return AlertDialog(
      title: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          if (duplicateCount > 0) ...[
            const SizedBox(width: 16),
            Tooltip(
              message: 'Deletes the $duplicateCount line(s) whose Article '
                  'and Shade an earlier line already has; the first of each '
                  'stays',
              child: SecondaryButton(
                wait: false,
                iconData: Icons.delete_sweep_outlined,
                text: 'Delete duplicates ($duplicateCount)',
                onPressed: () async => _deleteDuplicates(),
              ),
            ),
          ],
          if (showsTc) ...[
            const SizedBox(width: 16),
            _TcRequiredBox(
              value: _tcTicked,
              rArticleCount: total,
              onTap: _toggleTc,
            ),
          ],
        ],
      ),
      content: SizedBox(
        width: 1100,
        height: 540,
        child: Stack(
          children: [
            Positioned.fill(child: _content(errorRows, warningRows)),
            // In the middle, over the lines; taps elsewhere go through.
            Positioned.fill(
              child: IgnorePointer(
                ignoring: !_showsReady,
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _showsReady
                        ? _ReadyNotice(
                            key: const ValueKey('ready'),
                            count: validCount,
                            warningCount: warningRows.length,
                            onTap: _hideReady,
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
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
          onPressed: !isReady
              ? null
              : () async {
                  Get.back(result: true);
                },
        ),
      ],
    );
  }

  Widget _content(
    List<ExcelImportRow> errorRows,
    List<ExcelImportRow> warningRows,
  ) {
    return Column(
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
    );
  }
}

/// "All lines are ready": shown in the middle of the import dialog when
/// Yes comes on after the last fix or delete. Tapped, it goes.
class _ReadyNotice extends StatelessWidget {
  /// Lines Yes uploads.
  final int count;

  /// Of them, yellow lines (uploaded as they are).
  final int warningCount;

  final VoidCallback onTap;

  const _ReadyNotice({
    super.key,
    required this.count,
    required this.warningCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Material(
        elevation: 8,
        color: _Status.validFill,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: _Status.validText, width: 1.2),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle,
                color: _Status.validText,
                size: 30,
              ),
              const SizedBox(width: 14),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'All lines are ready',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: _Status.validText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Press Yes to upload the $count line'
                    '${count == 1 ? '' : 's'}'
                    '${warningCount == 0 ? '' : ' ($warningCount with warnings)'}'
                    '.',
                    style: TextStyle(
                      fontSize: 13,
                      color: VardhmanColors.darkGrey,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Tick if TC Required" in the import header (every line an "R" article):
/// ticks or unticks every line at once.
class _TcRequiredBox extends StatelessWidget {
  final bool value;

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
      message: 'Every line has an "R" article. Ticked, all '
          '$rArticleCount line(s) are uploaded as TC Required (direct '
          'delivery); unticked, all as normal lines',
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

  final void Function(ExcelImportRow row) onFix;

  final void Function(ExcelImportRow row) onDelete;

  const _LinesGrid({
    required this.rows,
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

                // Red for an error or a duplicate.
                final isValid = !row.isRed;

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
                          // On every red line (Article / Shade missing or
                          // not in JDE, a duplicate); any other line is
                          // deleted from its Fix modal.
                          if (!isValid)
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

  /// TC Required ticked: the Article can only be replaced with another
  /// "R" article.
  final bool rArticleOnly;

  /// The number of another line with the edited Article and Shade, or
  /// null: Save & validate does not save a duplicate, as the form does not
  /// add one.
  final int? Function(ExcelLine draft) duplicateRowNumberOf;

  final Future<void> Function() onRevalidate;

  final VoidCallback onDelete;

  const _FixLineDialog({
    required this.row,
    required this.number,
    required this.rArticleOnly,
    required this.duplicateRowNumberOf,
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

    // The row's own duplicate mark, until a Save & validate.
    final duplicate = draftProblems == null ? widget.row.duplicate : null;

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
            if (duplicate != null) _message(duplicate, isError: true),
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
                  helperText: widget.rArticleOnly
                      ? 'TC Required: "R" articles only'
                      : null,
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

            // TC Required ticked for the sheet: an "R" article only, the
            // row is left as it was.
            if (widget.rArticleOnly &&
                !_draft.article.toUpperCase().contains('R')) {
              final error = 'TC Required is ticked: the Article can only be '
                  'replaced with an "R" article (is "${_draft.article}")';

              debugPrint(
                '[BULK IMPORT] Fix row ${widget.number}: not saved, $error',
              );

              setState(
                () => _draftProblems = _DraftProblems(
                  error: error,
                  warning: null,
                  quantityProblem: _draft.quantityProblem,
                ),
              );

              return;
            }

            // As the form: no line with the Article and Shade of another;
            // the row is left as it was.
            if (widget.duplicateRowNumberOf(_draft) case final number?) {
              final error = 'Duplicate Article and Shade combination: same '
                  'as row $number';

              debugPrint(
                '[BULK IMPORT] Fix row ${widget.number}: not saved, $error',
              );

              setState(
                () => _draftProblems = _DraftProblems(
                  error: error,
                  warning: null,
                  quantityProblem: _draft.quantityProblem,
                ),
              );

              return;
            }

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
