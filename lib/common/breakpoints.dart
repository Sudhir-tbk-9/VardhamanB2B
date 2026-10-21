import 'package:flutter/widgets.dart';

/// Window widths, in logical pixels, at which the portal changes layout.
abstract final class Breakpoints {
  /// Below this the window is phone sized: the nav rail moves into a drawer
  /// and dialogs fill the screen.
  static const double compact = 600;

  /// A list and its details sit side by side only when the tab body is at
  /// least this wide; below it they show one at a time (MasterDetailLayout).
  static const double split = 840;

  /// A form row ([AdaptiveRow]) keeps its fields side by side only when it
  /// is at least this wide.
  static const double formRow = 720;
}

extension BreakpointsContext on BuildContext {
  /// Whether the window is phone sized ([Breakpoints.compact]).
  bool get isCompact => MediaQuery.sizeOf(this).width < Breakpoints.compact;
}
