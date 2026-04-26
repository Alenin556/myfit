import 'package:flutter/material.dart';

import 'app_state.dart';
import 'app_theme.dart';
import 'auth/local_auth.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.appState});

  final AppState appState;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppTheme.darkAccent : AppTheme.lightAccent;
    final title = isDark ? 'Активна тёмная тема' : 'Активна светлая тема';
    final subtitle = isDark
        ? 'Переключитесь на светлую тему, чтобы снова увидеть синий акцент на белом фоне.'
        : 'Переключитесь на тёмную тему, чтобы снова увидеть жёлтые акценты на чёрном фоне.';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 20),
          Card(
            child: SwitchListTile(
              title: const Text('Тёмная тема'),
              value: isDark,
              activeThumbColor: primary,
              onChanged: (v) {
                widget.appState.setTheme(v ? ThemeMode.dark : ThemeMode.light);
              },
            ),
          ),
          const SizedBox(height: 20),
          ListTile(
            title: const Text('Пароль'),
            subtitle: Text(
              widget.appState.user?.hasPassword == true
                  ? 'Сменить пароль'
                  : 'Задать пароль для входа',
            ),
            leading: const Icon(Icons.password),
            onTap: _showPasswordDialog,
          ),
          if (widget.appState.isLoggedIn) ...[
            const SizedBox(height: 4),
            ListTile(
              title: const Text('Выйти'),
              subtitle: Text(
                widget.appState.user?.hasPassword == true
                    ? 'Сессия сброшена; для входа снова понадобится логин и пароль'
                    : 'Возврат к экрану приветствия; данные профиля на устройстве сохраняются',
              ),
              leading: const Icon(Icons.logout),
              onTap: () async {
                await widget.appState.logout();
                if (!context.mounted) return;
                Navigator.of(context).pop();
              },
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showPasswordDialog() async {
    final p = widget.appState.user;
    if (p == null) return;
    final has = p.hasPassword;
    final needLogin = p.login == null || p.login!.isEmpty;
    final oldC = TextEditingController();
    final loginC = TextEditingController(
      text: p.login ?? p.username ?? p.name,
    );
    final n1 = TextEditingController();
    final n2 = TextEditingController();
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(has ? 'Смена пароля' : 'Пароль для входа'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (needLogin) ...[
                  TextField(
                    controller: loginC,
                    decoration: const InputDecoration(
                      labelText: 'Логин (email/имя)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (has) ...[
                  TextField(
                    controller: oldC,
                    decoration: const InputDecoration(
                      labelText: 'Текущий пароль',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: n1,
                  decoration: const InputDecoration(
                    labelText: 'Новый пароль (от 6 симв.)',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: n2,
                  decoration: const InputDecoration(
                    labelText: 'Повтор',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () async {
                final bar = ScaffoldMessenger.of(context);
                if (n1.text.length < 6 || n1.text != n2.text) {
                  bar.showSnackBar(
                    const SnackBar(content: Text('Пароли: мин. 6 символов и совпадение.')),
                  );
                  return;
                }
                final l = (needLogin ? loginC.text : p.login ?? '').trim();
                if (l.length < 2) {
                  bar.showSnackBar(
                    const SnackBar(content: Text('Укажите логин')),
                  );
                  return;
                }
                if (has) {
                  final ok = LocalAuth.verify(
                    login: p.login!,
                    password: oldC.text,
                    profileLogin: p.login,
                    passwordHash: p.passwordHash,
                    passwordSaltB64: p.passwordSaltB64,
                  );
                  if (!ok) {
                    bar.showSnackBar(
                      const SnackBar(content: Text('Неверный текущий пароль')),
                    );
                    return;
                  }
                }
                final salt = LocalAuth.generateSaltB64();
                final hash = LocalAuth.hashPassword(n1.text, salt);
                final newP = p.copyWith(
                  login: l,
                  passwordHash: hash,
                  passwordSaltB64: salt,
                );
                await widget.appState.setUser(newP);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
                bar.showSnackBar(
                  const SnackBar(content: Text('Пароль сохранён')),
                );
              },
              child: const Text('Сохранить'),
            ),
          ],
        );
      },
    );
  }
}

