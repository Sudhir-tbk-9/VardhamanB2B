import 'package:flutter/material.dart';
import 'package:vardhman_b2b/common/breakpoints.dart';

/// A [Dialog] that fills a phone-sized window ([Breakpoints.compact]) and
/// keeps [insetPadding] on larger ones. The size is checked on every build,
/// so resizing the window with the dialog open adapts it too.
class AdaptiveDialog extends StatelessWidget {
  const AdaptiveDialog({
    super.key,
    this.insetPadding = const EdgeInsets.symmetric(
      horizontal: 40,
      vertical: 24,
    ),
    this.clipBehavior = Clip.none,
    this.backgroundColor,
    this.shape,
    required this.child,
  });

  /// Defaults to [Dialog]'s own inset.
  final EdgeInsets insetPadding;

  final Clip clipBehavior;

  final Color? backgroundColor;

  /// Used on larger windows; a phone-sized one always gets square corners.
  final ShapeBorder? shape;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isCompact = context.isCompact;

    return Dialog(
      insetPadding: isCompact ? EdgeInsets.zero : insetPadding,
      clipBehavior: clipBehavior,
      backgroundColor: backgroundColor,
      // Full screen on a phone: square corners, like a page.
      shape: isCompact ? const RoundedRectangleBorder() : shape,
      child: child,
    );
  }
}
