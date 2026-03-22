import '../domain/enums.dart';
import '../domain/models.dart';

enum RoomScreenTarget { home, lobby, match, result }

class RoomFlowController {
  RoomScreenTarget resolve({
    required RoomSnapshot? room,
    required MatchSnapshot? match,
    required Session? session,
  }) {
    if (room == null || session == null) {
      return RoomScreenTarget.home;
    }

    if (room.status == RoomStatus.closed) {
      return RoomScreenTarget.home;
    }

    switch (room.status) {
      case RoomStatus.waiting:
        return RoomScreenTarget.lobby;
      case RoomStatus.inGame:
        return RoomScreenTarget.match;
      case RoomStatus.terminated:
        return RoomScreenTarget.result;
      case RoomStatus.closed:
        return RoomScreenTarget.home;
    }
  }
}
