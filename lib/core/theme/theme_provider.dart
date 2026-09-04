import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Current [ThemeMode] of the application. Defaults to [ThemeMode.light].
///
/// Riverpod is the project's single state-management solution (chosen in
/// Task 02); the theme mode is the first consumer so the pattern is in place
/// before feature state arrives in later tasks.
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.light);
