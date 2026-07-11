import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/branding.dart';
import 'state/auth_state.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const OlasApp());
}

class OlasApp extends StatelessWidget {
  const OlasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthState()..restore(),
      child: MaterialApp(
        title: Branding.schoolName,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Branding.primaryColor,
          scaffoldBackgroundColor: const Color(0xFFF5F6F8),
          inputDecorationTheme: const InputDecorationTheme(
            border: OutlineInputBorder(),
          ),
        ),
        home: const AuthGate(),
      ),
    );
  }
}

/// Chooses which screen to show based on auth status. This is the single
/// source of truth for "logged in or not" — screens never navigate to login
/// manually; they just change AuthState and this rebuilds.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    switch (auth.status) {
      case AuthStatus.unknown:
        return const SplashScreen();
      case AuthStatus.signedIn:
        return const HomeScreen();
      case AuthStatus.authenticating:
      case AuthStatus.signedOut:
        return const LoginScreen();
    }
  }
}
