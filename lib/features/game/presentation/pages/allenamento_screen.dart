/// File: allenamento_screen.dart. Contiene logica di presentazione (UI, widget o controller) per questa parte dell'app.

import 'package:darts/features/stats/presentation/pages/training_screen.dart';
import 'package:darts/features/game/domain/entities/training_mode.dart';
import 'package:flutter/material.dart';

import '../../../stats/presentation/pages/training_stats_screen.dart';

class AllenamentoScreen extends StatelessWidget {
  /// Funzione: descrive in modo semplice questo blocco di logica.
  const AllenamentoScreen({super.key});

  @override
  /// Funzione: descrive in modo semplice questo blocco di logica.
  Widget build(BuildContext context) {

    /// Funzione: descrive in modo semplice questo blocco di logica.
    Widget buildMode(String title, TrainingMode mode, IconData icon) {
      /// Funzione: descrive in modo semplice questo blocco di logica.
      return Card(
        child: ListTile(
          leading: Icon(icon),
          title: Text(title),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              /// Funzione: descrive in modo semplice questo blocco di logica.
              IconButton(
                icon: const Icon(Icons.bar_chart),
                onPressed: () {
                  Navigator.push(
                    context,
                    /// Funzione: descrive in modo semplice questo blocco di logica.
                    MaterialPageRoute(
                      builder: (context) => TrainingStatsScreen(
                        title: title,
                        mode: mode,
                      ),
                    ),
                  );
                },
              ),
              /// Funzione: descrive in modo semplice questo blocco di logica.
              const Icon(Icons.arrow_forward_ios),
            ],
          ),
          onTap: () {
            Navigator.push(
              context,
              /// Funzione: descrive in modo semplice questo blocco di logica.
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
