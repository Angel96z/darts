import 'package:flutter/material.dart';

import '../../../multiplayer/presentation/pages/multiplayer_room_page.dart';

class GiocaScreen extends StatelessWidget {
  const GiocaScreen({super.key});

  void _openRoomLobby(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const MultiplayerRoomPage(),
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
            subtitle: const Text('Nuova lobby multiplayer'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => _openRoomLobby(context),
          ),
        ),
      ],
    );
  }
}
