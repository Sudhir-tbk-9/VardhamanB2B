import 'package:flutter/widgets.dart';
import 'package:vardhman_b2b/app/theme_variants.dart';

/// Heading row of every table, in the active theme's primary gradient (like
/// the primary buttons), behind white header text. Read at build time, so a
/// theme switch, which rebuilds everything on screen, repaints it.
class TableHeader {
  /// For DataTable2 / PaginatedDataTable2 (`headingRowDecoration`); used
  /// instead of `headingRowColor`, as a colour and a gradient cannot be
  /// combined.
  static BoxDecoration get decoration =>
      BoxDecoration(gradient: ThemeVariants.current.primaryFill());

  /// For a plain DataTable, which takes only a colour.
  static WidgetStateProperty<Color> get color =>
      WidgetStatePropertyAll(ThemeVariants.current.primary);
}
