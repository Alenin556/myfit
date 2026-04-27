import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Синхронизирует иконку на рабочем столе с выбранной в приложении темой (светлая/тёмная),
/// а не с системной тёмной темой.
class AppIcon {
  static const _channel = MethodChannel('com.example.myfit/app_icon');

  static Future<void> syncWithTheme(ThemeMode mode) async {
    if (kIsWeb) return;
    final variant = mode == ThemeMode.dark ? 'dark' : 'light';
    try {
      await _channel.invokeMethod<void>(
        'setIcon',
        <String, Object?>{'variant': variant},
      );
    } on MissingPluginException {
      // Десктоп / тесты без нативной стороны.
    } on PlatformException catch (e) {
      debugPrint('AppIcon: ${e.message}');
    }
  }
}
