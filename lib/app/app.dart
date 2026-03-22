import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../features/darts_match/presentation/lobby/controllers/lobby_controller.dart';
import '../features/darts_match/presentation/lobby/pages/room_lobby_shell_page_wrapper.dart';
import 'link/app_link_state.dart';
import 'router/home_shell_screen.dart';
import '../features/players/presentation/pages/login_screen.dart';
import 'web_url_cleaner.dart';

class _AppBootstrap extends ConsumerStatefulWidget {
  const _AppBootstrap();

  @override
  ConsumerState<_AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends ConsumerState<_AppBootstrap> {
  bool _handled = false;
  bool _loading = false;
  bool _didRun = false;
  bool _processing = false;

  @override
  void initState() {
    super.initState();

    if (_didRun) return;
    _didRun = true;

    _handleLink();
  }


  Future<void> _handleLink() async {
    if (_handled || _processing) return;
    _handled = true;
    _processing = true;

    final coordinator = ref.read(appLinkCoordinatorProvider.notifier);
    final roomId = coordinator.state.pendingRoomId;
    final watchId = coordinator.state.pendingWatchRoomId;

    if ((roomId == null || roomId.isEmpty) &&
        (watchId == null || watchId.isEmpty)) {
      _processing = false;
      return;
    }

    setState(() => _loading = true);

    try {
      if (watchId != null && watchId.isNotEmpty) {
        await ref
            .read(lobbyControllerProvider.notifier)
            .joinAsSpectator(watchId);
      } else {
        await ref
            .read(lobbyControllerProvider.notifier)
            .joinFromLink(roomId!);
      }

      await coordinator.consumeRoomId();
      cleanUrl();

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => RoomLobbyShellPageWrapper(
            roomId: watchId ?? roomId!,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    } finally {
      _processing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return const HomeScreen();

  }
}
class DartsApp extends ConsumerWidget {
  const DartsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.themeMode,
      builder: (context, mode, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Darts',
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: mode,
          home: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.data == null) {
                return const LoginScreen();
              }

              return const _AppBootstrap();

            },
          ),
        );
      },
    );

  }
}