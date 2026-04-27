import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Persisted ThemeMode chosen by the user. Stored alongside the rest of
/// the profile prefs in the existing `userProfile` Hive box so we don't
/// need to open another box at startup.
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(_load());

  static ThemeMode _load() {
    if (!Hive.isBoxOpen(_box)) return ThemeMode.system;
    final stored = Hive.box<dynamic>(_box).get(_key) as String?;
    return _fromString(stored);
  }

  static const _box = 'userProfile';
  static const _key = 'themeMode';

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    await Hive.box<dynamic>(_box).put(_key, _toString(mode));
  }

  static String _toString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  static ThemeMode _fromString(String? s) {
    switch (s) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});
