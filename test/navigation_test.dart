import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myfit/app_state.dart';
import 'package:myfit/main.dart';
import 'package:myfit/services/user_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  /// Стандартное окно теста 800×600 — кнопки внизу [ListView] вне кадра.
  Future<void> tallSurface(WidgetTester tester) async {
    await TestWidgetsFlutterBinding.instance.setSurfaceSize(
      const Size(800, 2000),
    );
    addTearDown(
      () => TestWidgetsFlutterBinding.instance.setSurfaceSize(null),
    );
  }

  Future<AppState> createAppState() async {
    final storage = await UserStorage.open();
    final state = AppState(storage);
    await state.init();
    return state;
  }

  testWidgets('Приветствие: кнопка «Войти» при отсутствии профиля', (tester) async {
    final appState = await createAppState();
    await tester.pumpWidget(MyApp(appState: appState));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('welcome_login')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Нет сохранённого профиля'), findsOneWidget);
  });

  testWidgets('Приветствие → онбординг', (tester) async {
    final appState = await createAppState();
    await tester.pumpWidget(MyApp(appState: appState));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('welcome_start')));
    await tester.pumpAndSettle();
    expect(find.text('Расскажите о себе'), findsOneWidget);
  });

  testWidgets('Онбординг: Назад → снова приветствие', (tester) async {
    await tallSurface(tester);
    final appState = await createAppState();
    await tester.pumpWidget(MyApp(appState: appState));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('welcome_start')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding_back')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Добро пожаловать'), findsOneWidget);
  });

  testWidgets('Онбординг: заполнение → главная (дашборд)', (tester) async {
    await tallSurface(tester);
    final appState = await createAppState();
    await tester.pumpWidget(MyApp(appState: appState));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('welcome_start')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('onboarding_name')), 'Иван');
    await tester.enterText(find.byKey(const Key('onboarding_birthyear')), '1990');
    await tester.enterText(find.byKey(const Key('onboarding_weight')), '75');
    await tester.enterText(find.byKey(const Key('onboarding_height')), '175');
    await tester.enterText(find.byKey(const Key('onboarding_login')), 'ivan@test.com');
    await tester.enterText(find.byKey(const Key('onboarding_password')), 'testpass12');
    await tester.enterText(find.byKey(const Key('onboarding_password2')), 'testpass12');
    await tester.tap(find.byKey(const Key('onboarding_done')));
    await tester.pumpAndSettle();
    expect(find.text('Иван'), findsWidgets);
    expect(find.text('Главная'), findsOneWidget);
  });

  testWidgets('Дашборд → ввод БМР → таблица КБЖУ', (tester) async {
    await tallSurface(tester);
    final appState = await createAppState();
    await tester.pumpWidget(MyApp(appState: appState));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('welcome_start')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('onboarding_name')), 'Мария');
    await tester.enterText(find.byKey(const Key('onboarding_birthyear')), '1992');
    await tester.enterText(find.byKey(const Key('onboarding_weight')), '60');
    await tester.enterText(find.byKey(const Key('onboarding_height')), '165');
    await tester.enterText(find.byKey(const Key('onboarding_login')), 'm@test.com');
    await tester.enterText(find.byKey(const Key('onboarding_password')), 'testpass12');
    await tester.enterText(find.byKey(const Key('onboarding_password2')), 'testpass12');
    await tester.tap(find.byKey(const Key('onboarding_done')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationDrawer),
        matching: find.text('Питание'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Перейти к расчёту'));
    await tester.pumpAndSettle();
    expect(find.text('Данные для расчёта калорий'), findsOneWidget);
    await tester.tap(find.byKey(const Key('bmr_to_plan')));
    await tester.pumpAndSettle();
    expect(find.text('Суточные нормы (КБЖУ)'), findsOneWidget);
    expect(find.textContaining('ккал'), findsWidgets);
  });

  testWidgets('Настройки: открыть экран', (tester) async {
    await tallSurface(tester);
    final appState = await createAppState();
    await tester.pumpWidget(MyApp(appState: appState));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('welcome_start')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('onboarding_name')), 'Саша');
    await tester.enterText(find.byKey(const Key('onboarding_birthyear')), '2000');
    await tester.enterText(find.byKey(const Key('onboarding_weight')), '65');
    await tester.enterText(find.byKey(const Key('onboarding_height')), '170');
    await tester.enterText(find.byKey(const Key('onboarding_login')), 's@test.com');
    await tester.enterText(find.byKey(const Key('onboarding_password')), 'testpass12');
    await tester.enterText(find.byKey(const Key('onboarding_password2')), 'testpass12');
    await tester.tap(find.byKey(const Key('onboarding_done')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    expect(find.text('Настройки'), findsWidgets);
    expect(find.byType(SwitchListTile), findsOneWidget);
  });
}
