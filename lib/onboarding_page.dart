import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'app_state.dart';
import 'app_theme.dart';
import 'auth/local_auth.dart';
import 'models/user_profile.dart';
import 'widgets/user_avatar_view.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, required this.appState});

  final AppState appState;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _name = TextEditingController();
  final _userName = TextEditingController();
  final _login = TextEditingController();
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();
  final _year = TextEditingController();
  final _weight = TextEditingController();
  final _height = TextEditingController();
  String? _avatarB64;
  bool _obscurePass = true;

  @override
  void dispose() {
    _name.dispose();
    _userName.dispose();
    _login.dispose();
    _pass.dispose();
    _pass2.dispose();
    _year.dispose();
    _weight.dispose();
    _height.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final p = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 80,
    );
    if (p == null) return;
    final bytes = await p.readAsBytes();
    if (bytes.length > 800000) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Изображение слишком большое. Выберите файл поменьше.')),
      );
      return;
    }
    setState(() {
      _avatarB64 = base64Encode(bytes);
    });
  }

  void _clearAvatar() {
    setState(() => _avatarB64 = null);
  }

  String? _validate() {
    final n = _name.text.trim();
    if (n.isEmpty) return 'Введите имя';
    final y = int.tryParse(_year.text.trim());
    if (y == null || y < 1920 || y > DateTime.now().year) {
      return 'Укажите корректный год рождения';
    }
    final w = double.tryParse(_weight.text.trim().replaceAll(',', '.'));
    if (w == null || w <= 0 || w > 500) {
      return 'Введите вес (кг)';
    }
    final heightCm = int.tryParse(_height.text.trim().replaceAll(',', '.'));
    if (heightCm == null || heightCm < 100 || heightCm > 250) {
      return 'Введите рост в см (100–250)';
    }
    final l = _login.text.trim();
    if (l.length < 2) {
      return 'Введите логин (не короче 2 символов)';
    }
    if (_pass.text.length < 6) {
      return 'Пароль: не менее 6 символов';
    }
    if (_pass.text != _pass2.text) {
      return 'Пароли не совпадают';
    }
    return null;
  }

  Future<void> _submit() async {
    final err = _validate();
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    final y = int.parse(_year.text.trim());
    final w = double.parse(_weight.text.trim().replaceAll(',', '.'));
    final heightCm = int.parse(_height.text.trim().replaceAll(',', '.'));
    final un = _userName.text.trim();
    final salt = LocalAuth.generateSaltB64();
    final h = LocalAuth.hashPassword(_pass.text, salt);
    final profile = UserProfile(
      name: _name.text.trim(),
      username: un.isEmpty ? null : un,
      birthYear: y,
      weight: w,
      heightCm: heightCm,
      avatarBase64: _avatarB64,
      login: _login.text.trim(),
      passwordHash: h,
      passwordSaltB64: salt,
    );
    await widget.appState.setUser(profile);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppTheme.darkAccent : AppTheme.lightAccent;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Регистрация'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Расскажите о себе',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          Center(
            child: Column(
              children: [
                GestureDetector(
                  onTap: _pickAvatar,
                  child: UserAvatarView(avatarBase64: _avatarB64, radius: 48),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _pickAvatar,
                  child: const Text('Выбрать фото'),
                ),
                if (_avatarB64 != null)
                  TextButton(
                    onPressed: _clearAvatar,
                    child: const Text('Убрать фото'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('onboarding_name'),
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Имя *',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _userName,
            decoration: const InputDecoration(
              labelText: 'Имя пользователя',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('onboarding_birthyear'),
            controller: _year,
            decoration: const InputDecoration(
              labelText: 'Год рождения *',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('onboarding_weight'),
            controller: _weight,
            decoration: const InputDecoration(
              labelText: 'Вес (кг) *',
              border: OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('onboarding_height'),
            controller: _height,
            decoration: const InputDecoration(
              labelText: 'Рост (см) *',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
          ),
          const SizedBox(height: 16),
          const Text('Доступ в приложение', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            key: const Key('onboarding_login'),
            controller: _login,
            decoration: const InputDecoration(
              labelText: 'Логин *',
              border: OutlineInputBorder(),
              hintText: 'Email или имя',
            ),
            textInputAction: TextInputAction.next,
            autocorrect: false,
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('onboarding_password'),
            controller: _pass,
            decoration: InputDecoration(
              labelText: 'Пароль *',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() => _obscurePass = !_obscurePass);
                },
                icon: Icon(_obscurePass ? Icons.visibility : Icons.visibility_off),
              ),
            ),
            obscureText: _obscurePass,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('onboarding_password2'),
            controller: _pass2,
            decoration: const InputDecoration(
              labelText: 'Повтор пароля *',
              border: OutlineInputBorder(),
            ),
            obscureText: _obscurePass,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('onboarding_back'),
                  onPressed: () => widget.appState.setOnboarding(false),
                  child: const Text('Назад'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  key: const Key('onboarding_done'),
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: isDark ? Colors.black : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Начать'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
