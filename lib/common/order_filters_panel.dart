import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:vardhman_b2b/common/secondary_button.dart';
import 'package:vardhman_b2b/constants.dart';
import 'package:vardhman_b2b/orders/order_list_filters.dart';

/// An order list's filters, closed to one "Filters" line (with the filters
/// in use) so the list keeps the room; tapping it opens [child], the filter
/// fields.
class OrderFiltersPanel extends StatelessWidget {
  final OrderListFilters filters;

  final Widget child;

  const OrderFiltersPanel({
    super.key,
    required this.filters,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(
      () {
        final isExpanded = filters.rxFiltersExpanded.value;

        final activeFilterLabels = filters.activeFilterLabels;

        final lineSearchProgress = filters.rxLineSearchProgress.value;

        final textStyle = TextStyle(
          fontSize: 13,
          color: VardhmanColors.darkGrey,
        );

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => filters.rxFiltersExpanded.value = !isExpanded,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Icon(
                            isExpanded ? Icons.expand_more : Icons.chevron_right,
                            size: 20,
                            color: VardhmanColors.darkGrey,
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.filter_list,
                            size: 16,
                            color: activeFilterLabels.isEmpty
                                ? VardhmanColors.darkGrey
                                : VardhmanColors.red,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Filters',
                            style: textStyle.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (activeFilterLabels.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                isExpanded
                                    ? '(${activeFilterLabels.length} active)'
                                    : '(${activeFilterLabels.join(', ')})',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textStyle.copyWith(fontSize: 12),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SecondaryButton(
                  wait: false,
                  iconData: FontAwesomeIcons.arrowRotateLeft.data,
                  text: '',
                  onPressed:
                      filters.hasDefaultValues ? null : filters.setDefaultValues,
                ),
              ],
            ),
            if (isExpanded) ...[
              const SizedBox(height: 12),
              child,
            ],
            // Shown closed too: a shade / buyer search keeps running.
            if (lineSearchProgress != null) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: lineSearchProgress,
                color: VardhmanColors.red,
                backgroundColor: VardhmanColors.dividerGrey,
              ),
            ],
          ],
        );
      },
    );
  }
}
