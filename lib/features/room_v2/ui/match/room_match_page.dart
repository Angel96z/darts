import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:darts/features/room_v2/room_current_user.dart';
import 'package:darts/features/room_v2/user_room_repository.dart';
import 'package:flutter/material.dart';
import 'package:darts/features/room_v2/room_data.dart';
import 'package:darts/features/room_v2/ui/input/room_input_keyboard.dart';
import 'package:darts/features/room_v2/ui/match/match_layout.dart';
import 'package:darts/features/room_v2/room_repository.dart';

import '../../games_darts.dart';

class RoomMatchPage extends StatefulWidget {
  final RoomData data;
  final RoomRepository repo;

  const RoomMatchPage({
    super.key,
    required this.data,
    required this.repo,
  });

  @override
  State<RoomMatchPage> createState() => _RoomMatchPageState();
}

class _RoomMatchPageState extends State<RoomMatchPage> {
  int _lastHistoryLength = 0;
  bool _showCheckout = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _handleCheckout(RoomData data) {
    final history = data.history;

    // trigger solo su nuovo turno
    if (history.length == _lastHistoryLength) return;

    _lastHistoryLength = history.length;

    if (history.isEmpty) return;

    final last = history.last;

    if (last['endKind'] != 'checkout') return;

    _timer?.cancel();

    setState(() {
      _showCheckout = true;
    });

    _timer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() {
        _showCheckout = false;
      });
    });
  }

  Future<bool> handleExitLogic(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Conferma'),
        content: const Text('Abbandonare la partita?'),
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

    if (result != true) return false;

    final uid = RoomCurrentUser.current.uid;
    final isCreator = widget.data.creatorId == uid;

    try {
      if (isCreator) {
        await widget.repo.update(
          widget.data.copyWith(phase: RoomPhase.lobby),
        );
        return false;
      } else {
        final ownedPlayers = widget.data.players.where((p) {
          final owner = p['ownerId'];
          final id = p['id'];
          return owner == uid || id == uid;
        }).toList();

        for (final p in ownedPlayers) {
          final id = p['id'];
          final isGuest = p['isGuest'] == true;
          if (!isGuest && id != null) {
            await UserRoomRepository(FirebaseFirestore.instance)
                .clearCurrentRoom(id);
          }
        }
        return true;
      }
    } catch (e) {
      debugPrint("Errore durante l'uscita: $e");
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final repo = widget.repo;

    _handleCheckout(data);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final shouldPopPhysically = await handleExitLogic(context);

        if (shouldPopPhysically && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Stack(
        children: [
          Scaffold(
            appBar: AppBar(
              title: const Text('Match'),
            ),
            body: Column(
              children: [
                Expanded(
                  child: RoomMatchEngineView(
                    data: data,
                    repo: repo,
                  ),
                ),
                RoomInputKeyboard(
                  data: data,
                  repo: repo,
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      vertical: 10, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceVariant
                        .withOpacity(0.2),
                  ),
                  child: Center(
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        Text(
                          data.game.type == GameType.x01
                              ? '${data.game.startingScore ?? 501}'
                              : 'CRICKET',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (data.game.type == GameType.x01) ...[
                          if (data.game.doubleIn == true)
                            const Text('D-IN'),
                          if (data.game.doubleOut == true)
                            const Text('D-OUT'),
                          if (data.game.tripleOut == true)
                            const Text('T-OUT'),
                        ],
                        if (data.game.type == GameType.cricket) ...[
                          if (data.game.cutThroat == true)
                            const Text('CUT THROAT'),
                        ],
                        Text(
                          data.matchConfig.mode == MatchMode.firstTo
                              ? 'FIRST TO ${data.matchConfig.setsToWin} SET'
                              : 'BEST OF ${data.matchConfig.setCount} SET',
                        ),
                        Text('${data.matchConfig.legsToWin} LEG'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_showCheckout) _buildCheckoutOverlay(data),
        ],
      ),
    );
  }
}

Widget _buildCheckoutOverlay(RoomData data) {
  final last = data.history.isNotEmpty ? data.history.last : null;

  if (last == null) return const SizedBox.shrink();
  if (last['endKind'] != 'checkout') return const SizedBox.shrink();

  final playerId = last['playerId'];
  final total = last['total'];

  final player = data.players.firstWhere(
        (p) => p['id'] == playerId,
    orElse: () => {},
  );

  final name = player['name'] ?? '';

  return Positioned.fill(
    child: IgnorePointer(
      ignoring: true,
      child: Container(
        color: Colors.black.withOpacity(0.6),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Checkout $total',
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 28,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}