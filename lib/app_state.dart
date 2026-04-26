import 'package:flutter/material.dart';

import 'auth/local_auth.dart';
import 'models/user_profile.dart';
import 'services/user_storage.dart';

class AppState extends ChangeNotifier {
  AppState(this._storage);

  final UserStorage _storage;

  UserProfile? _user;
  ThemeMode _themeMode = ThemeMode.light;
  bool _hasMealPlan = false;
  bool _ready = false;
  /// Онбординг без [Navigator.push], чтобы смена [home] не оставляла лишние маршруты.
  bool _onboarding = false;
  /// Локальная сессия. Пока [true] и профиль загружен — пользователь в приложении.
  bool _sessionActive = true;

  UserProfile? get user => _user;
  ThemeMode get themeMode => _themeMode;
  bool get hasMealPlan => _hasMealPlan;
  bool get ready => _ready;
  bool get isOnboarding => _onboarding;
  bool get sessionActive => _sessionActive;

  /// Профиль есть и сессия не завершена (в т.ч. после «Выйти»).
  bool get isLoggedIn => _user != null && _sessionActive;

  int _mealPlanRefreshSeed = 0;
  /// Счётчик пересборки рациона (кнопка «Обновить план» на главной).
  int get mealPlanRefreshSeed => _mealPlanRefreshSeed;

  void refreshMealPlan() {
    _mealPlanRefreshSeed++;
    notifyListeners();
  }

  /// Сброс состояния «план готов» и вариации меню — для сценария «Новый план».
  Future<void> resetMealPlanWorkspace() async {
    _mealPlanRefreshSeed = 0;
    _hasMealPlan = false;
    await _storage.saveHasMealPlan(false);
    notifyListeners();
  }

  Future<void> init() async {
    _user = _storage.loadUser();
    _themeMode = _storage.loadTheme();
    _hasMealPlan = _storage.loadHasMealPlan();
    final s = _storage.loadSessionActive();
    // Нет ключа: считаем сессию активной только при наличии профиля (миграция).
    _sessionActive = s ?? (_user != null);
    _ready = true;
    notifyListeners();
  }

  /// Перезагрузить профиль с диска (кнопка «Войти»).
  void refreshUserFromStorage() {
    _user = _storage.loadUser();
    notifyListeners();
  }

  Future<void> setTheme(ThemeMode mode) async {
    _themeMode = mode;
    await _storage.saveTheme(mode);
    notifyListeners();
  }

  Future<void> setUser(UserProfile? u) async {
    _user = u;
    if (u != null) {
      _onboarding = false;
      _sessionActive = true;
      await _storage.saveSessionActive(true);
    }
    await _storage.saveUser(u);
    notifyListeners();
  }

  void setOnboarding(bool value) {
    if (_onboarding == value) return;
    _onboarding = value;
    notifyListeners();
  }

  Future<void> updateUser(UserProfile u) => setUser(u);

  Future<void> setHasMealPlan(bool v) async {
    _hasMealPlan = v;
    await _storage.saveHasMealPlan(v);
    notifyListeners();
  }

  Future<void> logout() async {
    _sessionActive = false;
    await _storage.saveSessionActive(false);
    notifyListeners();
  }

  /// Профили без пароля: открыть сессию с экрана приветствия.
  Future<void> restoreLocalSession() async {
    if (_user == null) return;
    if (_user!.hasPassword) return;
    _sessionActive = true;
    await _storage.saveSessionActive(true);
    notifyListeners();
  }

  /// Возврат [true] при успехе.
  Future<bool> tryLogin(String login, String password) async {
    final p = _user;
    if (p == null) return false;
    final ok = LocalAuth.verify(
      login: login,
      password: password,
      profileLogin: p.login,
      passwordHash: p.passwordHash,
      passwordSaltB64: p.passwordSaltB64,
    );
    if (ok) {
      _sessionActive = true;
      await _storage.saveSessionActive(true);
      notifyListeners();
    }
    return ok;
  }
}
