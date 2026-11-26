import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:toastification/toastification.dart';
import 'package:vardhman_b2b/app/theme_variants.dart';
import 'package:vardhman_b2b/common/primary_button.dart';
import 'package:vardhman_b2b/common/secondary_button.dart';
import 'package:vardhman_b2b/common/table_header.dart';
import 'package:vardhman_b2b/constants.dart';
import 'package:vardhman_b2b/drift/database.dart';
import 'package:vardhman_b2b/user/user_controller.dart';

/// Deletes the logged in customer's drafts from this browser: all of them,
/// those of one [orderType] (BK, DT, or LD for Labdip and Sampling both),
/// the one draft [orderNumber], or the drafts [orderNumbers] (picked in
/// [showSelectDraftsDialog]). Returns how many orders were cleared.
Future<int> deleteDrafts({
  String? orderType,
  int? orderNumber,
  Iterable<int>? orderNumbers,
}) async {
  final soldTo = Get.find<UserController>(tag: 'userController')
      .rxUserDetail
      .value
      .soldToNumber;

  final table = Get.find<Database>().managers.draftTable;

  var query = table.filter((f) => f.soldTo.equals(soldTo));

  if (orderType != null) {
    query = query.filter((f) => f.orderType.equals(orderType));
  }

  if (orderNumber != null) {
    query = query.filter((f) => f.orderNumber.equals(orderNumber));
  }

  if (orderNumbers != null) {
    query = query.filter((f) => f.orderNumber.isIn(orderNumbers));
  }

  final clearedOrders = (await query.get())
      .map((line) => (line.orderType, line.orderNumber))
      .toSet();

  await query.delete();

  debugPrint(
    '[DRAFTS] Cleared ${clearedOrders.length} draft order(s) of sold-to '
    '$soldTo${orderType == null ? '' : ', type $orderType'}'
    '${orderNumber == null ? '' : ', order $orderNumber'}: '
    '${clearedOrders.map((o) => '${o.$1} #${o.$2}').join(', ')}',
  );

  return clearedOrders.length;
}

/// Asks before drafts are deleted: they are only in this browser and cannot
/// be brought back. True for Clear.
Future<bool> confirmClearDrafts({
  required String title,
  required String message,
}) async {
  final confirmed = await Get.dialog<bool>(
    AlertDialog(
      title: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: 420,
        child: Text(
          '$message This cannot be undone.',
          style: TextStyle(fontSize: 13, color: VardhmanColors.darkGrey),
        ),
      ),
      actions: [
        SecondaryButton(
          text: 'Cancel',
          onPressed: () async => Get.back(result: false),
        ),
        PrimaryButton(
          wait: false,
          text: 'Clear',
          iconData: Icons.delete_outline,
          onPressed: () async => Get.back(result: true),
        ),
      ],
    ),
  );

  return confirmed == true;
}

/// "Clear drafts" button: asks first, deletes the drafts [deleteDrafts]
/// picks with [orderType] / [orderNumber], says how many went, then calls
/// [onCleared] (e.g. to clear the order form).
class ClearDraftsButton extends StatelessWidget {
  final String text;

  final String? orderType;

  final int? orderNumber;

  /// Title and text of the confirmation.
  final String confirmTitle;

  final String confirmMessage;

  final VoidCallback? onCleared;

  const ClearDraftsButton({
    super.key,
    this.text = 'Clear Drafts',
    this.orderType,
    this.orderNumber,
    required this.confirmTitle,
    required this.confirmMessage,
    this.onCleared,
  });

  @override
  Widget build(BuildContext context) {
    return SecondaryButton(
      text: text,
      iconData: Icons.delete_sweep_outlined,
      tooltip: confirmTitle,
      onPressed: () async {
        if (!await confirmClearDrafts(
          title: confirmTitle,
          message: confirmMessage,
        )) {
          return;
        }

        final count = await deleteDrafts(
          orderType: orderType,
          orderNumber: orderNumber,
        );

        toastification.show(
          autoCloseDuration: const Duration(seconds: 4),
          primaryColor: VardhmanColors.green,
          title: Text(
            count == 1 ? '1 draft cleared' : '$count drafts cleared',
          ),
        );

        onCleared?.call();
      },
    );
  }
}

/// One draft order in [showSelectDraftsDialog]: its number, how many lines
/// it has, and what identifies it in the order list.
class DraftSummary {
  final int orderNumber;

  final int lineCount;

  final String poNumber;

  final String merchandiser;

  final DateTime lastUpdated;

  const DraftSummary({
    required this.orderNumber,
    required this.lineCount,
    required this.poNumber,
    required this.merchandiser,
    required this.lastUpdated,
  });
}

/// The logged in customer's drafts of [orderType] in this browser, last
/// updated first, one per order.
Future<List<DraftSummary>> loadDraftSummaries(String orderType) async {
  final soldTo = Get.find<UserController>(tag: 'userController')
      .rxUserDetail
      .value
      .soldToNumber;

  final lines = await Get.find<Database>()
      .managers
      .draftTable
      .filter((f) => f.soldTo.equals(soldTo))
      .filter((f) => f.orderType.equals(orderType))
      .get();

  final byOrder = <int, List<DraftTableData>>{};

  for (final line in lines) {
    (byOrder[line.orderNumber] ??= []).add(line);
  }

  String firstNonEmpty(
    List<DraftTableData> lines,
    String Function(DraftTableData line) valueOf,
  ) =>
      lines
          .map(valueOf)
          .firstWhere((value) => value.trim().isNotEmpty, orElse: () => '');

  return [
    for (final MapEntry(key: orderNumber, value: orderLines)
        in byOrder.entries)
      DraftSummary(
        orderNumber: orderNumber,
        lineCount: orderLines.length,
        poNumber: firstNonEmpty(orderLines, (line) => line.poNumber),
        merchandiser: firstNonEmpty(orderLines, (line) => line.merchandiser),
        lastUpdated: orderLines
            .map((line) => line.lastUpdated)
            .reduce((a, b) => a.isAfter(b) ? a : b),
      ),
  ]..sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));
}

/// Lists [drafts] with a checkbox each and Select all; returns the order
/// numbers picked for Clear selected, or null for Cancel.
Future<Set<int>?> showSelectDraftsDialog({
  required String typeName,
  required List<DraftSummary> drafts,
}) =>
    Get.dialog<Set<int>>(
      SelectDraftsDialog(typeName: typeName, drafts: drafts),
    );

/// Picks drafts of one order list (Bulk, DTM, Labdip / Sampling) to clear:
/// one, several, or all at once with Select all. Drawn in the active
/// theme's colours (header gradient, table header, checkboxes, buttons).
class SelectDraftsDialog extends StatefulWidget {
  final String typeName;

  final List<DraftSummary> drafts;

  const SelectDraftsDialog({
    super.key,
    required this.typeName,
    required this.drafts,
  });

  @override
  State<SelectDraftsDialog> createState() => _SelectDraftsDialogState();
}

class _SelectDraftsDialogState extends State<SelectDraftsDialog> {
  final _selected = <int>{};

  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();

    super.dispose();
  }

  /// Select all: ticked when every draft is, a dash when some are.
  bool? get _allState => _selected.isEmpty
      ? false
      : _selected.length == widget.drafts.length
          ? true
          : null;

  void _toggleAll() => setState(() {
        if (_selected.length == widget.drafts.length) {
          _selected.clear();
        } else {
          _selected.addAll(widget.drafts.map((draft) => draft.orderNumber));
        }
      });

  void _toggle(int orderNumber) => setState(() {
        if (!_selected.remove(orderNumber)) {
          _selected.add(orderNumber);
        }
      });

  static const _flexes = [3, 2, 3, 3, 4];

  Widget _cells(List<Widget> children) => Row(
        children: [
          for (final (index, child) in children.indexed)
            Expanded(flex: _flexes[index], child: child),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final variant = ThemeVariants.current;

    const headerStyle = TextStyle(
      color: Colors.white,
      fontSize: 12,
      fontWeight: FontWeight.bold,
    );

    final cellStyle = TextStyle(fontSize: 12.5, color: VardhmanColors.darkGrey);

    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');

    final count = _selected.length;

    return AlertDialog(
      titlePadding: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        decoration: BoxDecoration(gradient: variant.primaryFill()),
        child: Row(
          children: [
            const Icon(Icons.delete_sweep_outlined, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Clear ${widget.typeName} drafts',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
      content: SizedBox(
        width: 640,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Select the drafts to clear. They are kept only in this '
              'browser and cannot be brought back.',
              style: cellStyle,
            ),
            const SizedBox(height: 12),
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                border: Border.all(color: VardhmanColors.dividerGrey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header with Select all, in the theme's table header.
                  Container(
                    decoration: TableHeader.decoration,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      children: [
                        Tooltip(
                          message: 'Select all',
                          child: Checkbox(
                            value: _allState,
                            tristate: true,
                            visualDensity: VisualDensity.compact,
                            side: const BorderSide(
                              color: Colors.white,
                              width: 1.5,
                            ),
                            fillColor: WidgetStateProperty.resolveWith(
                              (states) => states.contains(WidgetState.selected)
                                  ? Colors.white
                                  : Colors.transparent,
                            ),
                            checkColor: variant.primary,
                            onChanged: (_) => _toggleAll(),
                          ),
                        ),
                        Expanded(
                          child: _cells(const [
                            Text('Draft No.', style: headerStyle),
                            Text('Lines', style: headerStyle),
                            Text('PO No.', style: headerStyle),
                            Text('Merchandiser', style: headerStyle),
                            Text('Last updated', style: headerStyle),
                          ]),
                        ),
                      ],
                    ),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 360),
                    child: Scrollbar(
                      controller: _scrollController,
                      child: ListView.builder(
                        controller: _scrollController,
                        shrinkWrap: true,
                        itemCount: widget.drafts.length,
                        itemBuilder: (context, index) {
                          final draft = widget.drafts[index];

                          final isSelected =
                              _selected.contains(draft.orderNumber);

                          return Material(
                            color: isSelected
                                ? VardhmanColors.red.withAlpha(22)
                                : index.isEven
                                    ? Colors.white
                                    : VardhmanColors.dividerGrey.withAlpha(90),
                            child: InkWell(
                              // Light press colours: the theme's highlight
                              // is the solid accent, which turned the row
                              // dark while pressed.
                              highlightColor:
                                  VardhmanColors.red.withAlpha(28),
                              splashColor: VardhmanColors.red.withAlpha(40),
                              hoverColor: VardhmanColors.red.withAlpha(14),
                              onTap: () => _toggle(draft.orderNumber),
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                child: Row(
                                  children: [
                                    Checkbox(
                                      value: isSelected,
                                      activeColor: VardhmanColors.red,
                                      visualDensity: VisualDensity.compact,
                                      onChanged: (_) =>
                                          _toggle(draft.orderNumber),
                                    ),
                                    Expanded(
                                      child: _cells([
                                        Text(
                                          '#${draft.orderNumber}',
                                          style: cellStyle.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          '${draft.lineCount}',
                                          style: cellStyle,
                                        ),
                                        Text(
                                          draft.poNumber.isEmpty
                                              ? '-'
                                              : draft.poNumber,
                                          style: cellStyle,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          draft.merchandiser.isEmpty
                                              ? '-'
                                              : draft.merchandiser,
                                          style: cellStyle,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          dateFormat.format(draft.lastUpdated),
                                          style: cellStyle,
                                        ),
                                      ]),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$count of ${widget.drafts.length} selected',
              style: cellStyle.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
      actions: [
        SecondaryButton(
          wait: false,
          text: 'Cancel',
          onPressed: () async => Get.back(),
        ),
        PrimaryButton(
          wait: false,
          text: count == 0 ? 'Clear selected' : 'Clear selected ($count)',
          iconData: Icons.delete_outline,
          onPressed:
              count == 0 ? null : () async => Get.back(result: {..._selected}),
        ),
      ],
    );
  }
}

/// "Clear Drafts" button of an order list: opens [SelectDraftsDialog] with
/// the list's drafts ([orderType]), deletes the ones picked and says how
/// many went.
class SelectClearDraftsButton extends StatelessWidget {
  final String orderType;

  /// Bulk, DTM or Labdip / Sampling.
  final String typeName;

  const SelectClearDraftsButton({
    super.key,
    required this.orderType,
    required this.typeName,
  });

  @override
  Widget build(BuildContext context) {
    return SecondaryButton(
      text: 'Clear Drafts',
      iconData: Icons.delete_sweep_outlined,
      tooltip: 'Select $typeName drafts to clear',
      onPressed: () async {
        final drafts = await loadDraftSummaries(orderType);

        if (drafts.isEmpty) {
          return;
        }

        final selected = await showSelectDraftsDialog(
          typeName: typeName,
          drafts: drafts,
        );

        if (selected == null || selected.isEmpty) {
          return;
        }

        final count = await deleteDrafts(
          orderType: orderType,
          orderNumbers: selected,
        );

        toastification.show(
          autoCloseDuration: const Duration(seconds: 4),
          primaryColor: VardhmanColors.green,
          title: Text(
            count == 1 ? '1 draft cleared' : '$count drafts cleared',
          ),
        );
      },
    );
  }
}
