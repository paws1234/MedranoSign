import 'package:flutter/material.dart';

/// Central application theme: Material 3 light and dark [ThemeData] for the
/// responsive shell (Task 03). Brand color and component defaults live here
/// so later feature tasks can build on a single source of truth.
abstract final class AppTheme {
  /// Brand seed color shared by both schemes.
  static const Color seedColor = Color(0xFF3949AB);

  /// Light color-scheme theme.
  static ThemeData get light => _build(Brightness.light);

  /// Dark color-scheme theme.
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.secondaryContainer,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.secondaryContainer,
      ),
    );
  }
}
