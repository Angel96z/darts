class ConnectionBadgeVm {
  const ConnectionBadgeVm({required this.isOnline});

  final bool isOnline;

  String get label => isOnline ? 'ONLINE' : 'OFFLINE';
}