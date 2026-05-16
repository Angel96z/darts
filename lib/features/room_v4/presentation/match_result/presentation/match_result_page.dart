import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app_theme.dart';
import '../../../application/room_notifier.dart';
import '../../../domain/models/player_info.dart';
import '../../room_lobby_page.dart';


class MatchResultPage extends ConsumerWidget {
  const MatchResultPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppTokens.of(context);
    final winnerId = ref.watch(roomNotifierProvider.select((s) => s.matchWinnerId));
    final completedMatch = ref.watch(roomNotifierProvider.select((s) => s.completedMatch));

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        title: Text(
          'Match Result',
          style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.w800),
        ),
        backgroundColor: t.bg,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: t.textPrimary),
          onPressed: () => _onBackPressed(context, ref),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.emoji_events, size: 80, color: t.accent),
            const SizedBox(height: 24),
            Text(
              'Winner',
              style: TextStyle(color: t.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              _getWinnerName(ref, winnerId),
              style: TextStyle(
                color: t.accent,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: () => _onBackPressed(context, ref),
              style: ElevatedButton.styleFrom(
                backgroundColor: t.accent,
                foregroundColor: t.accentFg,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: AppTokens.r16),
              ),
              child: Text(
                'BACK TO LOBBY',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: t.accentFg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getWinnerName(WidgetRef ref, String? winnerId) {
    if (winnerId == null) return 'Unknown';
    final players = ref.read(roomNotifierProvider).players;
    final player = players.firstWhere(
          (p) => p.id == winnerId,
      orElse: () => PlayerInfo(id: winnerId, name: winnerId, isGuest: false, order: 0),
    );
    return player.name;
  }

  void _onBackPressed(BuildContext context, WidgetRef ref) {
    // Non resettare nulla, torna solo indietro
    Navigator.of(context).pop();
  }
}