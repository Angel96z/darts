import 'package:darts/features/room_v2/room_user_flow.dart';
import 'package:flutter/material.dart';
import 'room_result_page.dart';

/// Obiettivo: pagina match.
/// Responsabilità: UNA sola → gestire partita attiva.
class RoomMatchPage extends StatelessWidget {
  final String? roomId;

  const RoomMatchPage({super.key, required this.roomId});

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => await _confirmExit(context),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Match'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text('MATCH IN CORSO'),

              const SizedBox(height: 16),

              /// vai a RESULT
              ElevatedButton(
                onPressed: () {
                  goToResult(context, roomId);
                },
                child: const Text('Finish match'),
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
        content: const Text('Abbandonare la partita?'),
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
      Navigator.pop(context); // torna alla lobby
      return false;
    }

    return false;
  }
}