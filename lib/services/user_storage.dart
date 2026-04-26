import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_profile.dart';

class UserStorage {
  UserStorage._(this._p);

  final SharedPreferences _p;

  static const _kUser = 'user_profile_json';
  static const _kTheme = 'app_theme_mode';
  static const _kMealPlan = 'has_meal_plan';
  static const _kSession = 'session_active';
  /// JSON: `{ "yyyy-MM-dd": [ { food diary entry }, ... ] }`
  static const _kFoodDiaryV1 = 'food_diary_v1';

  static Future<UserStorage> open() async {
    final p = await SharedPreferences.getInstance();
    return UserStorage._(p);
  }

  UserProfile? loadUser() {
    final raw = _p.getString(_kUser);
    if (raw == null || raw.isEmpty) return null;
    try {
      return UserProfile.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map<dynamic, dynamic>),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> saveUser(UserProfile? u) async {
    if (u == null) {
      await _p.remove(_kUser);
      return;
    }
    await _p.setString(_kUser, jsonEncode(u.toJson()));
  }

  ThemeMode loadTheme() {
    final t = _p.getString(_kTheme);
    switch (t) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      default:
        return ThemeMode.light;
    }
  }

  Future<void> saveTheme(ThemeMode m) async {
    final v = m == ThemeMode.dark ? 'dark' : 'light';
    await _p.setString(_kTheme, v);
  }

  bool loadHasMealPlan() => _p.getBool(_kMealPlan) ?? false;

  Future<void> saveHasMealPlan(bool v) => _p.setBool(_kMealPlan, v);

  /// [null] нет в prefs — миграция, считаем, что сессия есть.
  bool? loadSessionActive() {
    if (!_p.containsKey(_kSession)) return null;
    return _p.getBool(_kSession);
  }

  Future<void> saveSessionActive(bool value) => _p.setBool(_kSession, value);

  String? loadFoodDiaryV1() {
    return _p.getString(_kFoodDiaryV1);
  }

  Future<void> saveFoodDiaryV1(String? json) async {
    if (json == null || json.isEmpty) {
      await _p.remove(_kFoodDiaryV1);
    } else {
      await _p.setString(_kFoodDiaryV1, json);
    }
  }
}
