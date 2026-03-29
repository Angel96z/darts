/// File: gioca_screen.dart. Contiene logica di presentazione (UI, widget o controller) per questa parte dell'app.

import 'package:flutter/material.dart';

import '../../../darts_match/presentation/lobby/pages/room_lobby_shell_page.dart';
import '../../../room_v2/room_lobby_v2_page.dart';
import '../../../room_v2/room_repository.dart';
import '../../../room_v2/room_data.dart';
import '../../../room_v2/room_user_flow.dart';
import '../../../room_v2/room_current_user.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
class GiocaScreen extends StatelessWidget {
  /// Funzione: descrive in modo semplice questo blocco di logica.
  const GiocaScreen({super.key});

  @override
  /// Funzione: descrive in modo semplice questo blocco di logica.
  Widget build(BuildContext context) {
    /// Funzione: descrive in modo semplice questo blocco di logica.
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        /// Funzione: descrive in modo semplice questo blocco di logica.
        Card(
          child: ListTile(
            leading: const Icon(Icons.meeting_room),
            title: const Text('Room online'),
            subtitle: const Text('Apri la nuova sezione Gioca'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              final now = DateTime.now().toIso8601String();

              // ignore: avoid_print
              print('========== NAVIGATION DEBUG ==========');
              // ignore: avoid_print
              print('action: open_room_lobby');
              // ignore: avoid_print
              print('timestamp: $now');
              // ignore: avoid_print
              print('route: RoomLobbyShellPage');
              // ignore: avoid_print
              print('=====================================');

              Navigator.push(
                context,
                /// Funzione: descrive in modo semplice questo blocco di logica.
                MaterialPageRoute(
                  builder: (_) {
                    final repo = RoomRepository(FirebaseFirestore.instance);

                    repo.initLocal(RoomData(
                      roomId: null,
                      createdAt: DateTime.now(),
                      gameMode: GameMode.x01,
                      x01: X01Variant.x501,
                      phase: RoomPhase.lobby,
                      adminIds: [RoomCurrentUser.current.uid],
                      players: [],
                    ));

                    return RoomGate(repo: repo);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
