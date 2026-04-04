/// Obiettivo: definire in modo chiaro dove deve stare l’utente.
/// Lobby e Match sono schermate base.
/// Result è un overlay locale sopra la schermata base.
import 'package:darts/features/room_v2/room_data.dart';
import 'package:darts/features/room_v2/room_lobby_v2_page.dart';
import 'package:darts/features/room_v2/room_repository.dart';
import 'package:darts/features/room_v2/room_result_page.dart';
import 'package:flutter/material.dart';
import 'room_match_page.dart';

enum RoomUserLocation {
  lobby,
  match,
}

class RoomGate extends StatefulWidget {
  final RoomRepository repo;

  const RoomGate({
    super.key,
    required this.repo,
  });

  @override
  State<RoomGate> createState() => _RoomGateState();
}

class _RoomGateState extends State<RoomGate> {
  bool _showResultOverlay = false;
  RoomPhase? _lastPhase;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<RoomData>(
      stream: widget.repo.watch(),
      initialData: widget.repo.current,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final data = snapshot.data!;

        if (_lastPhase != RoomPhase.result && data.phase == RoomPhase.result) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _showResultOverlay = true;
            });
          });
        }

        _lastPhase = data.phase;

        final location = resolveUserLocation(RoomState(
          roomId: data.roomId,
          phase: data.phase,
        ));

        Widget basePage;
        switch (location) {
          case RoomUserLocation.lobby:
            basePage = RoomLobbyV2Page(
              data: data,
              repo: widget.repo,
            );
            break;
          case RoomUserLocation.match:
            basePage = RoomMatchPage(
              data: data,
              repo: widget.repo,
            );
            break;
        }

        return Stack(
          children: [
            Positioned.fill(child: basePage),
            if (_showResultOverlay)
              Positioned.fill(
                child: RoomResultPage(
                  data: data,
                  repo: widget.repo,
                  onClose: () {
                    if (!mounted) return;
                    setState(() {
                      _showResultOverlay = false;
                    });
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Stato minimo della room.
class RoomState {
  final String? roomId;
  final RoomPhase phase;

  const RoomState({
    required this.roomId,
    required this.phase,
  });
}

/// Result non è una schermata base.
/// Serve solo come trigger overlay.
RoomUserLocation resolveUserLocation(RoomState state) {
  switch (state.phase) {
    case RoomPhase.match:
      return RoomUserLocation.match;
    case RoomPhase.result:
      return RoomUserLocation.match;
    case RoomPhase.lobby:
      return RoomUserLocation.lobby;
  }
}