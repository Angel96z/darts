import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/result_controller.dart';

class ResultShellPage extends ConsumerWidget {
  const ResultShellPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(resultControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Match Result')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: result == null
            ? const Text('Result not available yet.')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Winner: ${result.winnerPlayerId?.value ?? result.winnerTeamId?.value ?? '-'}'),
                  Text('MVP: ${result.mvpPlayerId?.value ?? '-'}'),
                  Text('Highest score: ${result.highestScore}'),
                  const SizedBox(height: 12),
                  const Wrap(
                    spacing: 8,
                    children: [
                      FilledButton(onPressed: null, child: Text('Rigioca')),
                      FilledButton(onPressed: null, child: Text('Nuova room')),
                      FilledButton(onPressed: null, child: Text('Home')),
                      FilledButton(onPressed: null, child: Text('Dettaglio statistiche')),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}
