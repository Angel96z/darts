import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:darts/features/room_v2/room_current_user.dart';
import 'package:darts/features/room_v2/user_room_repository.dart';
import 'package:flutter/material.dart';
import 'room_data.dart';
import 'room_input_keyboard.dart';
import 'room_match_engine.dart';
import 'room_repository.dart';

class RoomMatchPage extends StatelessWidget {
  final RoomData data;
  final RoomRepository repo;

  const RoomMatchPage({
    super.key,
    required this.data,
    required this.repo,
  });

  Future<void> _finishMatch() async {
    await repo.update(data.copyWith(phase: RoomPhase.result));
  }

  /// Restituisce TRUE se l'uscita è confermata, FALSE altrimenti.
  /// Gestisce internamente la pulizia del DB.
  Future<bool> handleExitLogic(BuildContext context) async {
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
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Si'),
          ),
        ],
      ),
    );

    if (result != true) return false;

    final uid = RoomCurrentUser.current.uid;
    final isCreator = data.creatorId == uid;

    try {
      if (isCreator) {
        // IL CREATOR riporta la stanza in lobby per tutti
        await repo.update(data.copyWith(phase: RoomPhase.lobby));
        // In questo caso NON facciamo il pop manuale perché
        // il RoomGate reagirà al cambio di fase portando il creator in lobby.
        return false;
      } else {
        // IL PARTECIPANTE si disconnette e basta
        final ownedPlayers = data.players.where((p) {
          final owner = p['ownerId'];
          final id = p['id'];
          return owner == uid || id == uid;
        }).toList();

        for (final p in ownedPlayers) {
          final id = p['id'];
          final isGuest = p['isGuest'] == true;
          if (!isGuest && id != null) {
            await UserRoomRepository(FirebaseFirestore.instance)
                .clearCurrentRoom(id);
          }
        }
        // Restituiamo true per dire al PopScope di eseguire il Navigator.pop
        return true;
      }
    } catch (e) {
      debugPrint("Errore durante l'uscita: $e");
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // Eseguiamo la logica di uscita
        final shouldPopPhysically = await handleExitLogic(context);

        if (shouldPopPhysically && context.mounted) {
          // Se partecipante: esce fisicamente dal RoomGate e torna alla sezione GIOCA
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Match'),
        ),
        body: Column(
          children: [
            Expanded(
              child: RoomMatchEngineView(data: data),
            ),

            RoomInputKeyboard(
              data: data,
              repo: repo,
            ),
          ],
        ),
      ),
    );
  }
}