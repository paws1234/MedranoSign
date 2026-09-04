// Integration/widget tests for the responsive shell (Task 03).
//
// The shell is pumped at each breakpoint width and the correct adaptive
// navigation (bottom bar vs. compact rail vs. extended rail) is asserted,
// together with "no overflow" checks and light/dark theme switching.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pdf_esign_app/app.dart';
import 'package:pdf_esign_app/shared/widgets/theme_toggle_button.dart';

/// Pumps the full app at a fixed logical [size].
Future<void> _pumpApp(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(const ProviderScope(child: PdfEsignApp()));
  await tester.pumpAndSettle();
}

ThemeMode _appThemeMode(WidgetTester tester) =>
    tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode!;

void main() {
  group('responsive layout', () {
    testWidgets('mobile width shows a bottom navigation bar', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester, const Size(400, 800));

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tablet width shows a compact navigation rail', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester, const Size(800, 800));

      final NavigationRail rail = tester.widget<NavigationRail>(
        find.byType(NavigationRail),
      );
      expect(rail.extended, isFalse);
      expect(find.byType(NavigationBar), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('desktop width shows an extended navigation rail', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester, const Size(1200, 900));

      final NavigationRail rail = tester.widget<NavigationRail>(
        find.byType(NavigationRail),
      );
      expect(rail.extended, isTrue);
      expect(find.byType(NavigationBar), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders without overflow across a range of widths', (
      WidgetTester tester,
    ) async {
      for (final double width in <double>[360, 400, 600, 800, 1024, 1200, 1440]) {
        await _pumpApp(tester, Size(width, 800));
        expect(
          tester.takeException(),
          isNull,
          reason: 'layout exception at width $width',
        );
      }
    });

    testWidgets('bottom bar switches destination on mobile', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester, const Size(400, 800));

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(find.text('Dark theme'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('side rail switches destination on desktop', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester, const Size(1200, 900));

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(find.text('Dark theme'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('theming', () {
    testWidgets('app-bar toggle switches light and dark without crash', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester, const Size(800, 800));

      expect(_appThemeMode(tester), ThemeMode.light);

      await tester.tap(find.byType(ThemeToggleButton));
      await tester.pumpAndSettle();
      expect(_appThemeMode(tester), ThemeMode.dark);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byType(ThemeToggleButton));
      await tester.pumpAndSettle();
      expect(_appThemeMode(tester), ThemeMode.light);
    });

    testWidgets('settings switch toggles the dark theme', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester, const Size(1200, 900));

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(_appThemeMode(tester), ThemeMode.light);

      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(_appThemeMode(tester), ThemeMode.dark);
      expect(tester.takeException(), isNull);
    });
  });
}
