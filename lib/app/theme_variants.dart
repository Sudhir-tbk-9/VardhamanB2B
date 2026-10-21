import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Decorative layer drawn over the accent gradient (nav rail, top bar and the
/// theme preview tiles).
enum ThemePattern { none, weave, stars, waves }

/// One colour scheme the user can pick. [primary] is the brand colour
/// (buttons, selection), [accent] the dark tone for headers and text,
/// [surface] the light tone for panels and dividers.
class AppThemeVariant {
  final String id;
  final String name;
  final IconData icon;
  final Color primary;
  final Color accent;
  final Color surface;
  final Color success;
  final Color warning;
  final Color error;

  /// Gradient stops for primary buttons, and for the nav rail and top bar.
  final List<Color> primaryGradient;
  final List<Color> accentGradient;

  /// Optional pattern and asset image layered over [accentGradient].
  final ThemePattern pattern;
  final String? backgroundImage;

  const AppThemeVariant({
    required this.id,
    required this.name,
    required this.icon,
    required this.primary,
    required this.accent,
    required this.surface,
    required this.success,
    required this.warning,
    required this.error,
    required this.primaryGradient,
    required this.accentGradient,
    this.pattern = ThemePattern.none,
    this.backgroundImage,
  });

  bool get hasBackdrop =>
      pattern != ThemePattern.none || backgroundImage != null;

  /// Fill for primary buttons.
  Gradient primaryFill({
    AlignmentGeometry begin = Alignment.centerLeft,
    AlignmentGeometry end = Alignment.centerRight,
  }) =>
      LinearGradient(begin: begin, end: end, colors: primaryGradient);

  /// Fill for the nav rail / top bar.
  Gradient accentFill({
    AlignmentGeometry begin = Alignment.topCenter,
    AlignmentGeometry end = Alignment.bottomCenter,
  }) =>
      LinearGradient(begin: begin, end: end, colors: accentGradient);
}

/// Success / warning colours, which [ColorScheme] has no slot for. Read them
/// in widgets with `Theme.of(context).extension<StatusColors>()!`.
class StatusColors extends ThemeExtension<StatusColors> {
  final Color success;
  final Color warning;

  const StatusColors({required this.success, required this.warning});

  @override
  StatusColors copyWith({Color? success, Color? warning}) => StatusColors(
        success: success ?? this.success,
        warning: warning ?? this.warning,
      );

  @override
  StatusColors lerp(StatusColors? other, double t) => other == null
      ? this
      : StatusColors(
          success: Color.lerp(success, other.success, t)!,
          warning: Color.lerp(warning, other.warning, t)!,
        );
}

class ThemeVariants {
  /// The original Vardhman palette; the default.
  static const vardhmanRed = AppThemeVariant(
    id: 'vardhman_red',
    name: 'Vardhman Red',
    icon: Icons.whatshot_rounded,
    primary: Color(0xFFE61E31),
    accent: Color(0xFF424242),
    surface: Color(0xFFE8E8E8),
    success: Color(0xFF008B47),
    warning: Color(0xFFFFB300),
    error: Color(0xFFE61E31),
    primaryGradient: [Color(0xFFE61E31), Color(0xFFFF5A5F)],
    accentGradient: [Color(0xFF333333), Color(0xFF4A4A4A)],
  );

  static const all = <AppThemeVariant>[
    vardhmanRed,
    AppThemeVariant(
      id: 'indigo_navy',
      name: 'Indigo Navy',
      icon: Icons.anchor_rounded,
      primary: Color(0xFF283593),
      accent: Color(0xFF1E2A3A),
      surface: Color(0xFFE3E7F1),
      success: Color(0xFF2E7D32),
      warning: Color(0xFFF9A825),
      error: Color(0xFFC62828),
      primaryGradient: [Color(0xFF283593), Color(0xFF3F51B5)],
      accentGradient: [Color(0xFF141E30), Color(0xFF243B55)],
    ),
    AppThemeVariant(
      id: 'ocean_teal',
      name: 'Ocean Teal',
      icon: Icons.water_drop_rounded,
      primary: Color(0xFF00897B),
      accent: Color(0xFF263238),
      surface: Color(0xFFE0F2F1),
      success: Color(0xFF2E7D32),
      warning: Color(0xFFFFA000),
      error: Color(0xFFD32F2F),
      primaryGradient: [Color(0xFF00897B), Color(0xFF26C6DA)],
      accentGradient: [Color(0xFF1F2D33), Color(0xFF134E4A)],
    ),
    AppThemeVariant(
      id: 'royal_purple',
      name: 'Royal Purple',
      icon: Icons.diamond_rounded,
      primary: Color(0xFF6A1B9A),
      accent: Color(0xFF2D2438),
      surface: Color(0xFFEDE7F6),
      success: Color(0xFF388E3C),
      warning: Color(0xFFFFB300),
      error: Color(0xFFD32F2F),
      primaryGradient: [Color(0xFF6A1B9A), Color(0xFFAB47BC)],
      accentGradient: [Color(0xFF2D2438), Color(0xFF4A2C5E)],
    ),
    AppThemeVariant(
      id: 'charcoal_gold',
      name: 'Charcoal Gold',
      icon: Icons.workspace_premium_rounded,
      primary: Color(0xFFB07D12),
      accent: Color(0xFF212121),
      surface: Color(0xFFEFEBE4),
      success: Color(0xFF2E7D32),
      warning: Color(0xFFEF6C00),
      error: Color(0xFFC62828),
      primaryGradient: [Color(0xFF9C6B0E), Color(0xFFD4A537)],
      accentGradient: [Color(0xFF1A1A1A), Color(0xFF3A3226)],
    ),
    AppThemeVariant(
      id: 'forest_green',
      name: 'Forest Green',
      icon: Icons.forest_rounded,
      primary: Color(0xFF2E7D32),
      accent: Color(0xFF1B2E21),
      surface: Color(0xFFE6EFE7),
      success: Color(0xFF00796B),
      warning: Color(0xFFF9A825),
      error: Color(0xFFC62828),
      primaryGradient: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
      accentGradient: [Color(0xFF14261A), Color(0xFF2C4A32)],
    ),
    AppThemeVariant(
      id: 'sunset_blaze',
      name: 'Sunset Blaze',
      icon: Icons.wb_twilight_rounded,
      primary: Color(0xFFE53935),
      accent: Color(0xFF2B1B2E),
      surface: Color(0xFFFBE9EC),
      success: Color(0xFF2E7D32),
      warning: Color(0xFFFB8C00),
      error: Color(0xFFC62828),
      primaryGradient: [Color(0xFFFF512F), Color(0xFFDD2476)],
      accentGradient: [Color(0xFF2B1B2E), Color(0xFF5A1E44)],
    ),
    AppThemeVariant(
      id: 'ocean_aurora',
      name: 'Ocean Aurora',
      icon: Icons.waves_rounded,
      primary: Color(0xFF1565C0),
      accent: Color(0xFF0F2027),
      surface: Color(0xFFE1F5FE),
      success: Color(0xFF00897B),
      warning: Color(0xFFFFA000),
      error: Color(0xFFD32F2F),
      primaryGradient: [Color(0xFF1565C0), Color(0xFF00ACC1)],
      accentGradient: [
        Color(0xFF0F2027),
        Color(0xFF203A43),
        Color(0xFF2C5364),
      ],
    ),
    AppThemeVariant(
      id: 'royal_twilight',
      name: 'Royal Twilight',
      icon: Icons.nightlight_round,
      primary: Color(0xFF6A1FD1),
      accent: Color(0xFF1A1033),
      surface: Color(0xFFEDE7F6),
      success: Color(0xFF43A047),
      warning: Color(0xFFFFB300),
      error: Color(0xFFE53935),
      primaryGradient: [Color(0xFF7F00FF), Color(0xFFE100FF)],
      accentGradient: [
        Color(0xFF0F0C29),
        Color(0xFF302B63),
        Color(0xFF24243E),
      ],
    ),
    // Patterned / image themes.
    AppThemeVariant(
      id: 'silk_weave',
      name: 'Silk Weave',
      icon: Icons.texture_rounded,
      primary: Color(0xFFAD1457),
      accent: Color(0xFF3E1F35),
      surface: Color(0xFFFCE4EC),
      success: Color(0xFF2E7D32),
      warning: Color(0xFFFFA000),
      error: Color(0xFFC62828),
      primaryGradient: [Color(0xFFAD1457), Color(0xFFEC407A)],
      accentGradient: [Color(0xFF3E1F35), Color(0xFF6A2C55)],
      pattern: ThemePattern.weave,
    ),
    AppThemeVariant(
      id: 'midnight_stars',
      name: 'Midnight Stars',
      icon: Icons.auto_awesome_rounded,
      primary: Color(0xFF3949AB),
      accent: Color(0xFF151A3A),
      surface: Color(0xFFE8EAF6),
      success: Color(0xFF43A047),
      warning: Color(0xFFFFB300),
      error: Color(0xFFE53935),
      primaryGradient: [Color(0xFF3949AB), Color(0xFF8E24AA)],
      accentGradient: [
        Color(0xFF0B1026),
        Color(0xFF1B2150),
        Color(0xFF2B1F4A),
      ],
      pattern: ThemePattern.stars,
    ),
    AppThemeVariant(
      id: 'thread_spectrum',
      name: 'Thread Spectrum',
      icon: Icons.color_lens_rounded,
      primary: Color(0xFF00838F),
      accent: Color(0xFF1C2B36),
      surface: Color(0xFFE0F2F1),
      success: Color(0xFF2E7D32),
      warning: Color(0xFFFB8C00),
      error: Color(0xFFD32F2F),
      primaryGradient: [Color(0xFF00838F), Color(0xFFE64A19)],
      accentGradient: [Color(0xE61C2B36), Color(0xCC263D4A)],
      pattern: ThemePattern.waves,
      backgroundImage: 'assets/home_background.jpg',
    ),
  ];

  /// Variant in use; read by [VardhmanColors] so existing widgets follow it.
  static AppThemeVariant current = vardhmanRed;

  static AppThemeVariant byId(String? id) =>
      all.firstWhereOrNull((variant) => variant.id == id) ?? vardhmanRed;

  /// ThemeData is costly to build; each variant's is built once.
  static final _themeDataCache = <String, ThemeData>{};

  static ThemeData themeData(AppThemeVariant variant) =>
      _themeDataCache[variant.id] ??= _buildThemeData(variant);

  static ThemeData _buildThemeData(AppThemeVariant variant) {
    final outline = OutlineInputBorder(
      borderSide: BorderSide(color: variant.surface),
    );

    return ThemeData(
      primaryColor: variant.primary,
      colorScheme: ColorScheme.fromSwatch().copyWith(
        primary: variant.primary,
        secondary: variant.accent,
        surface: Colors.white,
        surfaceContainerHighest: variant.surface,
        error: variant.error,
      ),
      extensions: [
        StatusColors(success: variant.success, warning: variant.warning),
      ],
      highlightColor: variant.accent,
      splashColor: variant.primary,
      buttonTheme: ButtonThemeData(buttonColor: variant.primary),
      focusColor: variant.accent,
      hoverColor: variant.primary.withAlpha(32),
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: variant.primary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: variant.accent),
        ),
        enabledBorder: outline,
        errorBorder: OutlineInputBorder(
          borderSide: BorderSide(color: variant.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderSide: BorderSide(color: variant.error),
        ),
        labelStyle: TextStyle(color: variant.accent),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: variant.primary,
        selectionColor: variant.surface,
        selectionHandleColor: variant.primary,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.all(variant.primary),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.all(variant.primary),
      ),
      scrollbarTheme: const ScrollbarThemeData(
        thumbVisibility: WidgetStatePropertyAll(true),
        trackVisibility: WidgetStatePropertyAll(true),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(variant.primary),
        trackColor: WidgetStateProperty.all(variant.primary.withAlpha(127)),
      ),
    );
  }
}

/// Holds the chosen variant and persists it in SharedPreferences.
class ThemeController extends GetxController {
  static const _prefsKey = 'themeVariant';

  final _sharedPrefs = Get.find<SharedPreferences>();

  late final rxVariant =
      ThemeVariants.byId(_sharedPrefs.getString(_prefsKey)).obs;

  ThemeController() {
    ThemeVariants.current = rxVariant.value;
  }

  ThemeData get themeData => ThemeVariants.themeData(rxVariant.value);

  void select(AppThemeVariant variant) {
    if (variant.id == rxVariant.value.id) {
      return;
    }

    ThemeVariants.current = variant;

    rxVariant.value = variant;

    // Widgets that read VardhmanColors directly only pick up the new colours
    // on rebuild. Mark every element dirty for one rebuild; unlike
    // Get.forceAppUpdate (a hot-reload style reassemble) this does not also
    // force every render object to re-layout.
    void markNeedsBuild(Element element) {
      element.markNeedsBuild();

      element.visitChildren(markNeedsBuild);
    }

    WidgetsBinding.instance.rootElement?.visitChildren(markNeedsBuild);

    // Saving does not need to hold up the switch.
    _sharedPrefs.setString(_prefsKey, variant.id);
  }
}

/// [variant]'s accent gradient with its pattern and background image, as
/// used behind the nav rail, top bar and theme previews. Painted once into
/// its own layer, so it costs nothing on later frames.
class ThemeBackdrop extends StatelessWidget {
  final AppThemeVariant variant;

  final AlignmentGeometry begin;

  final AlignmentGeometry end;

  final Widget? child;

  const ThemeBackdrop({
    super.key,
    required this.variant,
    this.begin = Alignment.topCenter,
    this.end = Alignment.bottomCenter,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final image = variant.backgroundImage;

    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: variant.accent,
          image: image == null
              ? null
              : DecorationImage(
                  // The asset is several megapixels; decode a small copy.
                  image: ResizeImage(AssetImage(image), width: 640),
                  fit: BoxFit.cover,
                ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: variant.accentFill(begin: begin, end: end),
          ),
          child: CustomPaint(
            painter: variant.pattern == ThemePattern.none
                ? null
                : ThemePatternPainter(variant.pattern),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Draws [pattern] in translucent white.
class ThemePatternPainter extends CustomPainter {
  final ThemePattern pattern;

  ThemePatternPainter(this.pattern);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);

    switch (pattern) {
      case ThemePattern.weave:
        _paintWeave(canvas, size);
      case ThemePattern.stars:
        _paintStars(canvas, size);
      case ThemePattern.waves:
        _paintWaves(canvas, size);
      case ThemePattern.none:
        break;
    }
  }

  /// Diagonal threads crossing over and under, like woven cloth.
  void _paintWeave(Canvas canvas, Size size) {
    const gap = 12.0;

    final warp = Paint()
      ..color = Colors.white.withAlpha(28)
      ..strokeWidth = 3;

    final weft = Paint()
      ..color = Colors.white.withAlpha(16)
      ..strokeWidth = 1.5;

    final span = size.width + size.height;

    for (var d = -size.height; d < span; d += gap) {
      canvas.drawLine(Offset(d, 0), Offset(d + size.height, size.height), warp);
      canvas.drawLine(Offset(d + size.height, 0), Offset(d, size.height), weft);
    }
  }

  /// Fixed-seed scatter of dots with a few four-point sparkles.
  void _paintStars(Canvas canvas, Size size) {
    final random = math.Random(7);

    final paint = Paint();

    final count = (size.width * size.height / 900).clamp(12, 600).round();

    for (var i = 0; i < count; i++) {
      final center = Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height,
      );

      final radius = 0.4 + random.nextDouble() * 1.2;

      paint.color = Colors.white.withAlpha(40 + random.nextInt(120));

      if (i % 23 == 0) {
        final r = radius * 4;

        final sparkle = Path()
          ..moveTo(center.dx, center.dy - r)
          ..quadraticBezierTo(center.dx, center.dy, center.dx + r, center.dy)
          ..quadraticBezierTo(center.dx, center.dy, center.dx, center.dy + r)
          ..quadraticBezierTo(center.dx, center.dy, center.dx - r, center.dy)
          ..quadraticBezierTo(center.dx, center.dy, center.dx, center.dy - r);

        canvas.drawPath(sparkle, paint);
      } else {
        canvas.drawCircle(center, radius, paint);
      }
    }
  }

  /// Flowing horizontal lines, like threads unwinding.
  void _paintWaves(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withAlpha(30);

    const gap = 14.0;

    for (var y = -gap; y < size.height + gap; y += gap) {
      final path = Path()..moveTo(0, y);

      for (var x = 0.0; x <= size.width; x += 6) {
        path.lineTo(x, y + math.sin(x / 22 + y / 40) * 4);
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(ThemePatternPainter oldDelegate) =>
      oldDelegate.pattern != pattern;
}
