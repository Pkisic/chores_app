import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'app/theme.dart';
import 'app/router.dart';
import 'providers/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Status bar style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // Firebase init
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Load shared prefs before app starts
  final prefs = await SharedPreferences.getInstance();
  await _clearLegacyTimerPrefs(prefs);

  runApp(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
      ],
      child: const ChoresApp(),
    ),
  );
}

/// The schedule timer used to keep its state in SharedPreferences under
/// `sched_timer_*`; it now lives in Firestore.
Future<void> _clearLegacyTimerPrefs(SharedPreferences prefs) async {
  final legacy = prefs.getKeys().where((k) => k.startsWith('sched_timer_'));
  for (final key in legacy.toList()) {
    await prefs.remove(key);
  }
}

class ChoresApp extends ConsumerWidget {
  const ChoresApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final householdId = ref.watch(householdIdProvider);

    return MaterialApp(
      title: 'Chores',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      initialRoute: householdId != null ? AppRouter.home : AppRouter.onboarding,
      routes: AppRouter.routes,
    );
  }
}
