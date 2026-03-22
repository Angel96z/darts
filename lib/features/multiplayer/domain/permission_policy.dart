import 'enums.dart';
import 'models.dart';

class PermissionPolicy {
  static bool canEditConfig({required RoomSnapshot room, required Session actor}) {
    return room.status == RoomStatus.waiting && actor.authUid == room.hostUid;
  }

  static bool canAddPlayer({required RoomSnapshot room, required Session actor}) {
    return room.status == RoomStatus.waiting && actor.authUid == room.hostUid;
  }

  static bool canRemovePlayer({
    required RoomSnapshot room,
    required Session actor,
    required RoomParticipant target,
  }) {
    if (room.status != RoomStatus.waiting) {
      return false;
    }
    if (actor.authUid == room.hostUid) {
      return target.role != RoomRole.host;
    }
    return target.ownerParticipantId == actor.participantId;
  }

  static bool canStartMatch({required RoomSnapshot room, required Session actor}) {
    return room.status == RoomStatus.waiting && actor.authUid == room.hostUid;
  }

  static bool canSubmitTurn({
    required RoomSnapshot room,
    required MatchSnapshot match,
    required Session actor,
  }) {
    return room.status == RoomStatus.inGame &&
        match.status == MatchStatus.active &&
        actor.participantId == match.turnParticipantId;
  }

  static bool canCloseRoom({required RoomSnapshot room, required Session actor}) {
    return actor.authUid == room.hostUid;
  }
}
