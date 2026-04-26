import 'package:flutter/material.dart';

import 'app_state.dart';
import 'app_theme.dart';
import 'widgets/nutrition_plan_gate.dart';
import 'models/user_profile.dart';
import 'personal_goal.dart';
import 'services/daily_menu_generator.dart' show DailyMenuGenerator;
import 'services/meal_plan_narrative.dart' show computePlanMacroTargets;
import 'services/menu_balance.dart' show PlanMacroTargets;
import 'what_to_eat_meal_page.dart';

class WhatToEatPage extends StatelessWidget {
  const WhatToEatPage({super.key, required this.appState});

  final AppState appState;

  String _mealLabel(String key) {
    return switch (key) {
      'Перед сном' => 'Поздний перекус',
      'Второй завтрак' => 'Второй завтрак (перекус)',
      _ => key,
    };
  }

  @override
  Widget build(BuildContext context) {
    final p = appState.user;
    if (p == null) {
      return const Center(child: Text('Профиль не найден'));
    }
    if (!p.canComputeBmr) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Сначала укажите цель и активность в «План питания».',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    }
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        if (!appState.hasMealPlan) {
          return NutritionPlanGate(appState: appState);
        }
        final bmr = computeBmrMifflin(
          weightKg: p.weight,
          heightCm: p.heightCm!,
          age: p.age,
          gender: p.gender!,
          activityMult: p.activityMult!,
        );
        final rec = bmr *
            switch (p.goal!) {
              PersonalGoal.gain => 1.10,
              PersonalGoal.maintain => 1.00,
              PersonalGoal.lose => 0.85,
            };
        final targetKcal = rec.round();
        final macros = computePlanMacroTargets(p, targetKcal: targetKcal);
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final primary = isDark ? AppTheme.darkAccent : AppTheme.lightAccent;
        final variant = Theme.of(context).colorScheme.onSurfaceVariant;

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Что поесть',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Суточная норма: $targetKcal ккал. Нажмите приём пищи, чтобы увидеть подборку продуктов.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: variant),
            ),
            const SizedBox(height: 8),
            Text(
              'КБЖУ за день: белки ≈${macros.proteinG} г, жиры ≈${macros.fatG} г, углеводы ≈${macros.carbG} г',
              style: TextStyle(color: primary, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            for (final key in DailyMenuGenerator.mealOrder) ...[
              _MealIntakeCard(
                label: _mealLabel(key),
                mealKey: key,
                share: DailyMenuGenerator.mealKcalShare[key]!,
                targetKcal: targetKcal,
                macros: macros,
                appState: appState,
                primary: primary,
              ),
              const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }
}

class _MealIntakeCard extends StatelessWidget {
  const _MealIntakeCard({
    required this.label,
    required this.mealKey,
    required this.share,
    required this.targetKcal,
    required this.macros,
    required this.appState,
    required this.primary,
  });

  final String label;
  final String mealKey;
  final double share;
  final int targetKcal;
  final PlanMacroTargets macros;
  final AppState appState;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    final kc = (targetKcal * share).round();
    if (kc < 50) {
      return const SizedBox.shrink();
    }
    final pk = (macros.proteinG * share).round();
    final fk = (macros.fatG * share).round();
    final ck = (macros.carbG * share).round();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            PageRouteBuilder<void>(
              pageBuilder: (c, a, b) => WhatToEatMealPage(
                appState: appState,
                mealKey: mealKey,
                mealLabel: label,
                targetKcal: kc,
                targetProteinG: pk,
                targetFatG: fk,
                targetCarbG: ck,
              ),
              transitionsBuilder: (c, a, s, w) =>
                  FadeTransition(opacity: a, child: w),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.restaurant, color: primary, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '≈ $kc ккал • Б $pk / Ж $fk / У $ck г',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: primary),
            ],
          ),
        ),
      ),
    );
  }
}
