import 'package:flutter/material.dart';
import 'package:vardhman_b2b/app/theme_variants.dart';
import 'package:vardhman_b2b/constants.dart';

class PrimaryButton extends StatefulWidget {
  final Future<void> Function()? onPressed;
  final String text;
  final IconData? iconData;
  /// Pause 500 ms before running [onPressed]. Off by default: the spinner
  /// already shows while the action runs, and the pause made every tap lag.
  final bool wait;

  const PrimaryButton({
    super.key,
    this.iconData,
    required this.text,
    required this.onPressed,
    this.wait = false,
  });

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final Color color = widget.onPressed == null
        ? Colors.grey
        : isProcessing
            ? VardhmanColors.darkGrey
            : VardhmanColors.red;

    return GestureDetector(
      onTap: isProcessing
          ? null
          : () async {
              if (widget.onPressed != null) {
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
          border: Border.all(
            color: color,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(24),
          color: color,
          // Enabled buttons are filled with the theme's primary gradient.
          gradient: widget.onPressed != null && !isProcessing
              ? ThemeVariants.current.primaryFill()
              : null,
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
                        color: Colors.white,
                        size: 16,
                      ),
            if ((widget.iconData != null || isProcessing) &&
                widget.text.isNotEmpty)
              const SizedBox(width: 8),
            if (widget.text.isNotEmpty)
              Text(
                widget.text,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
