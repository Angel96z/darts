import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_theme.dart';
import '../features/match_sync/data/services/local_match_sync_service.dart';
import '../features/stats/data/datasources/local_training_sync_service.dart';
import '../features/stats/domain/services/stats_aggregator_service.dart';
import '../features/stats/shared/stats_repository.dart';
import 'link/app_link_state.dart';
import 'router/home_shell_screen.dart';
import '../features/players/presentation/pages/login_screen.dart';
import '../features/players/application/user_notifier.dart';

class _AppBootstrap extends ConsumerStatefulWidget {
  const _AppBootstrap();

  @override
  ConsumerState<_AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends ConsumerState<_AppBootstrap> {
  @override
  void initState() {
    super.initState();
    Future.microtask(_bootstrap);
  }

  Future<void> _bootstrap() async {
    await ref.read(appLinkCoordinatorProvider.notifier).init();
    await ref.read(userProvider.notifier).loadProfile();
  }

  @override
  Widget build(BuildContext context) {
    return const HomeScreen();
  }
}


class DartsApp extends ConsumerWidget {
  const DartsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ✅ USA IL ThemeController GLOBALE che già esiste nel tuo codice
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.themeMode,  // ✅ usa quello globale
      builder: (context, mode, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Darts Arena',
          theme: AppThemeData.light(),
          darkTheme: AppThemeData.dark(),
          themeMode: mode,
          home: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              final user = snapshot.data ?? FirebaseAuth.instance.currentUser;
              if (user == null) return const LoginScreen();
              return const _AppBootstrap();
            },
          ),
        );
      },
    );
  }
}

class ThemeController {
  static final ValueNotifier<ThemeMode> themeMode = ValueNotifier(ThemeMode.system);
  static void setTheme(ThemeMode mode) { themeMode.value = mode; }
}