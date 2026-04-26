import 'package:flutter/material.dart';

import 'app_state.dart';
import 'app_theme.dart';
import 'dashboard_page.dart';
import 'onboarding_page.dart';
import 'services/user_storage.dart';
import 'welcome_page.dart';

Widget _homeForState(AppState s) {
  if (s.user != null && s.isLoggedIn) {
    return DashboardPage(appState: s);
  }
  if (s.isOnboarding) {
    return OnboardingPage(appState: s);
  }
  return WelcomePage(appState: s);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = await UserStorage.open();
  final appState = AppState(storage);
  await appState.init();
  runApp(MyApp(appState: appState));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        if (!appState.ready) {
          return const MaterialApp(
            home: Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
            debugShowCheckedModeBanner: false,
          );
        }
        return MaterialApp(
          title: 'My Pro Health Nutrition',
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: appState.themeMode,
          debugShowCheckedModeBanner: false,
          home: _homeForState(appState),
        );
      },
    );
  }
}
