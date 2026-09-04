import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/responsive/breakpoint.dart';
import '../../core/theme/theme_provider.dart';
import 'theme_toggle_button.dart';

/// Metadata for one top-level destination shown in the responsive shell.
class ShellDestination {
  const ShellDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.builder,
  });

  /// Destination title (also used as the AppBar title while selected).
  final String label;

  /// Unselected [NavigationDestination]/[NavigationRailDestination] icon.
  final IconData icon;

  /// Selected-state icon.
  final IconData selectedIcon;

  /// Builds the destination's page content.
  final WidgetBuilder builder;
}

/// Root application shell.
///
/// Adapts its navigation and content spacing to the available width (see
/// [Breakpoint]):
///
/// * **mobile** (< 600)  — bottom [NavigationBar];
/// * **tablet**  (600–1024) — compact [NavigationRail] (icons + labels below);
/// * **desktop** (> 1024)  — extended [NavigationRail] (labels beside icons)
///   with more generous content padding.
class AppShell extends StatefulWidget {
  const AppShell({super.key, this.initialIndex = 0});

  /// Index of the destination shown on first build.
  final int initialIndex;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static final List<ShellDestination> _destinations = <ShellDestination>[
    ShellDestination(
      label: 'Home',
      icon: Icons.description_outlined,
      selectedIcon: Icons.description,
      builder: (BuildContext _) => const _HomeView(),
    ),
    ShellDestination(
      label: 'Settings',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      builder: (BuildContext _) => const _SettingsView(),
    ),
  ];

  late int _selectedIndex = widget.initialIndex;

  void _select(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final Breakpoint breakpoint = breakpointOf(context);
    final ShellDestination destination = _destinations[_selectedIndex];

    final Widget content = _ContentFrame(
      breakpoint: breakpoint,
      child: destination.builder(context),
    );

    final Widget body = switch (breakpoint) {
      Breakpoint.mobile => content,
      Breakpoint.tablet || Breakpoint.desktop => Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _SideRail(
              breakpoint: breakpoint,
              selectedIndex: _selectedIndex,
              onDestinationSelected: _select,
              destinations: _destinations,
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(child: content),
          ],
        ),
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(destination.label),
        actions: const <Widget>[ThemeToggleButton()],
      ),
      body: body,
      bottomNavigationBar: breakpoint == Breakpoint.mobile
          ? _BottomBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: _select,
              destinations: _destinations,
            )
          : null,
    );
  }
}

/// Bottom navigation bar used on mobile widths.
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<ShellDestination> destinations;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      destinations: <NavigationDestination>[
        for (final ShellDestination d in destinations)
          NavigationDestination(
            icon: Icon(d.icon),
            selectedIcon: Icon(d.selectedIcon),
            label: d.label,
          ),
      ],
    );
  }
}

/// Side rail used on tablet and desktop widths.
class _SideRail extends StatelessWidget {
  const _SideRail({
    required this.breakpoint,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
  });

  final Breakpoint breakpoint;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<ShellDestination> destinations;

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = breakpoint == Breakpoint.desktop;
    return NavigationRail(
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      extended: isDesktop,
      labelType: isDesktop ? null : NavigationRailLabelType.all,
      destinations: <NavigationRailDestination>[
        for (final ShellDestination d in destinations)
          NavigationRailDestination(
            icon: Icon(d.icon),
            selectedIcon: Icon(d.selectedIcon),
            label: Text(d.label),
          ),
      ],
    );
  }
}

/// Applies breakpoint-aware padding around the destination content so the
/// layout scales correctly across form factors.
class _ContentFrame extends StatelessWidget {
  const _ContentFrame({required this.breakpoint, required this.child});

  final Breakpoint breakpoint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final double horizontal = switch (breakpoint) {
      Breakpoint.mobile => 16,
      Breakpoint.tablet => 24,
      Breakpoint.desktop => 48,
    };
    final double vertical = switch (breakpoint) {
      Breakpoint.mobile => 16,
      Breakpoint.tablet => 24,
      Breakpoint.desktop => 32,
    };
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical),
      child: child,
    );
  }
}

/// Placeholder home content. The PDF viewer and editing workspace replace this
/// in later tasks (Tasks 04+).
class _HomeView extends StatelessWidget {
  const _HomeView();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextTheme textTheme = theme.textTheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.picture_as_pdf_outlined,
              size: 96,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'PDF e-Sign',
              style: textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text(
              'Open a PDF document to add text fields and signatures, then '
              'export a signed copy with a clean audit trail.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Placeholder settings content. Task 03 owns the appearance/theme control;
/// further settings arrive with later features.
class _SettingsView extends ConsumerWidget {
  const _SettingsView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          children: <Widget>[
            Text(
              'Appearance',
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.dark_mode_outlined),
              title: const Text('Dark theme'),
              subtitle: const Text('Use the dark color scheme'),
              value: isDark,
              onChanged: (bool dark) {
                ref.read(themeModeProvider.notifier).state =
                    dark ? ThemeMode.dark : ThemeMode.light;
              },
            ),
          ],
        ),
      ),
    );
  }
}
