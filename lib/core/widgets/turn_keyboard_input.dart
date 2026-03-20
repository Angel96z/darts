import 'package:flutter/material.dart';
import '../../features/score/presentation/state/score_controller.dart';

class TurnKeyboardInput extends StatelessWidget {

  final ScoreController controller;

  const TurnKeyboardInput({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {

    return GridView.count(
      crossAxisCount: 4,
      children: [

        for (int i = 0; i <= 180; i += 10)
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