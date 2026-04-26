import 'package:flutter/material.dart';

import 'app_state.dart';
import 'app_theme.dart';

/// Экран приветствия. Без профиля — «Начать» / «Войти».
/// С профилем, но без активной сессии — форма входа (логин/пароль) или «Продолжить» без пароля.
class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key, required this.appState});

  final AppState appState;

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  final _login = TextEditingController();
  final _pass = TextEditingController();
  bool _obsc = true;
  bool _loading = false;

  @override
  void dispose() {
    _login.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _tryPasswordLogin() async {
    setState(() => _loading = true);
    final ok = await widget.appState.tryLogin(_login.text.trim(), _pass.text);
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Неверный логин или пароль.')));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppTheme.darkAccent : AppTheme.lightAccent;
    final p = widget.appState.user;
    final notLogged = p != null && !widget.appState.isLoggedIn;
    final needPasswordForm = notLogged && p.hasPassword;
    final needPasswordlessContinue = notLogged && !p.hasPassword;

    final muted = Theme.of(
      context,
    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.55);
    return Scaffold(
      body: SafeArea(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    'Добро пожаловать в\nMy Pro Health Nutrition',
                    textAlign: TextAlign.center,
                    style: t.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0D0D0D),
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Питание, калории и планы в одном месте.',
                    textAlign: TextAlign.center,
                    style: t.bodyLarge?.copyWith(
                      color: isDark
                          ? Colors.white70
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (needPasswordForm) ...[
                    const SizedBox(height: 28),
                    Text(
                      'Войдите, чтобы снова открыть данные профиля и планов.',
                      textAlign: TextAlign.center,
                      style: t.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      key: const Key('welcome_auth_login'),
                      controller: _login,
                      decoration: const InputDecoration(
                        labelText: 'Логин',
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      autofillHints: const [AutofillHints.username],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('welcome_auth_password'),
                      controller: _pass,
                      decoration: InputDecoration(
                        labelText: 'Пароль',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() => _obsc = !_obsc);
                          },
                          icon: Icon(
                            _obsc ? Icons.visibility : Icons.visibility_off,
                          ),
                        ),
                      ),
                      obscureText: _obsc,
                      onSubmitted: (_) => _tryPasswordLogin(),
                      autofillHints: const [AutofillHints.password],
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      key: const Key('welcome_auth_submit'),
                      onPressed: _loading ? null : _tryPasswordLogin,
                      style: FilledButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: isDark ? Colors.black : Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Войти'),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Первый раз или новый профиль? Перейдите к регистрации.',
                      textAlign: TextAlign.center,
                      style: t.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      key: const Key('welcome_start'),
                      onPressed: _loading
                          ? null
                          : () => widget.appState.setOnboarding(true),
                      child: const Text('Начать'),
                    ),
                  ] else if (needPasswordlessContinue) ...[
                    const SizedBox(height: 28),
                    Text(
                      'Профиль без пароля. Нажмите, чтобы снова открыть приложение.',
                      textAlign: TextAlign.center,
                      style: t.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () => widget.appState.restoreLocalSession(),
                      style: FilledButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: isDark ? Colors.black : Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Продолжить в приложение'),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      key: const Key('welcome_start'),
                      onPressed: () => widget.appState.setOnboarding(true),
                      child: const Text('Начать'),
                    ),
                  ] else ...[
                    const SizedBox(height: 48),
                    FilledButton(
                      key: const Key('welcome_start'),
                      onPressed: () => widget.appState.setOnboarding(true),
                      style: FilledButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: isDark ? Colors.black : Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Начать'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      key: const Key('welcome_login'),
                      onPressed: () {
                        widget.appState.refreshUserFromStorage();
                        if (widget.appState.user == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Нет сохранённого профиля. Нажмите «Начать» для регистрации.',
                              ),
                            ),
                          );
                        }
                      },
                      child: const Text('Войти'),
                    ),
                  ],
                ],
              ),
            ),
            Positioned(
              left: 12,
              top: 0,
              child: IgnorePointer(
                child: Text(
                  'alenindev13',
                  style: t.labelSmall?.copyWith(
                    fontSize: 11,
                    height: 1.2,
                    color: muted,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
