import '../../../domain/entities/room.dart';

class ConnectionBadgeVm {
  const ConnectionBadgeVm({required this.state});

  final ConnectionState state;

  String get label => state.name;
}
