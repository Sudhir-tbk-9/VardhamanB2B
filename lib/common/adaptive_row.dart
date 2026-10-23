import 'package:flutter/material.dart';
import 'package:vardhman_b2b/common/breakpoints.dart';

/// How an [AdaptiveRow] lays out its children when it is narrow.
enum NarrowLayout {
  /// One under the other, full width. For groups of form fields.
  column,

  /// Left to right, wrapping onto new lines: flexible children (form
  /// fields) at least [AdaptiveRow.minChildWidth] wide, others (buttons) at
  /// their own size. For filter bars and button rows.
  wrap,
}

/// A [Row] that rearranges its children once it is narrower than
/// [breakpoint], so the fields of a form or filter bar are never squeezed
/// into slivers.
///
/// It takes the same children as the Row it replaces. When narrow,
/// [Expanded] / [Flexible] lose their flex, [Spacer]s and width-only
/// [SizedBox] gaps turn into [spacing], and the children are laid out as
/// [narrowLayout] says.
class AdaptiveRow extends StatelessWidget {
  const AdaptiveRow({
    super.key,
    required this.children,
    this.breakpoint = Breakpoints.formRow,
    this.narrowLayout = NarrowLayout.column,
    this.spacing = 8,
    this.minChildWidth = 160,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.mainAxisSize = MainAxisSize.max,
    this.crossAxisAlignment = CrossAxisAlignment.center,
  });

  final List<Widget> children;

  final double breakpoint;

  final NarrowLayout narrowLayout;

  /// Gap between children when narrow.
  final double spacing;

  /// Narrowest a flexible child gets in [NarrowLayout.wrap].
  final double minChildWidth;

  /// Used as is when wide.
  final MainAxisAlignment mainAxisAlignment;

  /// Used as is when wide.
  final MainAxisSize mainAxisSize;

  /// Used as is when wide.
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= breakpoint) {
          return Row(
            mainAxisAlignment: mainAxisAlignment,
            mainAxisSize: mainAxisSize,
            crossAxisAlignment: crossAxisAlignment,
            children: children,
          );
        }

        final items = <({Widget child, bool isFlexible})>[
          for (final child in children)
            if (!_isGap(child))
              child is Flexible
                  ? (child: child.child, isFlexible: true)
                  : (child: child, isFlexible: false),
        ];

        if (narrowLayout == NarrowLayout.column) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: spacing,
            children: [for (final item in items) item.child],
          );
        }

        // As many flexible children per line as fit at minChildWidth, sharing
        // the line's width evenly.
        final flexibleCount = items.where((item) => item.isFlexible).length;

        final perLine =
            ((constraints.maxWidth + spacing) / (minChildWidth + spacing))
                .floor()
                .clamp(1, flexibleCount < 1 ? 1 : flexibleCount);

        final childWidth =
            (constraints.maxWidth - spacing * (perLine - 1)) / perLine;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final item in items)
              item.isFlexible
                  ? SizedBox(width: childWidth, child: item.child)
                  : item.child,
          ],
        );
      },
    );
  }

  /// [Spacer] and empty, width-only [SizedBox] gaps, replaced by [spacing].
  static bool _isGap(Widget child) =>
      child is Spacer ||
      (child is SizedBox &&
          child.child == null &&
          child.height == null &&
          child.width != null);
}
