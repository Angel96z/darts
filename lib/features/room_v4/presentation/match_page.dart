import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app_theme.dart';
import '../application/match_builder.dart';
import '../application/room_notifier.dart';
import '../domain/models/game_config.dart';
import '../domain/models/game_state.dart';
import '../domain/models/player_info.dart';
import 'widgets/cricket_board.dart';
import 'widgets/cricket_keyboard.dart';
import 'widgets/player_score_card.dart';
import 'widgets/team_score_card.dart';
import 'widgets/dart_keyboard.dart';
import 'widgets/turn_pass_timer.dart';
import 'widgets/match_config_bar.dart';
import 'widgets/current_turn_card.dart';

class MatchPage extends ConsumerWidget {
  const MatchPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppTokens.of(context);

    final status       = ref.watch(roomNotifierProvider.select((s) => s.status));
    final errorMessage = ref.watch(roomNotifierProvider.select((s) => s.errorMessage));
    final players      = ref.watch(roomNotifierProvider.select((s) => s.players));
    final gameState    = ref.watch(roomNotifierProvider.select((s) => s.gameState));
    final isWaiting    = ref.watch(roomNotifierProvider.select((s) => s.isWaitingForTurnPass));
    final teamSize     = ref.watch(roomNotifierProvider.select((s) => s.teamSize));
    final builderState = ref.watch(roomNotifierProvider.select((s) => s.builderState));

    ref.listen(roomNotifierProvider.select((s) => s.showResultOverlay), (prev, next) {
      if (next == true && prev == false) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (context.mounted) Navigator.pop(context);
        });
      }
    });

    return Scaffold(
      backgroundColor: t.bg,
      appBar: _AppBar(builderState: builderState, t: t),
      body: _buildBody(context, status, errorMessage, players, gameState, isWaiting, teamSize, builderState, t),
    );
  }

  Widget _buildBody(
      BuildContext context,
      AppStatus status,
      String? errorMessage,
      List<PlayerInfo> players,
      GameState? gameState,
      bool isWaiting,
      int teamSize,
      MatchBuilderState? builderState,
      AppTokens t,
      ) {
    if (status == AppStatus.loading) {
      return Center(child: CircularProgressIndicator(color: t.accent, strokeWidth: 2));
    }
    if (status == AppStatus.error) {
      return Center(child: Text(errorMessage ?? 'Errore', style: TextStyle(color: t.textSecondary, fontSize: 14)));
    }
    if (gameState == null || players.isEmpty) {
      return Center(child: Text('Nessun giocatore', style: TextStyle(color: t.textMuted, fontSize: 14)));
    }

    final isTeamMode = teamSize > 1;
    final cards = isTeamMode ? _buildTeamCards(gameState) : _buildPlayerCards(gameState);
    final currentLegKey = builderState?.currentLegNumber ?? 1;
// Calcola l'altezza per Cricket fuori dal builder
    final cricketStripHeight = gameState.isCricket
        ? (gameState.players.length * 90.0).clamp(180.0, 400.0)
        : null;
    // 🔥 DIVIDO IN DUE BLOCCHI CON Column + Expanded
    // 🔥 DIVIDO IN DUE BLOCCHI CON Column + Expanded
    return Column(
      children: [
        // ──────────────────────────────────────────────
        // BLOCCO 1 - IN ALTO (altezza fissa)
        // ──────────────────────────────────────────────
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CurrentTurnCard(key: ValueKey(currentLegKey), gameState: gameState),
            // 🔥 SPAZIO FISSO DEDICATO AL TIMER (40px) - sempre presente, mai animato
            SizedBox(
              height: 20,
              child: isWaiting
                  ? const TurnPassTimer()
                  : const SizedBox.shrink(),
            ),
          ],
        ),

// ──────────────────────────────────────────────
// BLOCCO 2 - SPINTO IN BASSO
// ──────────────────────────────────────────────
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Player strip con altezza massima controllata
              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: cricketStripHeight ?? MediaQuery.of(context).size.height * 0.4,
                  ),
                  child: _PlayerStrip(
                    cards: cards,
                    t: t,
                    isTeamMode: isTeamMode,
                    activeIndex: isTeamMode
                        ? _activeTeamIndex(gameState)
                        : gameState.orderedPlayerIds.indexOf(gameState.currentPlayerId),
                    gameState: gameState,
                    cricketStripHeight: cricketStripHeight,  // ← NUOVO PARAMETRO
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // 🔥 SCELTA TASTIERA in base al tipo di gioco
              gameState.isCricket
                  ? const CricketKeyboard()
                  : const DartKeyboard(),
              const MatchConfigBar(),
            ],
          ),
        ),
      ],
    );
  }

  int _activeTeamIndex(GameState gameState) {
    final currentTeam = gameState.getPlayerTeam(gameState.currentPlayerId);
    if (currentTeam == null) return 0;

    final teamOrder = <String>[];
    for (final id in gameState.orderedPlayerIds) {
      final team = gameState.getPlayerTeam(id);
      if (team != null && !teamOrder.contains(team)) {
        teamOrder.add(team);
      }
    }
    final index = teamOrder.indexOf(currentTeam);
    return index == -1 ? 0 : index;
  }

  List<Widget> _buildPlayerCards(GameState gameState) {
    return gameState.orderedPlayerIds.asMap().entries.map<Widget>((e) {
      return PlayerScoreCard(playerId: e.value, gameState: gameState, position: e.key + 1, isTeamMode: false);
    }).toList();
  }

  List<Widget> _buildTeamCards(GameState gameState) {
    final teamMap = gameState.teamPlayersMap;
    final teamOrder = <String>[];
    for (final id in gameState.orderedPlayerIds) {
      final team = gameState.getPlayerTeam(id);
      if (team != null && !teamOrder.contains(team)) teamOrder.add(team);
    }
    return teamOrder.map<Widget>((teamId) {
      return TeamScoreCard(teamId: teamId, playerIds: teamMap[teamId]!, gameState: gameState);
    }).toList();
  }
}

// ── AppBar ────────────────────────────────────

class _AppBar extends StatelessWidget implements PreferredSizeWidget {
  final MatchBuilderState? builderState;
  final AppTokens t;
  const _AppBar({required this.builderState, required this.t});

  @override
  Size get preferredSize => const Size.fromHeight(48);

  @override
  Widget build(BuildContext context) {
    final setNum = builderState?.currentSetNumber ?? 1;
    final legNum = builderState?.currentLegNumber ?? 1;

    return AppBar(
      backgroundColor: t.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleSpacing: 16,
      title: Text('🎯  Game On',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: t.textPrimary)),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: t.divider),
      ),
      actions: [
        _Pill(label: 'S', value: '$setNum', t: t),
        const SizedBox(width: 6),
        _Pill(label: 'L', value: '$legNum', t: t),
        const SizedBox(width: 16),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final String label, value;
  final AppTokens t;
  const _Pill({required this.label, required this.value, required this.t});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: t.surface, borderRadius: AppTokens.r6),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: t.textMuted, letterSpacing: 0.5)),
        const SizedBox(width: 4),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: t.textPrimary)),
      ]),
    );
  }
}

// ── Player cards strip ────────────────────────

class _PlayerStrip extends StatefulWidget {
  final List<Widget> cards;
  final AppTokens t;
  final int activeIndex;
  final bool isTeamMode;
  final GameState gameState;
  final double? cricketStripHeight;  // ← NUOVO PARAMETRO

  const _PlayerStrip({
    required this.cards,
    required this.t,
    required this.activeIndex,
    required this.isTeamMode,
    required this.gameState,
    this.cricketStripHeight,  // ← NUOVO PARAMETRO
  });

  @override
  State<_PlayerStrip> createState() => _PlayerStripState();
}

class _PlayerStripState extends State<_PlayerStrip> {
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();
  int? _lastActiveIndex;

  // 🔥 Lista di chiavi per misurare l'altezza di ogni card
  final List<GlobalKey> _cardKeys = [];

  @override
  void initState() {
    super.initState();
    _lastActiveIndex = widget.activeIndex;
    // Inizializza le chiavi per ogni card
    for (int i = 0; i < widget.cards.length; i++) {
      _cardKeys.add(GlobalKey());
    }
    _scrollToActive();
  }

  @override
  void didUpdateWidget(covariant _PlayerStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_lastActiveIndex != widget.activeIndex) {
      _lastActiveIndex = widget.activeIndex;
      _scrollToActive();
    }
    // Se il numero di card cambia, aggiorna le chiavi
    if (oldWidget.cards.length != widget.cards.length) {
      _cardKeys.clear();
      for (int i = 0; i < widget.cards.length; i++) {
        _cardKeys.add(GlobalKey());
      }
    }
  }

  double _getCardHeight(int index) {
    final renderBox = _cardKeys[index].currentContext?.findRenderObject() as RenderBox?;
    return renderBox?.size.height ?? 85.0; // fallback a 85 se non disponibile
  }

  void _scrollToActive() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 🔥 CRICKET (sia single che team mode): scroll verticale
      if (widget.gameState.isCricket) {
        if (!_verticalController.hasClients || widget.cards.isEmpty) return;

        final viewportHeight = _verticalController.position.viewportDimension;

        double offset = 0;
        for (int i = 0; i < widget.activeIndex; i++) {
          offset += _getCardHeight(i);
        }

        final currentCardHeight = _getCardHeight(widget.activeIndex);
        final targetOffset = offset - (viewportHeight / 2) + (currentCardHeight / 2);
        final clampedOffset = targetOffset.clamp(0.0, _verticalController.position.maxScrollExtent);

        _verticalController.animateTo(
          clampedOffset,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
        return;
      }

      // 🔥 X01: scroll orizzontale
      if (!_horizontalController.hasClients || widget.cards.isEmpty) return;

      final viewportWidth = _horizontalController.position.viewportDimension;
      final divisor = widget.isTeamMode ? 2.3 : 2.8;
      final cardWidth = viewportWidth / divisor;

      const gap = 6.0;
      const sidePadding = 12.0;

      final rawOffset = sidePadding +
          (widget.activeIndex * (cardWidth + gap)) -
          (viewportWidth / 2) +
          (cardWidth / 2);

      final target = rawOffset.clamp(0.0, _horizontalController.position.maxScrollExtent);
      _horizontalController.animateTo(
        target,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 🔥 CRICKET (sia single che team mode): colonna verticale scrollabile
        if (widget.gameState.isCricket) {
          final screenWidth = MediaQuery.of(context).size.width;
          final cardWidth = (screenWidth * 0.95);
          // 🔥 USA L'ALTEZZA PASSATA DAL PADRE
          final maxHeight = widget.cricketStripHeight ?? 360.0;

          return Center(
            child: SizedBox(
              width: cardWidth,
              height: maxHeight,  // ← ORA USA L'ALTEZZA CORRETTA
              child: SingleChildScrollView(
                controller: _verticalController,
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(widget.cards.length, (index) {
                    return Container(
                      key: _cardKeys[index],
                      child: widget.cards[index],
                    );
                  }),
                ),
              ),
            ),
          );
        }

        // 🔥 X01 (invariato)
        final divisor = widget.isTeamMode ? 2.3 : 2.8;
        final cardWidth = constraints.maxWidth / divisor;

        return SingleChildScrollView(
          controller: _horizontalController,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(widget.cards.length, (i) {
              return Padding(
                padding: EdgeInsets.only(right: i == widget.cards.length - 1 ? 0 : 6),
                child: SizedBox(width: cardWidth, child: widget.cards[i]),
              );
            }),
          ),
        );
      },
    );
  }


  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }
}