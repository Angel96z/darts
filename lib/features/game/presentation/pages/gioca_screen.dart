import 'package:flutter/material.dart';

import '../../../darts_match/presentation/lobby/pages/room_lobby_shell_page.dart';

class GiocaScreen extends StatelessWidget {
  const GiocaScreen({super.key});

  void _openRoomLobby(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const RoomLobbyShellPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Multiplayer',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.meeting_room),
            title: const Text('Room online'),
            subtitle: const Text('Crea o entra in una room'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => _openRoomLobby(context),
          ),
        ),
      ],
    );
  }
}
