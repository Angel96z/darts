/// File: score_view.dart. Contiene componenti condivisi usati in più parti dell'app.

import 'package:flutter/material.dart';
import '../../features/score/presentation/state/score_controller.dart';

class ScoreView extends StatelessWidget {

  final ScoreController controller;

  /// Funzione: descrive in modo semplice questo blocco di logica.
  const ScoreView({
    super.key,
    required this.controller,
  });

  @override
  /// Funzione: descrive in modo semplice questo blocco di logica.
  Widget build(BuildContext context) {

    /// Funzione: descrive in modo semplice questo blocco di logica.
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {

        return Column(
          children: [

            /// Funzione: descrive in modo semplice questo blocco di logica.
            Text(
              "Totale ${controller.total}",
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            /// Funzione: descrive in modo semplice questo blocco di logica.
            Expanded(
              child: ListView.builder(
                itemCount: controller.scores.length,
                itemBuilder: (_, i) {

                  final s = controller.scores[i];

                  return ListTile(
                    title: Text(s.label),
                    trailing: Text("${s.score}"),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
