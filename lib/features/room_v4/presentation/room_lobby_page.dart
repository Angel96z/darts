import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app_theme.dart';
import '../application/room_notifier.dart';
import 'match_page.dart';
import 'match_result/presentation/match_result_overlay.dart';
import 'widgets/config_column.dart';
import 'widgets/players_column.dart';

class RoomLobbyPage extends ConsumerWidget {
  const RoomLobbyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppTokens.of(context);
    final state = ref.watch(roomNotifierProvider);

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        title: Text(
          'Lobby',
          style: TextStyle(
            color: t.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: t.bg,
        foregroundColor: t.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _onBackPressed(context, ref, t),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: t.divider),
        ),
      ),

      body: Stack(
        children: [
          _LobbyContent(
            canStartMatch: state.canStartMatch,
            onStart: () => _startMatch(context, ref),
            t: t,
          ),

          const MatchResultOverlay(),
        ],
      ),
    );
  }

  void _startMatch(BuildContext context, WidgetRef ref) {
    ref.read(roomNotifierProvider.notifier).startMatch();

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MatchPage()),
    );
  }

  Future<void> _onBackPressed(
      BuildContext context,
      WidgetRef ref,
      AppTokens t,
      ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: t.overlay,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Esci dalla lobby?',
          style: TextStyle(
            color: t.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          'I giocatori verranno rimossi.',
          style: TextStyle(color: t.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('No', style: TextStyle(color: t.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Sì',
              style: TextStyle(
                color: t.accent,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      ref.read(roomNotifierProvider.notifier).resetAll();
      if (context.mounted) Navigator.of(context).pop();
    }
  }
}
class _LobbyContent extends ConsumerWidget {
  final bool canStartMatch;
  final VoidCallback onStart;
  final AppTokens t;

  const _LobbyContent({
    required this.canStartMatch,
    required this.onStart,
    required this.t,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        final isWide = width >= 900;
        final padding = width < 500 ? 12.0 : 20.0;
        final maxWidth = width >= 1200 ? 1100.0 : 900.0;

        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(padding),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [

                    /// ───── CONFIG + PLAYERS ─────
                    if (isWide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: ConfigColumn(ref: ref)),
                          const SizedBox(width: 24),
                          Expanded(child: PlayersColumn(ref: ref)),
                        ],
                      )
                    else
                      Column(
                        children: [
                          ConfigColumn(ref: ref),
                          const SizedBox(height: 20),
                          PlayersColumn(ref: ref),
                        ],
                      ),

                    const SizedBox(height: 24),

                    /// ───── START BUTTON ─────
                    _StartButton(
                      enabled: canStartMatch,
                      onPressed: onStart,
                      t: t,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StartButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onPressed;
  final AppTokens t;

  const _StartButton({
    required this.enabled,
    required this.onPressed,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: t.accent,
          foregroundColor: t.accentFg,
          disabledBackgroundColor: t.surfaceHigh,
          disabledForegroundColor: t.textMuted,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: AppTokens.r10,
          ),
        ),
        child: const Text(
          'START MATCH',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
