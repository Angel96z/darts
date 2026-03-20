import 'package:flutter/material.dart';
import '../logic/score_controller.dart';

class DartKeyboardInput extends StatelessWidget {

  final ScoreController controller;

  const DartKeyboardInput({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {

    List<int> numbers = List.generate(20, (i) => i + 1);

    return GridView.count(
      crossAxisCount: 5,
      children: [

        for (var n in numbers)
          _btn("S$n", n),

        for (var n in numbers)
          _btn("D$n", n * 2),

        for (var n in numbers)
          _btn("T$n", n * 3),

        _btn("25", 25),
        _btn("50", 50),

      ],
    );
  }

  Widget _btn(String label, int score) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: ElevatedButton(
        onPressed: () {
          controller.registerHit(label, score);
        },
        child: Text(label),
      ),
    );
  }
}