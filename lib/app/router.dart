import 'package:flutter/material.dart';
import 'package:chores/features/onboarding/views/onboarding_page.dart';
import 'package:chores/features/home/views/home_shell.dart';

/// Simple imperative navigation helpers.
/// Kept minimal — the app only has two entry points:
///   1. Onboarding (no household yet)
///   2. Home shell  (household exists)
class AppRouter {
  AppRouter._();

  static const String onboarding = '/onboarding';
  static const String home = '/';

  static Map<String, WidgetBuilder> get routes => {
        onboarding: (_) => const OnboardingPage(),
        home: (_) => const HomeShell(),
      };
}
