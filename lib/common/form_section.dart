import 'package:flutter/material.dart';
import 'package:vardhman_b2b/app/theme_variants.dart';
import 'package:vardhman_b2b/constants.dart';

/// Most a New Order form takes of the window height before it scrolls:
/// what is left after the header, Ship-To bar and a few lines of the lines
/// table.
double formMaxHeight(BuildContext context) =>
    (MediaQuery.sizeOf(context).height - 320).clamp(200.0, double.infinity);

/// A group of related fields in a New Order form under a flat heading: the
/// theme's icon and title, then a thin rule fading out in the theme colour.
class FormSection extends StatelessWidget {
  final String title;

  final IconData icon;

  final Widget child;

  const FormSection({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // Read on every build: a theme switch rebuilds the heading.
    final variant = ThemeVariants.current;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 2),
          child: Row(
            children: [
              Icon(icon, size: 15, color: variant.primary),
              const SizedBox(width: 6),
              Text(
                title.toUpperCase(),
                maxLines: 1,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: variant.accent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 1.5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        ...variant.primaryGradient
                            .map((color) => color.withAlpha(150)),
                        variant.primary.withAlpha(0),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        child,
      ],
    );
  }
}

/// The row of a New Order form's actions (Clear, Add Line, ...), set off
/// from the fields by a thin rule.
class FormActionsBar extends StatelessWidget {
  final Widget child;

  const FormActionsBar({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: VardhmanColors.dividerGrey),
        ),
      ),
      child: child,
    );
  }
}
