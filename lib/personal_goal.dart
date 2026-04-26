enum PersonalGoal { gain, maintain, lose }

String personalGoalLabel(PersonalGoal goal) {
  switch (goal) {
    case PersonalGoal.gain:
      return 'Набор мышечной массы';
    case PersonalGoal.maintain:
      return 'Сохранить вес';
    case PersonalGoal.lose:
      return 'Снизить вес';
  }
}

