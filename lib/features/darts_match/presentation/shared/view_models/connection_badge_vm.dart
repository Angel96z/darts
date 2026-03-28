/// File: connection_badge_vm.dart. Contiene logica di presentazione (UI, widget o controller) per questa parte dell'app.

class ConnectionBadgeVm {
  const ConnectionBadgeVm({required this.isOnline});

  final bool isOnline;

  String get label => isOnline ? 'ONLINE' : 'OFFLINE';
}