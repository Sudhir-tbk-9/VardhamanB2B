import 'package:flutter/material.dart';
import 'package:vardhman_b2b/app/theme_variants.dart';

/// Title of a New Order dialog: the order type beside a badge in the active
/// theme's gradient.
class OrderFormTitle extends StatelessWidget {
  final IconData icon;

  final String title;

  const OrderFormTitle({
    super.key,
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    // Read on every build: a theme switch rebuilds the title.
    final variant = ThemeVariants.current;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 32,
          height: 32,
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
          child: Icon(icon, size: 17, color: Colors.white),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: variant.accent,
            ),
          ),
        ),
      ],
    );
  }
}
