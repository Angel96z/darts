import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app_theme.dart';
import '../application/match_builder.dart';
import '../application/room_notifier.dart';
import '../domain/models/game_config.dart';
import '../domain/models/game_state.dart';
import '../domain/models/player_info.dart';
import 'match_result/presentation/match_result_page.dart';
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
    final tt = Theme.of(context).textTheme;

    final status       = ref.watch(roomNotifierProvider.select((s) => s.status));
    final errorMessage = ref.watch(roomNotifierProvider.select((s) => s.errorMessage));
    final players      = ref.watch(roomNotifierProvider.select((s) => s.players));
    final gameState    = ref.watch(roomNotifierProvider.select((s) => s.gameState));
    final isWaiting    = ref.watch(roomNotifierProvider.select((s) => s.isWaitingForTurnPass));
    final teamSize     = ref.watch(roomNotifierProvider.select((s) => s.teamSize));
    final builderState = ref.watch(roomNotifierProvider.select((s) => s.builderState));

    ref.listen(roomNotifierProvider.select((s) => s.matchFinished), (prev, next) {
      if (next == true && prev == false) {
        if (context.mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const MatchResultPage(),
            ),
          );
        }
      }
    });

    return Scaffold(
      backgroundColor: t.bg,
      appBar: _AppBar(builderState: builderState, t: t),
      body: _buildBody(
        context,
        status,
        errorMessage,
        players,
        gameState,
        isWaiting,
        teamSize,
        builderState,
        t,
        tt,
      ),
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
      TextTheme tt,
      ) {
    if (status == AppStatus.loading) {
      return Center(child: CircularProgressIndicator(color: t.accent, strokeWidth: 2));
    }
    if (status == AppStatus.error) {
      return Center(
        child: Text(
          errorMessage ?? 'Errore',
          style: tt.bodySmall?.copyWith(color: t.textSecondary),
        ),
      );
    }
    if (gameState == null || players.isEmpty) {
      return Center(
        child: Text(
          'Nessun giocatore',
          style: tt.bodySmall?.copyWith(color: t.textMuted),
        ),
      );
    }

    final isTeamMode = teamSize > 1;
    final cards = isTeamMode ? _buildTeamCards(gameState) : _buildPlayerCards(gameState);
    final currentLegKey = builderState?.currentLegNumber ?? 1;
    final cricketStripHeight = gameState.isCricket
        ? (gameState.players.length * 90.0).clamp(180.0, 400.0)
        : null;

    final isDesktop = MediaQuery.of(context).size.width > 900;

    if (isDesktop) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 864), // Larghezza massima totale
          child: Row(
            children: [
              // Colonna SINISTRA - con larghezza massima
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400), // Massimo colonna sinistra
                child: Expanded(
                  flex: 6,
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      CurrentTurnCard(key: ValueKey(currentLegKey), gameState: gameState),
                      SizedBox(
                        height: 20,
                        child: isWaiting
                            ? const TurnPassTimer()
                            : const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: _PlayerStripDesktop(
                          cards: cards,
                          t: t,
                          isTeamMode: isTeamMode,
                          activeIndex: isTeamMode
                              ? _activeTeamIndex(gameState)
                              : gameState.orderedPlayerIds.indexOf(gameState.currentPlayerId),
                          gameState: gameState,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const MatchConfigBar(),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
              // Colonna DESTRA - con larghezza massima
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500), // Massimo colonna destra
                child: SizedBox(
                  width: 380,  // Larghezza base
                  child: Column(
                    children: [
                      if (gameState.isCricket) ...[
                        const SizedBox(height: 16),
                        CricketBoard(gameState: gameState),
                        const SizedBox(height: 16),
                      ],
                      Expanded(
                        child: Center(
                          child: SizedBox(
                            width: 340,
                            height: 440,
                            child: gameState.isCricket
                                ? const CricketKeyboard()
                                : const DartKeyboard(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    // ──────────────────────────────────────────────
    // LAYOUT MOBILE (originale invariato)
    // ──────────────────────────────────────────────
    return Column(
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CurrentTurnCard(key: ValueKey(currentLegKey), gameState: gameState),
            SizedBox(
              height: 20,
              child: isWaiting
                  ? const TurnPassTimer()
                  : const SizedBox.shrink(),
            ),
          ],
        ),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
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
                    cricketStripHeight: cricketStripHeight,
                  ),
                ),
              ),
              const SizedBox(height: 8),
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
    final tt = Theme.of(context).textTheme;
    final setNum = builderState?.currentSetNumber ?? 1;
    final legNum = builderState?.currentLegNumber ?? 1;

    return AppBar(
      backgroundColor: t.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleSpacing: 16,
      title: Text('🎯  Game On',
          style: tt.titleMedium?.copyWith(color: t.textPrimary)),
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
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: t.surface, borderRadius: AppTokens.r6),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: tt.labelSmall?.copyWith(color: t.textMuted)),
        const SizedBox(width: 4),
        Text(value, style: tt.titleSmall?.copyWith(color: t.textPrimary)),
      ]),
    );
  }
}

// ── Player cards strip (mobile) ────────────────────────

class _PlayerStrip extends StatefulWidget {
  final List<Widget> cards;
  final AppTokens t;
  final int activeIndex;
  final bool isTeamMode;
  final GameState gameState;
  final double? cricketStripHeight;

  const _PlayerStrip({
    required this.cards,
    required this.t,
    required this.activeIndex,
    required this.isTeamMode,
    required this.gameState,
    this.cricketStripHeight,
  });

  @override
  State<_PlayerStrip> createState() => _PlayerStripState();
}

class _PlayerStripState extends State<_PlayerStrip> {
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();
  int? _lastActiveIndex;
  final List<GlobalKey> _cardKeys = [];

  @override
  void initState() {
    super.initState();
    _lastActiveIndex = widget.activeIndex;
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
    if (oldWidget.cards.length != widget.cards.length) {
      _cardKeys.clear();
      for (int i = 0; i < widget.cards.length; i++) {
        _cardKeys.add(GlobalKey());
      }
    }
  }

  double _getCardHeight(int index) {
    final renderBox = _cardKeys[index].currentContext?.findRenderObject() as RenderBox?;
    return renderBox?.size.height ?? 85.0;
  }

  void _scrollToActive() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
        if (widget.gameState.isCricket) {
          final screenWidth = MediaQuery.of(context).size.width;
          final cardWidth = (screenWidth * 0.95);
          final maxHeight = widget.cricketStripHeight ?? 360.0;

          return Center(
            child: SizedBox(
              width: cardWidth,
              height: maxHeight,
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

// ── Player cards strip DESKTOP ────────────────────────

class _PlayerStripDesktop extends StatefulWidget {
  final List<Widget> cards;
  final AppTokens t;
  final int activeIndex;
  final bool isTeamMode;
  final GameState gameState;

  const _PlayerStripDesktop({
    required this.cards,
    required this.t,
    required this.activeIndex,
    required this.isTeamMode,
    required this.gameState,
  });

  @override
  State<_PlayerStripDesktop> createState() => _PlayerStripDesktopState();
}

class _PlayerStripDesktopState extends State<_PlayerStripDesktop> {
  final ScrollController _verticalController = ScrollController();
  int? _lastActiveIndex;
  final List<GlobalKey> _cardKeys = [];

  @override
  void initState() {
    super.initState();
    _lastActiveIndex = widget.activeIndex;
    for (int i = 0; i < widget.cards.length; i++) {
      _cardKeys.add(GlobalKey());
    }
    _scrollToActive();
  }

  @override
  void didUpdateWidget(covariant _PlayerStripDesktop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_lastActiveIndex != widget.activeIndex) {
      _lastActiveIndex = widget.activeIndex;
      _scrollToActive();
    }
    if (oldWidget.cards.length != widget.cards.length) {
      _cardKeys.clear();
      for (int i = 0; i < widget.cards.length; i++) {
        _cardKeys.add(GlobalKey());
      }
    }
  }

  double _getCardHeight(int index) {
    final renderBox = _cardKeys[index].currentContext?.findRenderObject() as RenderBox?;
    return renderBox?.size.height ?? 85.0;
  }

  void _scrollToActive() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: widget.t.surface.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        controller: _verticalController,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(widget.cards.length, (index) {
            return Padding(
              padding: EdgeInsets.only(bottom: index == widget.cards.length - 1 ? 0 : 8),
              child: Container(
                key: _cardKeys[index],
                child: widget.cards[index],
              ),
            );
          }),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _verticalController.dispose();
    super.dispose();
  }
}
