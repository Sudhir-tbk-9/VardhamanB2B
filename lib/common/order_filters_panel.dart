import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vardhman_b2b/app/theme_variants.dart';
import 'package:vardhman_b2b/constants.dart';
import 'package:vardhman_b2b/orders/order_list_filters.dart';

/// An order list's filters, closed to one "Filters" line (with the filters
/// in use) so the list keeps the room; tapping it opens [child], the filter
/// fields.
///
/// Drawn as a card washed in the active theme's primary gradient: stronger
/// on the header line, lighter behind the fields so they stay readable.
class OrderFiltersPanel extends StatelessWidget {
  final OrderListFilters filters;

  final Widget child;

  const OrderFiltersPanel({
    super.key,
    required this.filters,
    required this.child,
  });

  /// [color] laid over white at [alpha]: a tint that keeps dark text legible.
  static Color _wash(Color color, int alpha) =>
      Color.alphaBlend(color.withAlpha(alpha), Colors.white);

  @override
  Widget build(BuildContext context) {
    return Obx(
      () {
        final isExpanded = filters.rxFiltersExpanded.value;

        final activeFilterLabels = filters.activeFilterLabels;

        final lineSearchProgress = filters.rxLineSearchProgress.value;

        // Read on every build: a theme switch rebuilds the panel.
        final variant = ThemeVariants.current;

        final textStyle = TextStyle(
          fontSize: 13,
          color: VardhmanColors.darkGrey,
        );

        const radius = Radius.circular(12);

        final header = Container(
          padding: const EdgeInsets.fromLTRB(4, 4, 6, 4),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: variant.primaryGradient
                  .map((color) => _wash(color, 46))
                  .toList(),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => filters.rxFiltersExpanded.value = !isExpanded,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        AnimatedRotation(
                          turns: isExpanded ? 0.25 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            Icons.chevron_right,
                            size: 20,
                            color: VardhmanColors.darkGrey,
                          ),
                        ),
                        const SizedBox(width: 4),
                        // Theme badge: the full gradient, as on the primary
                        // buttons.
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: variant.primaryFill(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: variant.primary.withAlpha(70),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.filter_list,
                            size: 15,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Filters',
                          style: textStyle.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (activeFilterLabels.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: variant.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${activeFilterLabels.length}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          if (!isExpanded) ...[
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                activeFilterLabels.join(', '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textStyle.copyWith(fontSize: 12),
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _ResetFiltersButton(
                variant: variant,
                onPressed:
                    filters.hasDefaultValues ? null : filters.setDefaultValues,
              ),
            ],
          ),
        );

        return Container(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(radius),
            border: Border.all(color: variant.primary.withAlpha(70)),
            // Lighter wash behind the fields, fading down the panel.
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: variant.primaryGradient
                  .map((color) => _wash(color, 16))
                  .toList(),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              if (isExpanded) ...[
                Divider(
                  height: 1,
                  thickness: 1,
                  color: variant.primary.withAlpha(50),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: child,
                ),
              ],
              // Shown closed too: a shade / buyer search keeps running.
              if (lineSearchProgress != null)
                LinearProgressIndicator(
                  value: lineSearchProgress,
                  minHeight: 3,
                  color: variant.primary,
                  backgroundColor: variant.primary.withAlpha(30),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Resets the filters. In the theme like the "Filters" badge: the full
/// primary gradient while there is something to reset, a light tint of it
/// (not grey) while the filters are at their defaults and it does nothing.
class _ResetFiltersButton extends StatelessWidget {
  final AppThemeVariant variant;

  /// Null while the filters are at their defaults.
  final VoidCallback? onPressed;

  const _ResetFiltersButton({required this.variant, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;

    return Tooltip(
      message: 'Reset filters',
      child: MouseRegion(
        cursor: isEnabled ? SystemMouseCursors.click : MouseCursor.defer,
        child: GestureDetector(
          onTap: onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isEnabled ? null : Colors.white,
              gradient: isEnabled
                  ? variant.primaryFill(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              border: isEnabled
                  ? null
                  : Border.all(color: variant.primary.withAlpha(90)),
              boxShadow: isEnabled
                  ? [
                      BoxShadow(
                        color: variant.primary.withAlpha(70),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            // A Material icon: the Font Awesome one did not show in the
            // deployed web build.
            child: Icon(
              Icons.restart_alt,
              size: 18,
              color: isEnabled ? Colors.white : variant.primary.withAlpha(140),
            ),
          ),
        ),
      ),
    );
  }
}
