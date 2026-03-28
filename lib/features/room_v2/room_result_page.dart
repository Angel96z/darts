import 'package:flutter/material.dart';
import 'room_lobby_v2_page.dart';

/// Obiettivo: pagina risultati.
/// Responsabilità: UNA sola → mostrare fine partita e reset.
class RoomResultPage extends StatelessWidget {
  final String? roomId;

  const RoomResultPage({super.key, required this.roomId});

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => await _confirmExit(context),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Result'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text('RISULTATI'),

              const SizedBox(height: 16),

              /// torna a nuova lobby (reset totale)
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: const Text('Nuova lobby'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmExit(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Conferma'),
        content: const Text('Uscire dai risultati?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context, true);
            },
            child: const Text('Si'),
          ),
        ],
      ),
    );

    if (result == true) {
      Navigator.pop(context); // RESULT → MATCH
      Navigator.pop(context); // MATCH → LOBBY
      return false;
    }

    return false;
  }
}