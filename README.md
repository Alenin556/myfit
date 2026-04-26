# myfit (My Pro Health Nutrition)

Flutter-приложение: профиль, цели по питанию и весу, расчёт калорий и КБЖУ, план питания с генерацией рациона, «Что поесть», тренировки, экспорт меню в PDF, интеграция с Telegram worker (Cloudflare).

---

## Обновления (последняя сессия)

### Цель по весу: шаг изменения (набор / снижение)

- В модели профиля добавлено поле **`targetWeightChangeKg`** (`int?`): допустимые значения **2, 4, 6, 8, 10 кг** (сериализация в JSON).
- Для целей «набрать» / «снизить» вес валидатор **`isWeightGoalRangeValid`** проверяет, что разница между «от» и «до» совпадает с выбранным шагом (с допуском ≈0.15 кг).
- На экране **плана питания** (`lib/meal_plan_page.dart`): заголовки **«На сколько увеличить вес»** / **«На сколько снизить вес»**, чипы выбора шага (кг), поле «От» редактируется, **«До»** пересчитывается по шагу; при сохранении в профиль уходит `targetWeightChangeKg` вместе с `goalWeightFromKg` / `goalWeightToKg`.
- **Дашборд**: в подзаголовке карточки «План питания» отображается строка вида `… вес: X → Y кг, план: +N кг` или `… план: −N кг` (функция `_mealPlanTileSubtitle` в `lib/dashboard_page.dart`).
- **Текст сводки для отправки** (`_buildSendSummary` в `meal_plan_page.dart`): добавлена строка **«План изменения: +N кг»** или **«−N кг»** для соответствующей цели.
- Сброс диапазона веса через **`copyWith(..., clearWeightGoalRange: true)`** очищает и шаг.

### Справочник продуктов

- Файл **`assets/data/products.json`**: существенно расширен список продуктов (десятки позиций), в т.ч. молочные продукты и каши, фрукты, мясо/рыба/морепродукты, крупы и бобовые, овощи, источники жиров (орехи, масла, авокадо и др.). Теги (`breakfast`, `dairy`, `fruit`, `lunch`, `protein`, `carb`, `veg`, `fat`) совместимы с **`DailyMenuGenerator`** — генератор подхватывает новые строки без правок кода.

### Репозиторий Git

- В каталоге проекта инициализирован **отдельный** репозиторий (ветка **`main`**, начальный коммит).
- В **`.gitignore`** добавлено игнорирование **`**/.wrangler/`** (локальный кэш Cloudflare Wrangler; не коммитить метаданные аккаунта).
- Для публикации на GitHub: создать репозиторий на [github.com/new](https://github.com/new), затем `git remote add origin …` и `git push -u origin main`, либо **`gh repo create`** после `gh auth login`.

### Прочее

- Мелкая правка линтера в `meal_plan_page.dart` (строка чипа веса: интерполяция без лишних фигурных скобок).

---

## Запуск и тесты

```bash
flutter pub get
flutter run
flutter test
flutter analyze lib
```

---

## Getting Started (Flutter)

If this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

[Online documentation](https://docs.flutter.dev/) — tutorials, samples, and API reference.
