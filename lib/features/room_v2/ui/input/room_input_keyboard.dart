import 'dart:async';
import 'package:flutter/material.dart';
import 'package:darts/features/room_v2/games_darts.dart';
import 'package:darts/features/room_v2/room_data.dart';
import 'package:darts/features/room_v2/core/room_match_engine.dart';
import 'package:darts/features/room_v2/room_repository.dart';
import 'package:darts/features/room_v2/room_current_user.dart';
import 'package:darts/features/room_v2/utils/player_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/offline_controller.dart';

class RoomInputKeyboard extends ConsumerWidget {
  final RoomData data;
  final RoomRepository repo;

  const RoomInputKeyboard({
    super.key,
    required this.data,
    required this.repo,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(offlineControllerProvider);

    final player = resolveActiveInputPlayer(data, RoomCurrentUser.current.uid);

    if (player == null || player['turn'] != true) {
      return const SizedBox.shrink();
    }

    final isCricket = data.game.type == GameType.cricket;
    final currentMode = isCricket ? 'dart' : (player['inputMode'] ?? 'dart');

    final canSwitch = canSwitchInputMode(player);
    final showOfflineOverlay = data.roomId != null && isOnline != true;

    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isCricket) ...[
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2C2E),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ModeButton(
                        label: 'DART',
                        active: currentMode == 'dart',
                        onTap: canSwitch && currentMode != 'dart'
                            ? () async {
                          await repo.enqueue(() async {
                            final current = repo.current!;
                            final updated = copyWithPlayerInputMode(
                              current,
                              player['id'],
                              'dart',
                            );
                            await repo.update(updated);
                          });
                        }
                            : null,
                      ),
                      _ModeButton(
                        label: 'TOTAL',
                        active: currentMode == 'total',
                        onTap: canSwitch && currentMode != 'total'
                            ? () async {
                          await repo.enqueue(() async {
                            final current = repo.current!;
                            final updated = copyWithPlayerInputMode(
                              current,
                              player['id'],
                              'total',
                            );
                            await repo.update(updated);
                          });
                        }
                            : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
              const SizedBox(height: 20),

              if (data.game.type == GameType.cricket)
                _CricketKeyboard(data: data, repo: repo, player: player)
              else if (currentMode == 'dart')
                _DartKeyboard(data: data, repo: repo, player: player)
              else
                _TotalKeyboard(data: data, repo: repo, player: player),
            ],
          ),
        ),

        if (showOfflineOverlay)
          Positioned.fill(
            child: AbsorbPointer(
              absorbing: true,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Center(
                  child: Icon(Icons.wifi_off, size: 32, color: Colors.white54),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback? onTap;

  const _ModeButton({
    required this.label,
    required this.active,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF0A84FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : Colors.grey.shade500,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

//////////////////////////////////////////////////////////////
/// DART KEYBOARD
//////////////////////////////////////////////////////////////

class _DartKeyboard extends StatefulWidget {
  final RoomData data;
  final RoomRepository repo;
  final Map<String, dynamic> player;

  const _DartKeyboard({
    required this.data,
    required this.repo,
    required this.player,
  });

  @override
  State<_DartKeyboard> createState() => _DartKeyboardState();
}

class _DartKeyboardState extends State<_DartKeyboard> {
  int multiplier = 1;
  Timer? _commitTimer;

  @override
  void dispose() {
    _commitTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canUndo = canUndoForPlayer(widget.data, widget.player);

    return Column(
      children: [
        // Multiplier row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _MultiplierChip(label: 'D', value: 2, current: multiplier, onTap: () => setState(() => multiplier = multiplier == 2 ? 1 : 2)),
            const SizedBox(width: 8),
            _MultiplierChip(label: 'T', value: 3, current: multiplier, onTap: () => setState(() => multiplier = multiplier == 3 ? 1 : 3)),
          ],
        ),
        const SizedBox(height: 16),

        // Numbers grid
        Wrap(
          spacing: 6,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: [
            for (int i = 1; i <= 20; i++) _DartKey(i, disabled: isTripleBullDisabled(multiplier, i)),
            _DartKey(25, disabled: isTripleBullDisabled(multiplier, 25)),
          ],
        ),
        const SizedBox(height: 12),

        // Action row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ActionChip('MISS', () => _handleThrow(0), isDestructive: true),
            const SizedBox(width: 8),
            _ActionChip('UNDO', canUndo ? _undo : null, isSecondary: true),
          ],
        ),
      ],
    );
  }

  void _handleThrow(int base) async {
    _commitTimer?.cancel();

    final current = widget.repo.current!;

    final intent = {
      'type': 'dart',
      'number': base == 0 ? null : base,
      'multiplier': base == 0 ? 0 : multiplier,
      'isMiss': base == 0,
    };

    final isCheckout = RoomMatchEngineLogic.wouldCheckoutDart(
      current,
      widget.player['id'],
      intent,
    );

    if (isCheckout) {
      _showConfirm(intent);
      return;
    }

    final newState = RoomMatchEngineLogic.applyThrow(
      current,
      widget.player['id'],
      intent,
    );

    await widget.repo.enqueue(() async {
      await widget.repo.update(newState);
    });

    final updatedPlayer = newState.players.firstWhere(
          (p) => p['id'] == widget.player['id'],
      orElse: () => {},
    );

    if (updatedPlayer.isEmpty) return;

    if (RoomMatchEngineLogic.isTurnEnded(updatedPlayer)) {
      _commitTimer = Timer(const Duration(seconds: 3), () async {
        await widget.repo.enqueue(() async {
          final latest = widget.repo.current!;
          final committed = RoomMatchEngineLogic.commitTurn(
            latest,
            widget.player['id'],
          );
          await widget.repo.update(committed);
        });
      });
    }

    setState(() => multiplier = 1);
  }

  void _showConfirm(Map<String, dynamic> intent) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2E),
        title: const Text('Checkout?', style: TextStyle(color: Colors.white)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('NO', style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await widget.repo.enqueue(() async {
                final current = widget.repo.current!;
                final applied = RoomMatchEngineLogic.applyThrow(current, widget.player['id'], intent);
                final committed = RoomMatchEngineLogic.commitTurn(applied, widget.player['id']);
                await widget.repo.update(committed);
              });
            },
            child: const Text('YES', style: TextStyle(color: Color(0xFF0A84FF))),
          ),
        ],
      ),
    );
  }

  void _undo() async {
    await widget.repo.enqueue(() async {
      final latest = widget.repo.current!;
      final newState = RoomMatchEngineLogic.undoLastThrow(latest);
      await widget.repo.update(newState);
    });
  }
}

class _MultiplierChip extends StatelessWidget {
  final String label;
  final int value;
  final int current;
  final VoidCallback onTap;

  const _MultiplierChip({
    required this.label,
    required this.value,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = current == value;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: active ? const Color(0xFF0A84FF) : const Color(0xFF2C2C2E),
          borderRadius: BorderRadius.circular(24),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : Colors.grey.shade400,
          ),
        ),
      ),
    );
  }
}

class _DartKey extends StatelessWidget {
  final int number;
  final bool disabled;

  const _DartKey(this.number, {required this.disabled});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : () => context.findAncestorStateOfType<_DartKeyboardState>()?._handleThrow(number),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: disabled ? const Color(0xFF1C1C1E) : const Color(0xFF2C2C2E),
          borderRadius: BorderRadius.circular(24),
        ),
        alignment: Alignment.center,
        child: Text(
          number.toString(),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: disabled ? Colors.grey.shade700 : Colors.white,
          ),
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool isDestructive;
  final bool isSecondary;

  const _ActionChip(this.label, this.onTap, {this.isDestructive = false, this.isSecondary = false});

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    if (isDestructive) {
      bgColor = const Color(0xFFFF453A);
    } else if (isSecondary) {
      bgColor = const Color(0xFF2C2C2E);
    } else {
      bgColor = const Color(0xFF0A84FF);
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: onTap == null ? const Color(0xFF1C1C1E) : bgColor,
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: onTap == null ? Colors.grey.shade700 : Colors.white,
          ),
        ),
      ),
    );
  }
}

//////////////////////////////////////////////////////////////
/// TOTAL KEYBOARD
//////////////////////////////////////////////////////////////

class _TotalKeyboard extends StatefulWidget {
  final RoomData data;
  final RoomRepository repo;
  final Map<String, dynamic> player;

  const _TotalKeyboard({
    required this.data,
    required this.repo,
    required this.player,
  });

  @override
  State<_TotalKeyboard> createState() => _TotalKeyboardState();
}

class _TotalKeyboardState extends State<_TotalKeyboard> {
  String input = '';
  Timer? _commitTimer;

  @override
  void dispose() {
    _commitTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canUndo = canUndoForPlayer(widget.data, widget.player);

    return Column(
      children: [
        // Display
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF0C0C0E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            input.isEmpty ? '0' : input,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              fontFamily: 'monospace',
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Number pad
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (int i = 1; i <= 9; i++) _TotalNumKey(i),
            _TotalNumKey(0),
          ],
        ),
        const SizedBox(height: 12),

        // Action row
        Wrap(
          spacing: 6,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: [
            _TotalAction('C', _clear, isSecondary: true),
            _TotalAction('✓', _submit, isPrimary: true),
            _TotalAction('CK', _checkout, isPrimary: true),
            _TotalAction('M', _miss, isDestructive: true),
            _TotalAction('B', _bust, isDestructive: true),
            _TotalAction('↺', canUndo ? _undo : null, isSecondary: true),
          ],
        ),
      ],
    );
  }

  Widget _TotalNumKey(int number) {
    return GestureDetector(
      onTap: () {
        if (canAppendTotalInput(input, number)) {
          setState(() => input += '$number');
        }
      },
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2E),
          borderRadius: BorderRadius.circular(28),
        ),
        alignment: Alignment.center,
        child: Text(
          '$number',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500, color: Colors.white),
        ),
      ),
    );
  }

  Widget _TotalAction(String label, VoidCallback? onTap, {bool isPrimary = false, bool isSecondary = false, bool isDestructive = false}) {
    Color bgColor;
    if (isPrimary) {
      bgColor = const Color(0xFF0A84FF);
    } else if (isDestructive) {
      bgColor = const Color(0xFFFF453A);
    } else {
      bgColor = const Color(0xFF2C2C2E);
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 48,
        decoration: BoxDecoration(
          color: onTap == null ? const Color(0xFF1C1C1E) : bgColor,
          borderRadius: BorderRadius.circular(24),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: label.length > 1 ? 13 : 18,
            fontWeight: FontWeight.w600,
            color: onTap == null ? Colors.grey.shade700 : Colors.white,
          ),
        ),
      ),
    );
  }

  void _clear() => setState(() => input = '');

  Future<void> _processIntent(Map<String, dynamic> intent) async {
    _commitTimer?.cancel();

    final current = widget.repo.current!;
    final isCheckout = RoomMatchEngineLogic.wouldCheckout(current, widget.player['id'], intent);

    if (isCheckout) {
      _showConfirm(intent);
      return;
    }

    final applied = RoomMatchEngineLogic.applyIntent(current, widget.player['id'], intent);
    await widget.repo.enqueue(() async => widget.repo.update(applied));

    final updatedPlayer = applied.players.firstWhere((p) => p['id'] == widget.player['id'], orElse: () => {});
    if (updatedPlayer.isEmpty) return;

    if (RoomMatchEngineLogic.isTurnEnded(updatedPlayer)) {
      _commitTimer = Timer(const Duration(seconds: 3), () async {
        await widget.repo.enqueue(() async {
          final latest = widget.repo.current!;
          final committed = RoomMatchEngineLogic.commitTurn(latest, widget.player['id']);
          await widget.repo.update(committed);
        });
      });
    }

    setState(() => input = '');
  }

  void _submit() async {
    final value = int.tryParse(input);
    if (value == null) return;
    await _processIntent({'type': 'total', 'value': value});
  }

  void _checkout() async => _processIntent({'type': 'checkout'});
  void _miss() async => _processIntent({'type': 'miss'});
  void _bust() async => _processIntent({'type': 'bust'});

  void _undo() async {
    _commitTimer?.cancel();
    await widget.repo.enqueue(() async {
      final latest = widget.repo.current!;
      final newState = RoomMatchEngineLogic.undoLastThrow(latest);
      await widget.repo.update(newState);
    });
  }

  void _showConfirm(Map<String, dynamic> intent) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2E),
        title: const Text('Checkout?', style: TextStyle(color: Colors.white)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('NO', style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              _commitTimer?.cancel();
              await widget.repo.enqueue(() async {
                final current = widget.repo.current!;
                final applied = RoomMatchEngineLogic.applyIntent(current, widget.player['id'], intent);
                final committed = RoomMatchEngineLogic.commitTurn(applied, widget.player['id']);
                await widget.repo.update(committed);
              });
              setState(() => input = '');
            },
            child: const Text('YES', style: TextStyle(color: Color(0xFF0A84FF))),
          ),
        ],
      ),
    );
  }
}

//////////////////////////////////////////////////////////////
/// CRICKET KEYBOARD
//////////////////////////////////////////////////////////////

class _CricketKeyboard extends StatefulWidget {
  final RoomData data;
  final RoomRepository repo;
  final Map<String, dynamic> player;

  const _CricketKeyboard({
    required this.data,
    required this.repo,
    required this.player,
  });

  @override
  State<_CricketKeyboard> createState() => _CricketKeyboardState();
}

class _CricketKeyboardState extends State<_CricketKeyboard> {
  Timer? _commitTimer;

  static const List<int> _targets = [20, 19, 18, 17, 16, 15, 25];

  @override
  void dispose() {
    _commitTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canUndo = canUndoForPlayer(widget.data, widget.player);

    return Column(
      children: [
        Column(
          children: _targets.map((target) {
            final isBull = target == 25;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 72,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C2C2E),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      isBull ? '25' : '$target',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: _CricketHitButton(
                            label: 'S',
                            onTap: () => _throw(target, 1),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _CricketHitButton(
                            label: 'D',
                            onTap: () => _throw(target, 2),
                          ),
                        ),
                        if (!isBull) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: _CricketHitButton(
                              label: 'T',
                              onTap: () => _throw(target, 3),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: _ActionChip(
                'MISS',
                    () => _throw(null, 0),
                isDestructive: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionChip(
                'UNDO',
                canUndo ? _undo : null,
                isSecondary: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _throw(int? base, int multiplier) async {
    _commitTimer?.cancel();

    final current = widget.repo.current!;

    final intent = {
      'type': 'dart',
      'number': base,
      'multiplier': multiplier,
      'isMiss': base == null,
    };

    final isWin = RoomMatchEngineLogic.wouldWinCricket(
      current,
      widget.player['id'],
      intent,
    );

    if (isWin) {
      _confirm(intent);
      return;
    }

    final newState = RoomMatchEngineLogic.applyThrow(
      current,
      widget.player['id'],
      intent,
    );

    await widget.repo.enqueue(() async {
      await widget.repo.update(newState);
    });

    final updatedPlayer = newState.players.firstWhere(
          (p) => p['id'] == widget.player['id'],
      orElse: () => {},
    );

    if (updatedPlayer.isEmpty) return;

    if (RoomMatchEngineLogic.isTurnEnded(updatedPlayer)) {
      _commitTimer = Timer(const Duration(seconds: 3), () async {
        await widget.repo.enqueue(() async {
          final latest = widget.repo.current!;
          final committed = RoomMatchEngineLogic.commitTurn(
            latest,
            widget.player['id'],
          );
          await widget.repo.update(committed);
        });
      });
    }
  }

  void _confirm(Map<String, dynamic> intent) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2E),
        title: const Text('Win match?', style: TextStyle(color: Colors.white)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('NO', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              await widget.repo.enqueue(() async {
                final current = widget.repo.current!;
                final applied = RoomMatchEngineLogic.applyThrow(
                  current,
                  widget.player['id'],
                  intent,
                );
                final committed = RoomMatchEngineLogic.commitTurn(
                  applied,
                  widget.player['id'],
                );
                await widget.repo.update(committed);
              });
            },
            child: const Text(
              'YES',
              style: TextStyle(color: Color(0xFF0A84FF)),
            ),
          ),
        ],
      ),
    );
  }

  void _undo() async {
    _commitTimer?.cancel();

    await widget.repo.enqueue(() async {
      final latest = widget.repo.current!;
      final newState = RoomMatchEngineLogic.undoLastThrow(latest);
      await widget.repo.update(newState);
    });
  }
}

class _CricketHitButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _CricketHitButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFF0A84FF),
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

