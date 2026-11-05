import 'package:flutter/material.dart';
import 'package:vardhman_b2b/app/theme_variants.dart';

class HeaderView extends StatelessWidget {
  final Widget? leading, trailing, title, tabBar;
  final double elevation;

  /// Half the usual top / bottom padding, for dialogs that need the height.
  final bool dense;

  const HeaderView({
    super.key,
    this.leading,
    this.trailing,
    this.title,
    this.elevation = 4.0,
    this.tabBar,
    this.dense = false,
  });

  /// Share of the header width that [leading] or [trailing] may take before
  /// it is scaled down, so the title always keeps some room.
  static const _sideMaxWidthFactor = 0.4;

  @override
  Widget build(BuildContext context) {
    // Read on every build: a theme switch rebuilds the header.
    final variant = ThemeVariants.current;

    final verticalPadding = dense ? 6.0 : 12.0;

    return Material(
      elevation: elevation,
      color: Colors.white,
      // A wash of the active theme's primary gradient, as on the order
      // lists' Filters bar; dark text and white buttons stay readable on it.
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: variant.primaryGradient
                .map(
                  (color) =>
                      Color.alphaBlend(color.withAlpha(46), Colors.white),
                )
                .toList(),
          ),
          border: Border(
            bottom: BorderSide(color: variant.primary.withAlpha(70)),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.only(
                left: 12.0,
                top: verticalPadding,
                right: 12,
                bottom: tabBar != null ? 0 : verticalPadding,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Leading and trailing keep their natural size on a normal
                  // window; on a narrow one they are capped and scaled down
                  // instead of pushing the row past the edge.
                  Widget side(Widget child, Alignment alignment) =>
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: constraints.maxWidth * _sideMaxWidthFactor,
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: alignment,
                          child: child,
                        ),
                      );
  
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      if (leading != null) side(leading!, Alignment.centerLeft),
                      if (title != null) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: title!,
                        ),
                      ],
                      if (trailing != null) ...[
                        const SizedBox(width: 8),
                        side(trailing!, Alignment.centerRight),
                      ],
                    ],
                  );
                },
              ),
            ),
            if (tabBar != null) ...[
              const SizedBox(
                height: 4,
              ),
              tabBar!
            ],
          ],
        ),
      ),
    );
  }
}
