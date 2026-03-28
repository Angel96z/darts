/// File: turn_keyboard_input.dart. Contiene componenti condivisi usati in più parti dell'app.

import 'package:flutter/material.dart';
import '../../features/score/presentation/state/score_controller.dart';

class TurnKeyboardInput extends StatelessWidget {

  final ScoreController controller;

  /// Funzione: descrive in modo semplice questo blocco di logica.
  const TurnKeyboardInput({
    super.key,
    required this.controller,
  });

  @override
  /// Funzione: descrive in modo semplice questo blocco di logica.
  Widget build(BuildContext context) {

    return GridView.count(
      crossAxisCount: 4,
      children: [

        for (int i = 0; i <= 180; i += 10)
          /// Funzione: descrive in modo semplice questo blocco di logica.
          Padding(
            padding: const EdgeInsets.all(6),
            child: ElevatedButton(
              onPressed: () {
                controller.registerTurn(i);
              },
              child: Text("$i"),
            ),
          ),

      ],
    );
  }
}
