/// File: app.dart. Contiene configurazione e avvio dell'applicazione.

import 'package:darts/app/web_url_cleaner_web.dart' as WebUrlCleaner;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import 'link/app_link_state.dart';
import 'router/home_shell_screen.dart';
import '../features/players/presentation/pages/login_screen.dart';
import 'web_url_cleaner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:darts/features/room_v2/room_repository.dart';


class _AppBootstrap extends ConsumerStatefulWidget {
  const _AppBootstrap();

  @override
  ConsumerState<_AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends ConsumerState<_AppBootstrap> {
  bool _processing = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      ref.read(appLinkCoordinatorProvider.notifier).init();
    });
  }

  @override
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

  Future<void> _handleLink(AppLinkState linkState) async {
    if (_processing) return;

    _processing = true;
    setState(() => _loading = true);

    final coordinator = ref.read(appLinkCoordinatorProvider.notifier);

    final roomId = linkState.pendingRoomId;
    final watchId = linkState.pendingWatchRoomId;

    try {
      if (roomId != null && roomId.isNotEmpty) {
        if (!mounted) return;

        final accept = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Invito'),
            content: const Text('Vuoi entrare nella partita?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Si'),
              ),
            ],
          ),
        );

        if (accept == true) {
          final repo = RoomRepository(FirebaseFirestore.instance);

          await repo.joinRoom(
            roomId,
            FirebaseAuth.instance.currentUser!.uid,
          );
        }

        await coordinator.consumeRoomId();
      }

      cleanUrl();

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
            (route) => false,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    } finally {
      _processing = false;
    }
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