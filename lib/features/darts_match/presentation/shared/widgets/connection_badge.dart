import 'package:flutter/material.dart';

import '../view_models/connection_badge_vm.dart';

class ConnectionBadge extends StatelessWidget {
  const ConnectionBadge({super.key, required this.vm});

  final ConnectionBadgeVm vm;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(vm.label),
      backgroundColor: vm.isOnline ? Colors.green : Colors.grey,
      labelStyle: const TextStyle(color: Colors.white),
    );
  }
}
