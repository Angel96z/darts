import 'package:darts/screens/training/training_screen.dart';
import 'package:darts/training/training_mode.dart';
import 'package:flutter/material.dart';

import 'training/training_stats_screen.dart';

class AllenamentoScreen extends StatelessWidget {
  const AllenamentoScreen({super.key});

  @override
  Widget build(BuildContext context) {

    Widget buildMode(String title, TrainingMode mode, IconData icon) {
      return Card(
        child: ListTile(
          leading: Icon(icon),
          title: Text(title),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.bar_chart),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TrainingStatsScreen(
                        title: title,
                        mode: mode,
                      ),
                    ),
                  );
                },
              ),
              const Icon(Icons.arrow_forward_ios),
            ],
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TrainingScreen(
                  title: title,
                  mode: mode,
                ),
              ),
            );
          },
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [

        buildMode("Rosa di tiro", TrainingMode.bull, Icons.adjust),

        buildMode("Settori singoli", TrainingMode.single, Icons.looks_one),

        buildMode("Settori doppi", TrainingMode.double, Icons.filter_2),

        buildMode("Settori tripli", TrainingMode.triple, Icons.filter_3),

      ],
    );
  }
}
