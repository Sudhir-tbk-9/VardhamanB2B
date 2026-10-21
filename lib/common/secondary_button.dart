import 'package:flutter/material.dart';
import 'package:vardhman_b2b/constants.dart';

class SecondaryButton extends StatefulWidget {
  final Future<void> Function()? onPressed;
  final String text;
  final IconData? iconData;
  /// Pause 500 ms before running [onPressed]. Off by default: the spinner
  /// already shows while the action runs, and the pause made every tap lag.
  final bool wait;

  const SecondaryButton({
    super.key,
    this.iconData,
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
    return GestureDetector(
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
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
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
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
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
                        size: 18,
                      ),
            if ((widget.iconData != null || isProcessing) &&
                widget.text.isNotEmpty)
              const SizedBox(width: 8),
            if (widget.text.isNotEmpty)
              Text(
                widget.text,
                style: TextStyle(
                  fontSize: 13,
                  color: widget.onPressed != null
                      ? VardhmanColors.darkGrey
                      : Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
