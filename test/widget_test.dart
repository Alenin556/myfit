import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:myfit/app_state.dart';
import 'package:myfit/main.dart';
import 'package:myfit/services/user_storage.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('При пустом профиле отображается приветствие', (tester) async {
    final storage = await UserStorage.open();
    final appState = AppState(storage);
    await appState.init();
    await tester.pumpWidget(MyApp(appState: appState));
    await tester.pumpAndSettle();
    expect(find.textContaining('My Pro Health Nutrition'), findsOneWidget);
  });
}
