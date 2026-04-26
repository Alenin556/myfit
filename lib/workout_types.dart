String workoutPlanLabel(WorkoutPlan w) {
  switch (w) {
    case WorkoutPlan.gymFullBody3:
      return 'Зал, полнотелое, 3 раза/нед';
    case WorkoutPlan.gymSplit4:
      return 'Зал, сплит, 4 раза/нед';
    case WorkoutPlan.homeBodyweight:
      return 'Дом, только вес тела';
    case WorkoutPlan.mixedCardio:
      return 'Силовая + кардио';
    case WorkoutPlan.novice:
      return 'Начинающий, 2–3 трен/нед';
  }
}

String workoutPlanDetail(WorkoutPlan w) {
  switch (w) {
    case WorkoutPlan.gymFullBody3:
      return 'Программа: базовые многосуставные — присед, жим, тяга. 3 дня, чередующиеся от тяжёлых к лёгким подходам. Отдых 48ч между сессиями.';
    case WorkoutPlan.gymSplit4:
      return 'Верх/низ или ноги/толкай/тян. 4 сессии, 8–10 упражнений, прогрессия по весу или повторениям еженедельно.';
    case WorkoutPlan.homeBodyweight:
      return '30–45 мин: отжимания, приседы, планка, тяга резиной. Схема 3 круга, рост нагрузки — повторы и сеты.';
    case WorkoutPlan.mixedCardio:
      return '2 силовые + 2 низкоинтенсивных кардио (ходьба/вел). Упор на восстановление и небольшой дефицит по калориям.';
    case WorkoutPlan.novice:
      return '2–3 полноценных тренировки: разминка, 5–6 упражнений, заминка. Фокус на технике, без срывов.';
  }
}

enum WorkoutPlan {
  gymFullBody3,
  gymSplit4,
  homeBodyweight,
  mixedCardio,
  novice,
}

WorkoutPlan? workoutPlanFromName(String? s) {
  if (s == null) return null;
  for (final w in WorkoutPlan.values) {
    if (w.name == s) return w;
  }
  return null;
}
