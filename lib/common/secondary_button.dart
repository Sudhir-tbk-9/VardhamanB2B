import 'package:flutter/material.dart';
import 'package:vardhman_b2b/constants.dart';

/// Makes the [SecondaryButton]s under it compact, for buttons placed inside
/// a 36 px form field (clear, Choose File) so they clear its border.
class CompactButtons extends InheritedWidget {
  const CompactButtons({super.key, required super.child});

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CompactButtons>() != null;

  @override
  bool updateShouldNotify(CompactButtons oldWidget) => false;
}

class SecondaryButton extends StatefulWidget {
  final Future<void> Function()? onPressed;
  final String text;
  final IconData? iconData;
  /// Shown on hover / long press; names an icon-only button.
  final String? tooltip;
  /// Pause 500 ms before running [onPressed]. Off by default: the spinner
  /// already shows while the action runs, and the pause made every tap lag.
  final bool wait;

  const SecondaryButton({
    super.key,
    this.iconData,
    this.tooltip,
    required this.text,
    required this.onPressed,
    this.wait = false,
  });

  @override
  State<SecondaryButton> createState() => _SecondaryButtonState();
}

class _SecondaryButtonState extends State<SecondaryButton> {
  bool isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final isCompact = CompactButtons.of(context);

    final iconSize = isCompact ? 14.0 : 18.0;

    final button = GestureDetector(
      onTap: () async {
        if (widget.onPressed != null && !isProcessing) {
          setState(() {
            isProcessing = true;
          });

          if (widget.wait) {
            await Future.delayed(
              const Duration(
                milliseconds: 500,
              ),
            );
          }

          try {
            await widget.onPressed!();
          } finally {
            if (mounted) {
              setState(() {
                isProcessing = false;
              });
            }
          }
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 8 : 12,
          vertical: isCompact ? 4 : 8,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.grey,
            width: 0.5,
          ),
          color: widget.onPressed == null || isProcessing
              ? Colors.grey
              : Colors.white,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            isProcessing
                ? SizedBox(
                    height: iconSize - 2,
                    width: iconSize - 2,
                    child: CircularProgressIndicator(
                      strokeWidth: isCompact ? 2 : 2.5,
                      valueColor: AlwaysStoppedAnimation(
                        VardhmanColors.red,
                      ),
                    ),
                  )
                : widget.iconData == null
                    ? const SizedBox(width: 0.0, height: 0.0)
                    : Icon(
                        widget.iconData,
                        color: widget.onPressed != null
                            ? VardhmanColors.darkGrey
                            : Colors.white,
                        size: iconSize,
                      ),
            if ((widget.iconData != null || isProcessing) &&
                widget.text.isNotEmpty)
              SizedBox(width: isCompact ? 6 : 8),
            if (widget.text.isNotEmpty)
              Text(
                widget.text,
                style: TextStyle(
                  fontSize: isCompact ? 12 : 13,
                  color: widget.onPressed != null
                      ? VardhmanColors.darkGrey
                      : Colors.white,
                ),
              ),
          ],
        ),
      ),
    );

    return widget.tooltip == null
        ? button
        : Tooltip(message: widget.tooltip!, child: button);
  }
}
