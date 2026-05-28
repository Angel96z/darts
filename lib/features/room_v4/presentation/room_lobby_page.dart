import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app_theme.dart';
import '../application/room_notifier.dart';
import '../domain/models/game_config.dart';
import 'match_page.dart';
import 'widgets/config_column.dart';
import 'widgets/players_column.dart';

class RoomLobbyPage extends ConsumerStatefulWidget {
  final GameType? initialGameType;

  const RoomLobbyPage({
    super.key,
    this.initialGameType,
  });

  static const double _bottomControlsHeight = 92;

  @override
  ConsumerState<RoomLobbyPage> createState() => _RoomLobbyPageState();
}

class _RoomLobbyPageState extends ConsumerState<RoomLobbyPage> {
  bool _initialGameTypeApplied = false;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final tt = Theme.of(context).textTheme;
    final state = ref.watch(roomNotifierProvider);

    if (!_initialGameTypeApplied && widget.initialGameType != null) {
      _initialGameTypeApplied = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        final notifier = ref.read(roomNotifierProvider.notifier);
        switch (widget.initialGameType!) {
          case GameType.x01:
            notifier.updateGameConfig(GameConfig.x01());
            break;
          case GameType.cricket:
            notifier.updateGameConfig(GameConfig.cricket());
            break;
        }
      });
    }
    return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          await _onBackPressed(context);
        },
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          backgroundColor: t.bg,
          appBar: AppBar(
        title: Text(
          'Gioca a freccette',
          style: tt.titleMedium?.copyWith(color: t.textPrimary),
        ),
        backgroundColor: t.bg,
        foregroundColor: t.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: t.textPrimary),
          onPressed: () => _onBackPressed(context),
        ),
      ),
          body: Column(
            children: [
              Expanded(
                child: _LobbyContent(),
              ),
              _BottomLobbyControls(
                canStartMatch: state.canStartMatch,
                onStart: () => _startMatch(context),
              ),
            ],
          ),
        ),
    );
  }

  void _startMatch(BuildContext context) {
    ref.read(roomNotifierProvider.notifier).startMatch();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MatchPage()),
    );
  }

  Future<void> _onBackPressed(BuildContext context) async {
    final t = AppTokens.of(context);
    final tt = Theme.of(context).textTheme;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: t.overlay,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Certo di voler uscire?',
          style: tt.titleMedium?.copyWith(color: t.textPrimary),
        ),
        content: Text(
          'I giocatori verranno rimossi.',
          style: tt.bodySmall?.copyWith(color: t.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Annulla',
              style: tt.bodySmall?.copyWith(color: t.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Esci',
              style: tt.titleSmall?.copyWith(color: t.accent),
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
  const _LobbyContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isWide = width >= 900;
        final padding = width < 500 ? 12.0 : 20.0;
        final maxWidth = width >= 1200 ? 1100.0 : 900.0;

        return SingleChildScrollView(
          padding: EdgeInsets.all(padding),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxWidth,
                minHeight: constraints.maxHeight,
              ),
              child: isWide
                  ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: ConfigColumn(ref: ref)),
                  const SizedBox(width: 24),
                  Expanded(child: PlayersColumn(ref: ref)),
                ],
              )
                  : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ConfigColumn(ref: ref),
                  const SizedBox(height: 20),
                  PlayersColumn(ref: ref),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BottomLobbyControls extends StatelessWidget {
  final bool canStartMatch;
  final VoidCallback onStart;

  const _BottomLobbyControls({
    required this.canStartMatch,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: BoxDecoration(
        color: t.surface.withOpacity(0.96),
        border: Border(
          top: BorderSide(color: t.border),
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 24,
            offset: const Offset(0, -8),
            color: Colors.black.withOpacity(0.18),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Row(
              children: [
                const AddPlayerButton(),
                const SizedBox(width: 12),
                Expanded(
                  child: _StartButton(
                    enabled: canStartMatch,
                    onPressed: onStart,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onPressed;

  const _StartButton({
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final tt = Theme.of(context).textTheme;

    return SizedBox(
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: t.accent,
          foregroundColor: t.accentFg,
          disabledBackgroundColor: t.surfaceHigh,
          disabledForegroundColor: t.textMuted,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: AppTokens.r16,
          ),
        ),
        onPressed: enabled ? onPressed : null,
        child: Text(
          'INIZIA PARTITA',
          style: tt.titleSmall?.copyWith(color: enabled ? t.accentFg : t.textMuted),
        ),
      ),
    );
  }
}
