import '../models/user_profile.dart';
import '../personal_goal.dart' show PersonalGoal, personalGoalLabel;
import 'menu_balance.dart' show PlanMacroTargets;

/// Текстовый блок плана питания в духе примера (заголовок, вводный абзац, параметры, советы).
class MealPlanNarrative {
  MealPlanNarrative({
    required this.title,
    required this.introBody,
    required this.kcalLine,
    required this.proteinLine,
    required this.fatLine,
    required this.carbLine,
    required this.waterLine,
    required this.mealsPerDayLine,
    required this.footerNote,
  });

  final String title;
  final String introBody;
  final String kcalLine;
  final String proteinLine;
  final String fatLine;
  final String carbLine;
  final String waterLine;
  final String mealsPerDayLine;
  final String footerNote;
}

String _forGenderPhrase(UserProfile p) {
  if (p.gender == 'female') {
    return 'Для женщины';
  }
  return 'Для мужчины';
}

/// Целевой вес (кг) для формулировок «с X до Y».
double _targetWeight(PersonalGoal goal, double w) {
  switch (goal) {
    case PersonalGoal.lose:
      return (w * 0.89).roundToDouble();
    case PersonalGoal.gain:
      return (w * 1.08).roundToDouble();
    case PersonalGoal.maintain:
      return w;
  }
}

int _weeksRangeLow(double w0, double w1) {
  final loss = (w0 - w1).abs();
  if (loss < 0.5) {
    return 0;
  }
  final rateW = 0.008 * w0;
  return (loss / rateW).round().clamp(1, 200);
}

int _weeksRangeHigh(double w0, double w1) {
  final loss = (w0 - w1).abs();
  if (loss < 0.5) {
    return 0;
  }
  final rateW = 0.005 * w0;
  return (loss / rateW).round().clamp(1, 200);
}

/// Ориентировочные суточные КБЖУ под [targetKcal] и текущий вес в профиле.
PlanMacroTargets computePlanMacroTargets(UserProfile p, {required int targetKcal}) {
  final w0 = p.weight;
  final pMin = 2.2 * w0;
  final pMax = 2.5 * w0;
  final fMin = 0.8 * w0;
  final fMax = 1.0 * w0;
  final pMidG = (pMax + pMin) / 2;
  final fMidG = (fMax + fMin) / 2;
  final cMid = (targetKcal - 4 * pMidG - 9 * fMidG) / 4;
  return PlanMacroTargets(
    kcal: targetKcal,
    proteinG: pMidG.round(),
    fatG: fMidG.round(),
    carbG: cMid.round().clamp(0, 2000),
  );
}

MealPlanNarrative buildMealPlanNarrative(
  UserProfile p, {
  required double bmr,
  required int targetKcal,
}) {
  final w0 = p.goalWeightFromKg ?? p.weight;
  final g = p.goal ?? PersonalGoal.maintain;
  final w1 = p.goalWeightToKg ?? _targetWeight(g, w0);
  final lo = 0.005 * w0;
  final hi = 0.008 * w0;
  String title;
  final forG = _forGenderPhrase(p);
  String intro;
  if (g == PersonalGoal.lose) {
    title =
        'План питания для сушки: с ${w0.toStringAsFixed(0)} до ${w1.toStringAsFixed(0)} кг без потери мышц';
    // быстрее похудение = меньше недель, медленнее = больше недель
    final wkMin = _weeksRangeLow(w0, w1);
    final wkMax = _weeksRangeHigh(w0, w1);
    final weeks = wkMin > 0 && wkMax > 0
        ? (wkMin == wkMax ? 'около $wkMin' : 'примерно $wkMin–$wkMax')
        : 'некоторое время';
    final wish = p.gender == 'female' ? 'желающей' : 'желающего';
    intro =
        '$forG весом ${w0.toStringAsFixed(0)} кг, $wish снизить вес '
        'до ${w1.toStringAsFixed(0)} кг, оптимальная скорость похудения — 0,5–0,8% массы тела в неделю '
        '(примерно ${lo.toStringAsFixed(1).replaceAll(".", ",")}–${hi.toStringAsFixed(1).replaceAll(".", ",")} кг). '
        'В твоём случае это займёт $weeks недель. Такой темп позволяет сохранить мышечную массу и не навредить здоровью.';
  } else if (g == PersonalGoal.gain) {
    title =
        'План питания для набора: с ${w0.toStringAsFixed(0)} до ${w1.toStringAsFixed(0)} кг';
    intro =
        '$forG весом ${w0.toStringAsFixed(0)} кг при цели «${personalGoalLabel(g)}» ориентируйся на умеренный избыток калорий '
        'и достаточный белок, чтобы вес прибавлялся в основном за счёт мышц, а не жира.';
  } else {
    title =
        'План питания: ${personalGoalLabel(g)} (≈${w0.toStringAsFixed(0)} кг)';
    intro =
        '$forG весом ${w0.toStringAsFixed(0)} кг при цели «${personalGoalLabel(g)}» важна стабильность калорий и баланс БЖУ, '
        'а также регулярные тренировки и сон.';
  }

  final kmin = (targetKcal - 100).clamp(1000, 10000);
  final kmax = (targetKcal + 100).clamp(1000, 10000);
  final kc = targetKcal.clamp(1000, 10000);
  final pMin = 2.2 * w0;
  final pMax = 2.5 * w0;
  final fMin = 0.8 * w0;
  final fMax = 1.0 * w0;
  final pMidG = (pMax + pMin) / 2;
  final fMidG = (fMax + fMin) / 2;
  final cFrom = ((kc - 4 * pMidG - 9 * fMidG) / 4 - 20).round().clamp(0, 1000);
  final cTo = ((kc - 4 * pMidG - 9 * fMidG) / 4 + 20).round().clamp(0, 1000);

  return MealPlanNarrative(
    title: title,
    introBody: intro,
    kcalLine:
        'Калорийность: $kmin–$kmax ккал в сутки (начни с $kc ккал, корректируй по результатам).',
    proteinLine:
        'Белки: 2,2–2,5 г на 1 кг веса (${pMin.round()}–${pMax.round()} г/сутки).',
    fatLine:
        'Жиры: 0,8–1 г на 1 кг веса (${fMin.round()}–${fMax.round()} г/сутки).',
    carbLine: 'Углеводы: остаток калорий (около $cFrom–$cTo г/сутки).',
    waterLine: 'Вода: 3–4 литра в день.',
    mealsPerDayLine: 'Режим: 5–6 приёмов пищи в сутки.',
    footerNote:
        'Если не добираешь белка — добавь ещё порцию протеина или творога. '
        'Если худеешь слишком быстро — увеличь углеводы на 20–30 г.',
  );
}

String regimeTipsText() {
  return '''
Рекомендации по режиму
Питайся каждые 3–4 часа.
За час до тренировки — сложные углеводы и белок.
После тренировки — белок + быстрые углеводы.
Последний приём пищи — за 2–3 часа до сна.''';
}
