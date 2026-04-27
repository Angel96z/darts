import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/link/app_link_state.dart';
import '../../features/game/presentation/pages/gioca_screen.dart';
import '../../features/room_v4/presentation/room_lobby_page.dart';
import '../../features/stats/presentation/pages/training_screen.dart';
import '../../features/stats/presentation/pages/training_stats_screen.dart';
import '../../features/game/domain/entities/training_mode.dart';
import '../../features/players/presentation/widgets/profile_panel.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(appLinkCoordinatorProvider);
      final hasPendingRoom = state.pendingRoomId != null && state.pendingRoomId!.isNotEmpty;

      if (hasPendingRoom && mounted) {
        _navigateToRoomLobby();
      }
    });
  }

  void _navigateToTraining() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const TrainingScreen(
          title: 'Rosa di tiro',
          mode: TrainingMode.bull,
        ),
      ),
    );
  }

  void _navigateToStats() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const TrainingStatsScreen(
          title: 'Rosa di tiro',
          mode: TrainingMode.bull,
        ),
      ),
    );
  }

  void _navigateToRoomLobby() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RoomLobbyPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AppLinkState>(
      appLinkCoordinatorProvider,
          (prev, next) {
        final hasPendingRoom = next.pendingRoomId != null && next.pendingRoomId!.isNotEmpty;
        final hadPendingRoom = prev?.pendingRoomId != null && prev!.pendingRoomId!.isNotEmpty;

        if (hasPendingRoom && !hadPendingRoom && mounted) {
          _navigateToRoomLobby();
        }
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Darts'),
        centerTitle: true,
        elevation: 2,
        actions: [
          StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              final user = snapshot.data;

              return Row(
                children: [
                  if (user != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        user.email ?? '',
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.account_circle),
                    onPressed: () {
                      Scaffold.of(context).openEndDrawer();
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
      endDrawer: const ProfilePanel(),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Card Rosa di tiro (con pulsante statistiche)
            Card(
              child: ListTile(
                leading: const Icon(Icons.fitness_center),
                title: const Text('Rosa di tiro'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.bar_chart),
                      onPressed: _navigateToStats,
                    ),
                    const Icon(Icons.arrow_forward_ios),
                  ],
                ),
                onTap: _navigateToTraining,
              ),
            ),
            const SizedBox(height: 24),
            // Card Room Lobby V4
            Card(
              color: Colors.green.shade50,
              child: ListTile(
                leading: const Icon(Icons.sports_esports, color: Colors.green),
                title: const Text('ROOM V4 (NUOVA ARCHITETTURA)'),
                subtitle: const Text('Match completo X01/Cricket - Lobby + Partita'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: _navigateToRoomLobby,
              ),
            ),
          ],
        ),
      ),
    );
  }
}