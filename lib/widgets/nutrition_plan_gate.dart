import 'package:flutter/material.dart';

import '../app_state.dart';
import '../app_theme.dart';
import '../bmr_entry_page.dart';

/// Пока пользователь не подтвердил расчёт кнопкой «К плану» в [BmrEntryPage], полный контент питания не показываем.
class NutritionPlanGate extends StatelessWidget {
  const NutritionPlanGate({super.key, required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppTheme.darkAccent : AppTheme.lightAccent;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.restaurant_menu, size: 48),
              const SizedBox(height: 20),
              Text(
                'Меню и вся информация по питанию отображаются после ввода цели, параметров и нажатия кнопки «К плану» внизу экрана «Данные для расчёта калорий».',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.4),
              ),
              const SizedBox(height: 24),
              FilledButton(
                key: const Key('meal_plan_to_plan'),
                onPressed: () {
                  Navigator.of(context).push(
                    PageRouteBuilder<void>(
                      pageBuilder: (c, a, b) => BmrEntryPage(appState: appState),
                      transitionsBuilder: (c, a, s, w) {
                        return FadeTransition(opacity: a, child: w);
                      },
                    ),
                  );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: isDark ? Colors.black : Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
                child: const Text('К плану'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
