import 'package:flutter/material.dart';
import '../logic/score_controller.dart';

class ScoreView extends StatelessWidget {

  final ScoreController controller;

  const ScoreView({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {

    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {

        return Column(
          children: [

            Text(
              "Totale ${controller.total}",
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

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