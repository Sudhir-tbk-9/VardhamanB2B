import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vardhman_b2b/app/theme_variants.dart';
import 'package:vardhman_b2b/common/breakpoints.dart';
import 'package:vardhman_b2b/segment/segment_controller.dart';

/// Shows the segment dialog when the logged in user has not picked a
/// segment yet. It cannot be closed without picking one.
Future<void> showSegmentDialogIfNeeded() async {
  if (!Get.isRegistered<SegmentController>() ||
      Get.find<SegmentController>().hasSegment) {
    return;
  }

  await showSegmentDialog();
}

/// Shows the segment dialog. Once a segment is picked (opened again from
/// the header button) it can be closed without changing it; before that it
/// cannot.
Future<void> showSegmentDialog() async {
  if (!Get.isRegistered<SegmentController>()) {
    return;
  }

  final segmentController = Get.find<SegmentController>();

  if (segmentController.isDialogOpen) {
    return;
  }

  final canCancel = segmentController.hasSegment;

  final previous = segmentController.segment;

  segmentController.isDialogOpen = true;

  logSegment(canCancel
      ? 'Showing the segment dialog to change '
          '${segmentController.segment!.title}'
      : 'Showing the segment selection dialog');

  try {
    await Get.dialog(
      SegmentDialog(canCancel: canCancel),
      barrierDismissible: canCancel,
      barrierColor: Colors.black.withAlpha(150),
    );
  } finally {
    segmentController.isDialogOpen = false;
  }

  if (canCancel && segmentController.segment == previous) {
    logSegment('Dialog closed; segment unchanged (${previous!.title})');
  }
}

/// Top bar button showing the current segment; opens [showSegmentDialog]
/// to change it. The code only on a phone-sized window.
class SegmentHeaderButton extends StatelessWidget {
  const SegmentHeaderButton({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<SegmentController>()) {
      return const SizedBox.shrink();
    }

    final segmentController = Get.find<SegmentController>();

    final isCompact = context.isCompact;

    return Obx(() {
      final segment = segmentController.segment;

      return Tooltip(
        message: segment == null
            ? 'Choose segment'
            : 'Segment: ${segment.title} (${segment.categories.join(', ')})'
                '\nClick to change',
        child: Material(
          color: Colors.white.withAlpha(30),
          shape: StadiumBorder(
            side: BorderSide(color: Colors.white.withAlpha(90)),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: showSegmentDialog,
            hoverColor: Colors.white.withAlpha(30),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 5, 8, 5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    segment?.icon ?? Icons.category_outlined,
                    size: 16,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    segment == null
                        ? 'Segment'
                        : isCompact
                            ? segment.code
                            : '${segment.code} · ${segment.title}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.swap_horiz,
                    size: 16,
                    color: Colors.white.withAlpha(200),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}

/// Segment selection after login: one card per [OrderSegment], on the
/// current theme's backdrop over the thread photo.
class SegmentDialog extends StatefulWidget {
  /// Whether it can be closed without picking: a segment is already set.
  final bool canCancel;

  const SegmentDialog({super.key, this.canCancel = false});

  @override
  State<SegmentDialog> createState() => _SegmentDialogState();
}

class _SegmentDialogState extends State<SegmentDialog> {
  final _segmentController = Get.find<SegmentController>();

  /// Starts on the current segment when changing it.
  late OrderSegment? _picked = _segmentController.segment;

  void _pick(OrderSegment segment) {
    if (_picked == segment) {
      return;
    }

    setState(() => _picked = segment);

    logSegment('Card picked: ${segment.title} (${segment.code}); '
        'waiting for Continue');
  }

  void _confirm() {
    final segment = _picked;

    if (segment == null) {
      return;
    }

    if (segment != _segmentController.segment) {
      _segmentController.select(segment);
    }

    Get.back();
  }

  @override
  Widget build(BuildContext context) {
    final variant = ThemeVariants.current;

    final isCompact = context.isCompact;

    return PopScope(
      canPop: widget.canCancel,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          logSegment('Close blocked: a segment must be picked first');
        }
      },
      child: Dialog(
        insetPadding: isCompact
            ? EdgeInsets.zero
            : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        shape: isCompact
            ? const RoundedRectangleBorder()
            : RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        backgroundColor: variant.accent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: _Backdrop(
            variant: variant,
            child: Stack(
              children: [
                _content(variant: variant, isCompact: isCompact),
                if (widget.canCancel)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      tooltip: 'Close',
                      icon: Icon(
                        Icons.close,
                        color: Colors.white.withAlpha(220),
                      ),
                      onPressed: Get.back,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _content({
    required AppThemeVariant variant,
    required bool isCompact,
  }) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        isCompact ? 16 : 32,
        isCompact ? 24 : 28,
        isCompact ? 16 : 32,
        isCompact ? 16 : 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Heading(variant: variant),
          const SizedBox(height: 24),
          _SegmentGrid(
            variant: variant,
            picked: _picked,
            onPick: _pick,
          ),
          const SizedBox(height: 24),
          _Footer(
            variant: variant,
            picked: _picked,
            onConfirm: _confirm,
          ),
        ],
      ),
    );
  }
}

/// The thread photo under the theme's accent gradient and pattern, with a
/// glow of the primary colour in the top corner.
class _Backdrop extends StatelessWidget {
  final AppThemeVariant variant;

  final Widget child;

  const _Backdrop({required this.variant, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        image: DecorationImage(
          // The asset is several megapixels; decode a small copy.
          image: ResizeImage(
            AssetImage('assets/home_background.jpg'),
            width: 1000,
          ),
          fit: BoxFit.cover,
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              for (final color in variant.accentGradient) color.withAlpha(215),
            ],
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-1, -1),
              radius: 1.3,
              colors: [
                variant.primary.withAlpha(110),
                variant.primary.withAlpha(0),
              ],
            ),
          ),
          child: CustomPaint(
            painter: variant.pattern == ThemePattern.none
                ? null
                : ThemePatternPainter(
                    variant.pattern,
                    color: variant.patternColor,
                  ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  final AppThemeVariant variant;

  const _Heading({required this.variant});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // The logo has a white background: a white disc in a gradient ring.
        Container(
          width: 60,
          height: 60,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: variant.primaryFill(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: variant.primary.withAlpha(120),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Container(
            padding: const EdgeInsets.all(11),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            child: Image.asset('assets/vytl_icon_white.png'),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Choose your segment',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Orders in this session will offer only the articles of the '
          'segment you pick.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withAlpha(200),
            fontSize: 13,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

/// IND, DOM and SPE on the first row; IND + SPE and All Segments, wider, on
/// the second. One card per row on a narrow window.
class _SegmentGrid extends StatelessWidget {
  final AppThemeVariant variant;

  final OrderSegment? picked;

  final ValueChanged<OrderSegment> onPick;

  const _SegmentGrid({
    required this.variant,
    required this.picked,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    Widget card(OrderSegment segment) => _SegmentCard(
          segment: segment,
          variant: variant,
          isPicked: picked == segment,
          onTap: () => onPick(segment),
        );

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 14.0;

        if (constraints.maxWidth < 560) {
          return Column(
            children: [
              for (final segment in OrderSegment.values) ...[
                card(segment),
                if (segment != OrderSegment.values.last)
                  const SizedBox(height: 10),
              ],
            ],
          );
        }

        return Column(
          children: [
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: card(OrderSegment.industry)),
                  const SizedBox(width: gap),
                  Expanded(child: card(OrderSegment.domestic)),
                  const SizedBox(width: gap),
                  Expanded(child: card(OrderSegment.speciality)),
                ],
              ),
            ),
            const SizedBox(height: gap),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: card(OrderSegment.industryAndSpeciality)),
                  const SizedBox(width: gap),
                  Expanded(child: card(OrderSegment.all)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Frosted glass card; picked, it turns white with a gradient ring and a
/// check badge.
class _SegmentCard extends StatefulWidget {
  final OrderSegment segment;

  final AppThemeVariant variant;

  final bool isPicked;

  final VoidCallback onTap;

  const _SegmentCard({
    required this.segment,
    required this.variant,
    required this.isPicked,
    required this.onTap,
  });

  @override
  State<_SegmentCard> createState() => _SegmentCardState();
}

class _SegmentCardState extends State<_SegmentCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final segment = widget.segment;

    final variant = widget.variant;

    final isPicked = widget.isPicked;

    final isAll = segment == OrderSegment.all;

    final textColor = isPicked ? variant.accent : Colors.white;

    final mutedColor =
        isPicked ? variant.accent.withAlpha(170) : Colors.white.withAlpha(185);

    return Semantics(
      button: true,
      selected: isPicked,
      label: '${segment.title} segment',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _isHovered && !isPicked ? 1.025 : 1,
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              // Room for the gradient ring.
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: isPicked
                    ? variant.primaryFill(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isPicked
                    ? null
                    : Colors.white.withAlpha(_isHovered ? 90 : 55),
                boxShadow: [
                  if (isPicked || _isHovered)
                    BoxShadow(
                      color: (isPicked ? variant.primary : Colors.black)
                          .withAlpha(isPicked ? 110 : 60),
                      blurRadius: isPicked ? 22 : 14,
                      offset: const Offset(0, 6),
                    ),
                ],
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: isPicked
                      ? Colors.white
                      : Color.alphaBlend(
                          Colors.white.withAlpha(_isHovered ? 38 : 22),
                          variant.accent.withAlpha(150),
                        ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SegmentIcon(
                      icon: segment.icon,
                      variant: variant,
                      isPicked: isPicked,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _CodeChip(
                            text: segment.code,
                            variant: variant,
                            isPicked: isPicked,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            segment.title,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isAll
                                ? '${segment.subtitle} '
                                    '(${segment.categories.join(' + ')})'
                                : segment.subtitle,
                            style: TextStyle(
                              color: mutedColor,
                              fontSize: 12,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      transitionBuilder: (child, animation) =>
                          ScaleTransition(scale: animation, child: child),
                      child: isPicked
                          ? Container(
                              key: const ValueKey('picked'),
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: variant.primaryFill(),
                              ),
                              child: const Icon(
                                Icons.check,
                                size: 15,
                                color: Colors.white,
                              ),
                            )
                          : Container(
                              key: const ValueKey('not picked'),
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withAlpha(140),
                                  width: 1.5,
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SegmentIcon extends StatelessWidget {
  final IconData icon;

  final AppThemeVariant variant;

  final bool isPicked;

  const _SegmentIcon({
    required this.icon,
    required this.variant,
    required this.isPicked,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: isPicked
            ? variant.primaryFill(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isPicked ? null : Colors.white.withAlpha(36),
        border: isPicked ? null : Border.all(color: Colors.white.withAlpha(60)),
      ),
      child: Icon(icon, size: 22, color: Colors.white),
    );
  }
}

class _CodeChip extends StatelessWidget {
  final String text;

  final AppThemeVariant variant;

  final bool isPicked;

  const _CodeChip({
    required this.text,
    required this.variant,
    required this.isPicked,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: isPicked
            ? variant.primary.withAlpha(28)
            : Colors.white.withAlpha(30),
        border: Border.all(
          color: isPicked
              ? variant.primary.withAlpha(90)
              : Colors.white.withAlpha(60),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isPicked ? variant.primary : Colors.white,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

/// What the pick means, and Continue.
class _Footer extends StatelessWidget {
  final AppThemeVariant variant;

  final OrderSegment? picked;

  final VoidCallback onConfirm;

  const _Footer({
    required this.variant,
    required this.picked,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final picked = this.picked;

    final hint = picked == null
        ? 'Pick a segment to continue'
        : picked == OrderSegment.all
            ? 'Articles of every segment will be offered'
            : 'Only ${picked.categories.join(' and ')} articles will be '
                'offered';

    final button = _ContinueButton(
      variant: variant,
      onPressed: picked == null ? null : onConfirm,
    );

    final hintText = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          picked == null ? Icons.touch_app_outlined : Icons.info_outline,
          size: 16,
          color: Colors.white.withAlpha(200),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            hint,
            style: TextStyle(
              color: Colors.white.withAlpha(220),
              fontSize: 12.5,
            ),
          ),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 480) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: hintText),
              const SizedBox(height: 12),
              button,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: hintText),
            const SizedBox(width: 16),
            button,
          ],
        );
      },
    );
  }
}

class _ContinueButton extends StatelessWidget {
  final AppThemeVariant variant;

  final VoidCallback? onPressed;

  const _ContinueButton({required this.variant, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: isEnabled ? 1 : 0.45,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: variant.primaryFill(),
          boxShadow: [
            if (isEnabled)
              BoxShadow(
                color: variant.primary.withAlpha(110),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onPressed,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 28, vertical: 13),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Continue',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward, size: 18, color: Colors.white),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
