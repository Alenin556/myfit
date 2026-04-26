import 'package:flutter/material.dart';

/// My Pro Health Nutrition — светлая: белый фон, синие акценты;
/// тёмная: чёрный фон, жёлтые акценты.
class AppTheme {
  static const Color lightAccent = Color(0xFF1565C0);
  static const Color darkAccent = Color(0xFFFFC107);

  static ThemeData get light {
    final scheme = ColorScheme(
      brightness: Brightness.light,
      primary: lightAccent,
      onPrimary: Colors.white,
      secondary: const Color(0xFF0D47A1),
      onSecondary: Colors.white,
      error: const Color(0xFFB00020),
      onError: Colors.white,
      surface: Colors.white,
      onSurface: const Color(0xFF0D0D0D),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF0D0D0D),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: const Color(0xFFF5F5F5),
        selectedIconTheme: const IconThemeData(color: lightAccent),
        selectedLabelTextStyle: const TextStyle(color: lightAccent),
        indicatorColor: lightAccent.withValues(alpha: 0.12),
      ),
    );
  }

  static ThemeData get dark {
    const bg = Color(0xFF000000);
    final scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: darkAccent,
      onPrimary: Color(0xFF1A1A1A),
      secondary: darkAccent,
      onSecondary: Color(0xFF1A1A1A),
      error: Color(0xFFCF6679),
      onError: Colors.black,
      surface: bg,
      onSurface: Color(0xFFF5F5F5),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        foregroundColor: Color(0xFFF5F5F5),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: Color(0xFF121212),
        selectedIconTheme: IconThemeData(color: darkAccent),
        selectedLabelTextStyle: TextStyle(color: darkAccent),
        indicatorColor: Color(0x33FFC107),
      ),
    );
  }
}
