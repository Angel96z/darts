/// File: app.dart. Contiene configurazione e avvio dell'applicazione.

import 'package:darts/app/web_url_cleaner_web.dart' as WebUrlCleaner;
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
  /// Funzione: descrive in modo semplice questo blocco di logica.
  ConsumerState<_AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends ConsumerState<_AppBootstrap> {
  bool _processing = false;
  bool _loading = false;

  @override
  /// Funzione: descrive in modo semplice questo blocco di logica.
  void initState() {
    super.initState();

    /// Funzione: descrive in modo semplice questo blocco di logica.
    Future.microtask(() {
      ref.read(appLinkCoordinatorProvider.notifier).init();
    });
  }

  @override
  /// Funzione: descrive in modo semplice questo blocco di logica.
  Widget build(BuildContext context) {
    ref.listen<AppLinkState>(
      appLinkCoordinatorProvider,
          (prev, next) {
        if (_processing) return;

        final roomId = next.pendingRoomId;
        final watchId = next.pendingWatchRoomId;

        if ((roomId == null || roomId.isEmpty) &&
            (watchId == null || watchId.isEmpty)) {
          return;
        }

        _handleLink(next);
      },
    );

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return const HomeScreen();
  }

  /// Funzione: descrive in modo semplice questo blocco di logica.
  Future<void> _handleLink(AppLinkState linkState) async {
    if (_processing) return;

    _processing = true;
    /// Funzione: descrive in modo semplice questo blocco di logica.
    setState(() => _loading = true);

    final coordinator = ref.read(appLinkCoordinatorProvider.notifier);

    final roomId = linkState.pendingRoomId;
    final watchId = linkState.pendingWatchRoomId;

    try {
      if (watchId != null && watchId.isNotEmpty) {
        await ref
            .read(lobbyControllerProvider.notifier)
            .joinAsSpectator(watchId);
      } else {
        await ref
            .read(lobbyControllerProvider.notifier)
            .joinFromLink(roomId!);

        final vm = ref.read(lobbyControllerProvider);

        if (vm.roomId == null) {
          /// Funzione: descrive in modo semplice questo blocco di logica.
          setState(() => _loading = false);

          if (!mounted) return;

          /// Funzione: descrive in modo semplice questo blocco di logica.
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => AlertDialog(
              title: const Text('Room non disponibile'),
              content: const Text('La room non esiste più o è stata chiusa'),
              actions: [
                /// Funzione: descrive in modo semplice questo blocco di logica.
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );

          if (!mounted) return;

          await coordinator.consumeRoomId();

          Navigator.of(context).pushAndRemoveUntil(
            /// Funzione: descrive in modo semplice questo blocco di logica.
            MaterialPageRoute(builder: (_) => const HomeScreen()),
                (route) => false,
          );

          _processing = false;
          return;
        }
      }

      final vmAfterJoin = ref.read(lobbyControllerProvider);

      if (vmAfterJoin.roomId != null) {
        await coordinator.consumeRoomId();
      }

      cleanUrl();

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        /// Funzione: descrive in modo semplice questo blocco di logica.
        MaterialPageRoute(
          builder: (_) => RoomLobbyShellPageWrapper(
            roomId: watchId ?? roomId!,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      /// Funzione: descrive in modo semplice questo blocco di logica.
      setState(() => _loading = false);
    } finally {
      _processing = false;
    }
  }
}


class DartsApp extends ConsumerWidget {
  /// Funzione: descrive in modo semplice questo blocco di logica.
  const DartsApp({super.key});

  @override
  /// Funzione: descrive in modo semplice questo blocco di logica.
  Widget build(BuildContext context, WidgetRef ref) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.themeMode,
      builder: (context, mode, _) {
        /// Funzione: descrive in modo semplice questo blocco di logica.
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
