import 'package:equatable/equatable.dart';

class RoomId extends Equatable {
  const RoomId(this.value);
  final String value;
  @override
  List<Object?> get props => [value];
}

class MatchId extends Equatable {
  const MatchId(this.value);
  final String value;
  @override
  List<Object?> get props => [value];
}

class TeamId extends Equatable {
  const TeamId(this.value);
  final String value;
  @override
  List<Object?> get props => [value];
}

class PlayerId extends Equatable {
  const PlayerId(this.value);
  final String value;
  @override
  List<Object?> get props => [value];
}

class CommandId extends Equatable {
  const CommandId(this.value);
  final String value;
  @override
  List<Object?> get props => [value];
}

class EventId extends Equatable {
  const EventId(this.value);
  final String value;
  @override
  List<Object?> get props => [value];
}
