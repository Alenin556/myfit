import 'package:flutter/foundation.dart';

import 'meal_plan_note.dart';
import 'weight_entry.dart';

import '../personal_goal.dart' show PersonalGoal, personalGoalLabel;
import '../workout_types.dart' show WorkoutPlan, workoutPlanFromName;

@immutable
class UserProfile {
  const UserProfile({
    required this.name,
    this.username,
    required this.birthYear,
    required this.weight,
    this.avatarBase64,
    this.heightCm,
    this.gender,
    this.activityMult,
    this.goal,
    this.lastBmr,
    this.login,
    this.passwordHash,
    this.passwordSaltB64,
    this.mealPlanNotes = const [],
    this.workoutPlan,
    this.workoutPlanNote,
    this.weightHistory = const [],
    this.goalWeightFromKg,
    this.goalWeightToKg,
    this.targetWeightChangeKg,
  });

  final String name;
  final String? username;
  final int birthYear;
  final double weight;
  final String? avatarBase64;
  final int? heightCm;
  final String? gender;
  final double? activityMult;
  final PersonalGoal? goal;
  final double? lastBmr;

  /// Логин для входа (email или псевдоним, без нормализации в модели).
  final String? login;
  final String? passwordHash;
  final String? passwordSaltB64;
  /// Личные заметки к плану питания (на экране «План питания»).
  final List<MealPlanNoteEntry> mealPlanNotes;
  final WorkoutPlan? workoutPlan;
  final String? workoutPlanNote;
  final List<WeightEntry> weightHistory;
  /// Диапазон веса для целей «набрать» / «снизить» (кг), «от» — старт, «до» — цель.
  final double? goalWeightFromKg;
  final double? goalWeightToKg;
  /// Набор/снижение: шаг изменения веса (2, 4, 6, 8 или 10 кг).
  final int? targetWeightChangeKg;

  bool get hasPassword => passwordHash != null && passwordHash!.isNotEmpty;

  /// Для gain/lose: заданы «от/до» и логика согласована с целью.
  bool get isWeightGoalRangeValid {
    if (goal == null || goal == PersonalGoal.maintain) {
      return true;
    }
    final from = goalWeightFromKg;
    final to = goalWeightToKg;
    if (from == null || to == null) {
      return false;
    }
    if (from < 30 || from > 300 || to < 30 || to > 300) {
      return false;
    }
    if (goal == PersonalGoal.lose) {
      if (to >= from) {
        return false;
      }
    } else if (goal == PersonalGoal.gain) {
      if (to <= from) {
        return false;
      }
    }
    final delta = (to - from).abs();
    const steps = {2, 4, 6, 8, 10};
    for (final s in steps) {
      if ((delta - s).abs() < 0.15) {
        return true;
      }
    }
    return false;
  }

  int get age {
    final y = DateTime.now().year;
    return (y - birthYear).clamp(0, 120);
  }

  bool get canComputeBmr {
    return heightCm != null &&
        heightCm! > 0 &&
        (gender == 'male' || gender == 'female') &&
        activityMult != null &&
        goal != null;
  }

  String get summaryLine {
    final g = goal != null
        ? personalGoalLabel(goal!)
        : 'Цель не задана';
    final b = lastBmr != null
        ? 'Базовая норма: ${lastBmr!.toStringAsFixed(0)} ккал/день (ориентир)'
        : 'Рекомендуем рассчитать норму в «Подсчёте калорий»';
    return '$g. $b';
  }

  UserProfile copyWith({
    String? name,
    String? username,
    int? birthYear,
    double? weight,
    String? avatarBase64,
    int? heightCm,
    String? gender,
    double? activityMult,
    PersonalGoal? goal,
    double? lastBmr,
    String? login,
    String? passwordHash,
    String? passwordSaltB64,
    List<MealPlanNoteEntry>? mealPlanNotes,
    WorkoutPlan? workoutPlan,
    String? workoutPlanNote,
    bool clearWorkoutPlan = false,
    bool clearGoal = false,
    bool clearWeightGoalRange = false,
    bool clearLastBmr = false,
    bool clearMealPlanNote = false,
    double? goalWeightFromKg,
    double? goalWeightToKg,
    int? targetWeightChangeKg,
    List<WeightEntry>? weightHistory,
  }) {
    return UserProfile(
      name: name ?? this.name,
      username: username ?? this.username,
      birthYear: birthYear ?? this.birthYear,
      weight: weight ?? this.weight,
      avatarBase64: avatarBase64 ?? this.avatarBase64,
      heightCm: heightCm ?? this.heightCm,
      gender: gender ?? this.gender,
      activityMult: activityMult ?? this.activityMult,
      goal: clearGoal ? null : (goal ?? this.goal),
      lastBmr: clearLastBmr ? null : (lastBmr ?? this.lastBmr),
      login: login ?? this.login,
      passwordHash: passwordHash ?? this.passwordHash,
      passwordSaltB64: passwordSaltB64 ?? this.passwordSaltB64,
      mealPlanNotes: clearMealPlanNote
          ? const []
          : (mealPlanNotes ?? this.mealPlanNotes),
      workoutPlan: clearWorkoutPlan ? null : (workoutPlan ?? this.workoutPlan),
      workoutPlanNote: clearWorkoutPlan
          ? null
          : (workoutPlanNote ?? this.workoutPlanNote),
      weightHistory: weightHistory ?? this.weightHistory,
      goalWeightFromKg: clearWeightGoalRange
          ? null
          : (goalWeightFromKg ?? this.goalWeightFromKg),
      goalWeightToKg: clearWeightGoalRange
          ? null
          : (goalWeightToKg ?? this.goalWeightToKg),
      targetWeightChangeKg: clearWeightGoalRange
          ? null
          : (targetWeightChangeKg ?? this.targetWeightChangeKg),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'username': username,
      'birthYear': birthYear,
      'weight': weight,
      'avatarBase64': avatarBase64,
      'heightCm': heightCm,
      'gender': gender,
      'activityMult': activityMult,
      'goal': goal?.name,
      'lastBmr': lastBmr,
      'login': login,
      'passwordHash': passwordHash,
      'passwordSaltB64': passwordSaltB64,
      'mealPlanNotes': mealPlanNotes.map((e) => e.toJson()).toList(),
      'workoutPlan': workoutPlan?.name,
      'workoutPlanNote': workoutPlanNote,
      'weightHistory': weightHistory.map((e) => e.toJson()).toList(),
      'goalWeightFromKg': goalWeightFromKg,
      'goalWeightToKg': goalWeightToKg,
      'targetWeightChangeKg': targetWeightChangeKg,
    };
  }

  static UserProfile? fromJson(Map<String, dynamic>? j) {
    if (j == null) return null;
    final name = j['name'] as String?;
    final birth = j['birthYear'];
    final w = j['weight'];
    if (name == null || name.isEmpty || birth == null || w == null) {
      return null;
    }
    PersonalGoal? g;
    final gn = j['goal'] as String?;
    if (gn != null) {
      for (final p in PersonalGoal.values) {
        if (p.name == gn) {
          g = p;
          break;
        }
      }
    }
    final twc = (j['targetWeightChangeKg'] as num?)?.toInt();
    var mealNotes = _parseMealPlanNotes(j['mealPlanNotes']);
    if (mealNotes.isEmpty) {
      final legacy = j['mealPlanNote'] as String?;
      if (legacy != null && legacy.trim().isNotEmpty) {
        mealNotes = [
          MealPlanNoteEntry(
            id: 'legacy',
            text: legacy.trim(),
            createdAt: DateTime.now(),
          ),
        ];
      }
    }
    return UserProfile(
      name: name,
      username: j['username'] as String?,
      birthYear: birth is int ? birth : int.parse('$birth'),
      weight: w is num ? w.toDouble() : double.parse('$w'),
      avatarBase64: j['avatarBase64'] as String? ?? j['webAvatarBase64'] as String?,
      heightCm: (j['heightCm'] as num?)?.toInt(),
      gender: j['gender'] as String?,
      activityMult: (j['activityMult'] as num?)?.toDouble(),
      goal: g,
      lastBmr: (j['lastBmr'] as num?)?.toDouble(),
      login: j['login'] as String?,
      passwordHash: j['passwordHash'] as String?,
      passwordSaltB64: j['passwordSaltB64'] as String?,
      mealPlanNotes: mealNotes,
      workoutPlan: workoutPlanFromName(j['workoutPlan'] as String?),
      workoutPlanNote: j['workoutPlanNote'] as String?,
      weightHistory: _parseWeightHistory(j['weightHistory']),
      goalWeightFromKg: (j['goalWeightFromKg'] as num?)?.toDouble(),
      goalWeightToKg: (j['goalWeightToKg'] as num?)?.toDouble(),
      targetWeightChangeKg: twc != null && {2, 4, 6, 8, 10}.contains(twc) ? twc : null,
    );
  }

  static List<MealPlanNoteEntry> _parseMealPlanNotes(Object? raw) {
    if (raw is! List) {
      return const [];
    }
    final out = <MealPlanNoteEntry>[];
    for (final e in raw) {
      if (e is Map<String, dynamic>) {
        out.add(MealPlanNoteEntry.fromJson(e));
      } else if (e is Map) {
        out.add(MealPlanNoteEntry.fromJson(Map<String, dynamic>.from(e)));
      }
    }
    return out;
  }

  static List<WeightEntry> _parseWeightHistory(Object? raw) {
    if (raw is! List) {
      return const [];
    }
    final out = <WeightEntry>[];
    for (final e in raw) {
      if (e is Map<String, dynamic>) {
        out.add(WeightEntry.fromJson(e));
      } else if (e is Map) {
        out.add(WeightEntry.fromJson(Map<String, dynamic>.from(e)));
      }
    }
    return out;
  }
}

double computeBmrMifflin({
  required double weightKg,
  required int heightCm,
  required int age,
  required String gender,
  required double activityMult,
}) {
  const maleConst = 5.0;
  const femaleConst = -161.0;
  final g = gender == 'male' ? maleConst : femaleConst;
  final base = 10 * weightKg + 6.25 * heightCm - 5 * age + g;
  return base * activityMult;
}
