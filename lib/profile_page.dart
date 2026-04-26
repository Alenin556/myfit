import 'package:flutter/material.dart';

import 'app_state.dart';
import 'app_theme.dart';
import 'models/weight_entry.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.appState});

  final AppState appState;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _weightController = TextEditingController();
  String? _weightError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final w = widget.appState.user?.weight;
    if (w != null) {
      _weightController.text = w == w.roundToDouble() ? '${w.toInt()}' : w.toStringAsFixed(1);
    }
  }

  @override
  void didUpdateWidget(covariant ProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.appState.user?.weight != widget.appState.user?.weight) {
      final w = widget.appState.user?.weight;
      if (w != null) {
        _weightController.text = w == w.roundToDouble() ? '${w.toInt()}' : w.toStringAsFixed(1);
      }
    }
  }

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _saveWeight() async {
    final p = widget.appState.user;
    if (p == null) {
      return;
    }
    setState(() => _weightError = null);
    final parsed = double.tryParse(_weightController.text.trim().replaceAll(',', '.'));
    if (parsed == null || parsed <= 0 || parsed > 500) {
      setState(() => _weightError = 'Введите вес в кг (0–500)');
      return;
    }
    if ((parsed - p.weight).abs() < 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Вес не изменился.')),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Подтвердите изменение'),
        content: Text(
          'Сохранить новый вес: ${parsed.toStringAsFixed(1)} кг (было ${p.weight} кг)?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) {
      return;
    }
    setState(() => _saving = true);
    final entry = WeightEntry(recordedAt: DateTime.now(), weightKg: parsed);
    final history = [...p.weightHistory, entry];
    history.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    await widget.appState.setUser(
      p.copyWith(
        weight: parsed,
        weightHistory: history,
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Вес сохранён')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.appState.user;
    if (p == null) {
      return const Scaffold(
        body: Center(child: Text('Профиль не найден')),
      );
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppTheme.darkAccent : AppTheme.lightAccent;
    final sortedHistory = [...p.weightHistory]..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));

    return Scaffold(
      appBar: AppBar(title: const Text('Профиль')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Регистрация',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 16),
          _row('Имя', p.name),
          if (p.username != null && p.username!.isNotEmpty) _row('Имя пользователя', '@${p.username}'),
          _row('Год рождения', '${p.birthYear}'),
          if (p.heightCm != null) ...[
            const SizedBox(height: 4),
            _row('Рост', '${p.heightCm} см (фиксирован при регистрации, не редактируется)'),
          ] else
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'Рост не указан в профиле — для расчётов нужен рост из регистрации.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 13,
                ),
              ),
            ),
          if (p.login != null && p.login!.isNotEmpty) _row('Логин', p.login!),
          const SizedBox(height: 20),
          Text(
            'Текущий вес',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _weightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Вес, кг',
              errorText: _weightError,
              border: const OutlineInputBorder(),
              suffixText: 'кг',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _saving ? null : _saveWeight,
            style: FilledButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: isDark ? Colors.black : Colors.white,
            ),
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Сохранить вес'),
          ),
          const SizedBox(height: 28),
          Text(
            'История веса',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          if (sortedHistory.isEmpty)
            Text(
              'История изменений веса пока пуста',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            )
          else
            ...sortedHistory.map(
              (e) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text('${e.weightKg.toStringAsFixed(1)} кг'),
                  subtitle: Text(_formatDateTimeRu(e.recordedAt.toLocal())),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDateTimeRu(DateTime d) {
    String z(int n) => n < 10 ? '0$n' : '$n';
    return '${z(d.day)}.${z(d.month)}.${d.year} ${z(d.hour)}:${z(d.minute)}';
  }

  Widget _row(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              k,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(v, style: const TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}
