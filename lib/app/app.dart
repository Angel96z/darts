import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../features/darts_match/presentation/lobby/pages/room_lobby_shell_page_wrapper.dart';
import 'link/app_link_state.dart';
import 'router/home_shell_screen.dart';
import '../features/players/presentation/pages/login_screen.dart';

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

              // 👇 QUI dentro inseriamo il deep link
              final linkState = ref.watch(appLinkCoordinatorProvider);

              if (linkState.pendingRoomId != null &&
                  !linkState.consumed) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  final roomId = ref
                      .read(appLinkCoordinatorProvider.notifier)
                      .consumeRoomId();

                  if (roomId != null) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            RoomLobbyShellPageWrapper(roomId: roomId),                      ),
                    );
                  }
                });
              }

              return const HomeScreen();
            },
          ),
        );
      },
    );

  }
}