// TARGET: Barra di riepilogo configurazione match
// LOGIC GOAL: Mostrare le configurazioni del match lette da RoomState
// REACTION: UI mostra badge con le regole del match

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app_theme.dart';
import '../../application/room_notifier.dart';
import '../../domain/models/game_config.dart';

class MatchConfigBar extends ConsumerWidget {
  const MatchConfigBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppTokens.of(context);
    final tt = Theme.of(context).textTheme;
    final gameConfig = ref.watch(roomNotifierProvider.select((s) => s.gameConfig));
    final matchConfig = ref.watch(roomNotifierProvider.select((s) => s.matchConfig));
    final teamSize = ref.watch(roomNotifierProvider.select((s) => s.teamSize));

    final configLines = <String>[];

    // Modalità team
    if (teamSize > 1) {
      configLines.add('${teamSize}v${teamSize}');
    }

    // Punteggio iniziale (X01)
    if (gameConfig.type == GameType.x01 && gameConfig.startingScore != null) {
      configLines.add('${gameConfig.startingScore}');
    }

    // Regole di entrata/uscita (X01)
    if (gameConfig.type == GameType.x01) {
      if (gameConfig.doubleIn == true) {
        configLines.add('double in');
      }
      if (gameConfig.doubleOut == true) {
        configLines.add('double out');
      }
      if (gameConfig.tripleOut == true) {
        configLines.add('triple out');
      }
    }

    // Modalità match (set e leg)
    if (matchConfig.mode == MatchMode.firstTo) {
      configLines.add('First to ${matchConfig.setsToWin} set');
      configLines.add('${matchConfig.legsToWin} leg');
    } else {
      configLines.add('Best of ${matchConfig.setCount} set');
      configLines.add('${matchConfig.legCount} leg');
    }

    // Cut Throat (Cricket)
    if (gameConfig.type == GameType.cricket && gameConfig.cutThroat == true) {
      configLines.add('cut throat');
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(0.2),
          ),
        ),
      ),
      child: Center(
        child: Text(
          configLines.join(' · '),
          style: tt.bodySmall?.copyWith(color: t.textSecondary),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
