import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/link/app_link_state.dart';
import '../../app_theme.dart';
import '../../features/consigli/admin/consigli_admin_screen.dart';
import '../../features/consigli/consigli_feature.dart';
import '../../features/players/application/user_notifier.dart';
import '../../features/room_v4/presentation/room_lobby_page.dart';
import '../../features/stats/presentation/pages/stats_home_screen.dart';
import '../../features/stats/presentation/pages/training_screen.dart';
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
    Navigator.push(context, MaterialPageRoute(builder: (_) => const TrainingScreen(title: 'ROSES Throws', mode: TrainingMode.bull)));
  }

  void _navigateToStats() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const StatsHomeScreen()));
  }

  void _navigateToRoomLobby() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const RoomLobbyPage()));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    ref.listen<AppLinkState>(appLinkCoordinatorProvider, (prev, next) {
      final hasPendingRoom = next.pendingRoomId != null && next.pendingRoomId!.isNotEmpty;
      final hadPendingRoom = prev?.pendingRoomId != null && prev!.pendingRoomId!.isNotEmpty;
      if (hasPendingRoom && !hadPendingRoom && mounted) _navigateToRoomLobby();
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Darts Roses trainer'),
        centerTitle: true,
        elevation: 0,
        actions: [
          Consumer(
            builder: (context, ref, _) {
              final userState = ref.watch(userProvider);
              return Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      userState.displayName,
                      style: TextStyle(fontSize: 12, color: t.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.account_circle, color: t.accent),
                    onPressed: () => Scaffold.of(context).openEndDrawer(),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      endDrawer: const ProfilePanel(),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            _buildCard(icon: Icons.center_focus_weak, title: 'Training', subtitle: 'Practice mode & bullseye training', onTap: _navigateToTraining, showBadge: false),
            const SizedBox(height: 20),
            _buildCard(icon: Icons.sports_esports, title: 'Match', subtitle: 'X01 • Cricket', onTap: _navigateToRoomLobby, showBadge: false),
            const SizedBox(height: 20),
            _buildCard(icon: Icons.bar_chart, title: 'Statistiche', subtitle: 'Analizza i tuoi progressi e performance', onTap: _navigateToStats, showBadge: false),
            const SizedBox(height: 20),
            const ConsigliCarouselWidget(), // importa il widget
// Dopo gli altri card
            _buildCard(
              icon: Icons.admin_panel_settings,
              title: 'Admin Consigli',
              subtitle: 'Gestisci le frasi motivazionali',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ConsigliAdminScreen()),
                );
              },
              showBadge: false,
            ),
          ],
        ),

      ),
    );
  }

  Widget _buildCard({required IconData icon, required String title, required String subtitle, required VoidCallback onTap, required bool showBadge}) {
    final t = AppTokens.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: t.border, width: 1)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: t.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: t.accent, size: 28)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: t.textPrimary)),
                        if (showBadge) ...[
                          const SizedBox(width: 8),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: t.accent.withOpacity(0.15), borderRadius: BorderRadius.circular(4)), child: Text('NEW', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: t.accent, letterSpacing: 0.5))),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(fontSize: 13, color: t.textSecondary)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: t.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}