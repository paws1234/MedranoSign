import 'package:flutter/widgets.dart';

/// Device form-factor classification used by the responsive shell.
///
/// Classification is driven by the *available horizontal space* in logical
/// pixels (the width the layout will actually be laid out within):
///
/// * [Breakpoint.mobile] — widths below 600 px (phones).
/// * [Breakpoint.tablet] — widths from 600 px up to and including 1024 px.
/// * [Breakpoint.desktop] — widths above 1024 px.
enum Breakpoint { mobile, tablet, desktop }

/// Layout breakpoint thresholds in logical pixels.
///
/// Ranges follow the project convention: mobile < 600, tablet 600–1024,
/// desktop > 1024 (see `.claude/Plan.md` Milestone 1.3).
abstract final class Breakpoints {
  /// First width that is treated as a tablet layout (mobile is below this).
  static const double tabletMin = 600;

  /// Last width still treated as a tablet layout (desktop is above this).
  static const double tabletMax = 1024;
}

/// Classifies a horizontal [width] (logical pixels) into a [Breakpoint].
///
/// * `width <  600`            → [Breakpoint.mobile]
/// * `600 <= width <= 1024`    → [Breakpoint.tablet]
/// * `width >  1024`           → [Breakpoint.desktop]
Breakpoint breakpointOfWidth(double width) {
  if (width < Breakpoints.tabletMin) {
    return Breakpoint.mobile;
  }
  if (width <= Breakpoints.tabletMax) {
    return Breakpoint.tablet;
  }
  return Breakpoint.desktop;
}

/// Classifies the current screen width (from [MediaQuery]) into a
/// [Breakpoint].
Breakpoint breakpointOf(BuildContext context) {
  return breakpointOfWidth(MediaQuery.sizeOf(context).width);
}
