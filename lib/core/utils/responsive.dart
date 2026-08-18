import 'package:flutter/widgets.dart';

/// Standard Material 3 layout breakpoints, extended for tablet/desk form
/// factors used by Quill on iPad and desktop.
enum WindowSize {
  /// Phone-portrait and below.
  compact,

  /// Phone-landscape, small tablets.
  medium,

  /// Tablet-portrait (e.g. iPad 9.7" portrait, 11").
  expanded,

  /// Tablet-landscape, desktop.
  large,

  /// Large desktop monitors.
  extraLarge,
}

class Breakpoints {
  static const double medium = 600;
  static const double expanded = 840;
  static const double large = 1200;
  static const double extraLarge = 1600;
}

extension ResponsiveContext on BuildContext {
  WindowSize get windowSize {
    final width = MediaQuery.sizeOf(this).width;
    if (width < Breakpoints.medium) return WindowSize.compact;
    if (width < Breakpoints.expanded) return WindowSize.medium;
    if (width < Breakpoints.large) return WindowSize.expanded;
    if (width < Breakpoints.extraLarge) return WindowSize.large;
    return WindowSize.extraLarge;
  }

  bool get isCompact => windowSize == WindowSize.compact;
  bool get isMedium => windowSize == WindowSize.medium;
  bool get isExpanded => windowSize.index >= WindowSize.expanded.index;
  bool get isLarge => windowSize.index >= WindowSize.large.index;

  /// `true` when we should show a permanent navigation rail (tablet/desktop).
  bool get showPermanentNavRail =>
      windowSize == WindowSize.expanded || windowSize == WindowSize.large;

  /// `true` when we should show a persistent left + right two-pane layout.
  bool get showTwoPane => isExpanded;

  /// Inner content max-width for readable prose (M3 guideline: 600-720dp).
  double get readableMaxWidth => 720;
}