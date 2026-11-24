import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vardhman_b2b/api/api_activity.dart';
import 'package:vardhman_b2b/constants.dart';

/// Brand spinner: two counter-rotating gradient arcs (red outer, grey inner)
/// around a pulsing red core, like thread winding onto a spool.
class VardhmanLoader extends StatefulWidget {
  final double size;

  final String? message;

  const VardhmanLoader({super.key, this.size = 56, this.message});

  @override
  State<VardhmanLoader> createState() => _VardhmanLoaderState();
}

class _VardhmanLoaderState extends State<VardhmanLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Own layer: each animation tick repaints only the spinner, not the
    // panel or page around it.
    return RepaintBoundary(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: widget.size,
            // The painter listens to the controller and repaints without a
            // widget rebuild per frame.
            child: CustomPaint(
              painter: _SpoolPainter(progress: _controller),
            ),
          ),
          if (widget.message != null) ...[
            const SizedBox(height: 14),
            _LoadingDots(message: widget.message!, progress: _controller),
          ],
        ],
      ),
    );
  }
}

/// [message] followed by 0-3 dots; rebuilds only when the dot count changes
/// rather than every frame.
class _LoadingDots extends StatefulWidget {
  final String message;

  final Animation<double> progress;

  const _LoadingDots({required this.message, required this.progress});

  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots> {
  int _dots = 0;

  int get _currentDots => (widget.progress.value * 4).floor() % 4;

  void _onTick() {
    if (_currentDots != _dots) {
      setState(() => _dots = _currentDots);
    }
  }

  @override
  void initState() {
    super.initState();

    widget.progress.addListener(_onTick);
  }

  @override
  void dispose() {
    widget.progress.removeListener(_onTick);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      '${widget.message}${('.' * _dots).padRight(3)}',
      style: TextStyle(
        fontSize: 13,
        letterSpacing: 0.4,
        fontWeight: FontWeight.w500,
        color: VardhmanColors.darkGrey,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

class _SpoolPainter extends CustomPainter {
  final Animation<double> progress;

  _SpoolPainter({required this.progress}) : super(repaint: progress);

  void _arc(
    Canvas canvas,
    Rect rect, {
    required double start,
    required double sweep,
    required double width,
    required Color color,
  }) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: sweep,
        colors: [color.withAlpha(0), color],
        transform: GradientRotation(start),
      ).createShader(rect);

    canvas.drawArc(rect, start, sweep, false, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);

    final radius = size.shortestSide / 2;

    final angle = progress.value * 2 * math.pi;

    // Breathing sweep makes the arcs feel like they are winding.
    final breath = 0.5 + 0.5 * math.sin(angle);

    final outerWidth = radius * 0.13;

    final outerRect =
        Rect.fromCircle(center: center, radius: radius - outerWidth / 2);

    canvas.drawCircle(
      center,
      radius - outerWidth / 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = outerWidth
        ..color = VardhmanColors.dividerGrey,
    );

    _arc(
      canvas,
      outerRect,
      start: angle * 2 - math.pi / 2,
      sweep: math.pi * (0.9 + 0.6 * breath),
      width: outerWidth,
      color: VardhmanColors.red,
    );

    final innerWidth = radius * 0.1;

    _arc(
      canvas,
      Rect.fromCircle(center: center, radius: radius * 0.62),
      start: -angle * 3,
      sweep: math.pi * (1.4 - 0.6 * breath),
      width: innerWidth,
      color: VardhmanColors.darkGrey,
    );

    final coreRadius = radius * (0.16 + 0.05 * breath);

    canvas.drawCircle(
      center,
      coreRadius * 1.8,
      Paint()..color = VardhmanColors.red.withAlpha((40 * breath).round()),
    );

    canvas.drawCircle(center, coreRadius, Paint()..color = VardhmanColors.red);
  }

  @override
  bool shouldRepaint(_SpoolPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Blurs [child] and shows only the animated [VardhmanLoader] over it while
/// [isLoading]: no panel and no text. The spinner fades in and out so short
/// loads do not flash.
///
/// The blur is on [child] itself ([ImageFiltered]), not a backdrop blur over
/// the screen: the child's picture is kept in its own layer, so each spinner
/// frame does not repaint the table under it, which made the loader stutter.
/// [ImageFiltered.enabled] keeps the same widget tree loading or not, so the
/// child keeps its state (scroll position, fields).
class LoadingOverlay extends StatelessWidget {
  final bool isLoading;

  final Widget child;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: ImageFiltered(
            enabled: isLoading,
            imageFilter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
            child: RepaintBoundary(child: child),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !isLoading,
            child: AnimatedOpacity(
              opacity: isLoading ? 1 : 0,
              duration: const Duration(milliseconds: 250),
              child: isLoading
                  ? ColoredBox(
                      // A light veil so the blurred screen reads as paused.
                      color: Colors.white.withAlpha(60),
                      child: const Center(child: VardhmanLoader()),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      ],
    );
  }
}

/// Slim indeterminate bar along the top of the app, shown while any JDE
/// request is in flight. The animation only runs while requests are pending;
/// an always-repeating controller kept the app rendering frames even when
/// the bar was invisible.
class ApiActivityBar extends StatefulWidget {
  const ApiActivityBar({super.key});

  @override
  State<ApiActivityBar> createState() => _ApiActivityBarState();
}

class _ApiActivityBarState extends State<ApiActivityBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  late final Worker _pendingWorker;

  bool _isVisible = false;

  void _onPendingChanged(int pending) {
    final isBusy = pending > 0;

    if (isBusy && !_controller.isAnimating) {
      _controller.repeat();
    }

    if (isBusy != _isVisible) {
      setState(() => _isVisible = isBusy);
    }
  }

  @override
  void initState() {
    super.initState();

    _pendingWorker = ever(ApiActivity.rxPending, _onPendingChanged);

    _onPendingChanged(ApiActivity.rxPending.value);
  }

  @override
  void dispose() {
    _pendingWorker.dispose();

    _controller.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedOpacity(
        opacity: _isVisible ? 1 : 0,
        duration: const Duration(milliseconds: 300),
        // Stop the ticker once fully faded out.
        onEnd: () {
          if (!_isVisible) {
            _controller.stop();
          }
        },
        child: SizedBox(
          height: 3,
          width: double.infinity,
          child: CustomPaint(
            painter: _ActivityBarPainter(progress: _controller),
          ),
        ),
      ),
    );
  }
}

class _ActivityBarPainter extends CustomPainter {
  final Animation<double> progress;

  _ActivityBarPainter({required this.progress}) : super(repaint: progress);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = VardhmanColors.red.withAlpha(30),
    );

    final eased = Curves.easeInOutCubic.transform(progress.value);

    final segment = size.width * 0.35;

    final left = -segment + (size.width + segment) * eased;

    final rect = Rect.fromLTWH(left, 0, segment, size.height);

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(size.height)),
      Paint()
        ..shader = LinearGradient(
          colors: [
            VardhmanColors.red.withAlpha(0),
            VardhmanColors.red,
            VardhmanColors.orange,
          ],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_ActivityBarPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
