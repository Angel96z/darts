import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'room_data.dart';

/// MODELLO UTENTE CORRENTE (solo runtime, NON DB)
class RoomCurrentUser {
  final String uid;
  final String? email;
  final String? name;

  const RoomCurrentUser({
    required this.uid,
    required this.email,
    required this.name,
  });

  factory RoomCurrentUser.fromAuth(User user) {
    return RoomCurrentUser(
      uid: user.uid,
      email: user.email,
      name: user.displayName,
    );
  }

  static RoomCurrentUser get current {
    final user = FirebaseAuth.instance.currentUser!;
    return RoomCurrentUser.fromAuth(user);
  }
}
/// AGGIUNGE UN ADMIN ALLA ROOM
Future<void> addAdminToRoom(RoomData data, Function(RoomData) update) async {
  final uid = RoomCurrentUser.current.uid;

  if (data.adminIds.contains(uid)) return;

  final updated = data.copyWith(
    adminIds: List.from(data.adminIds)..add(uid),
  );

  await update(updated);
}

/// CONTROLLA SE UTENTE È ADMIN
bool isCurrentUserAdmin(List<String> adminIds) {
  final uid = RoomCurrentUser.current.uid;
  return adminIds.contains(uid);
}
/// UI → mostra dati utente corrente
class RoomCurrentUserView extends StatelessWidget {
  const RoomCurrentUserView({super.key});

  @override
  Widget build(BuildContext context) {
    final user = RoomCurrentUser.current;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('UTENTE'),

        const SizedBox(height: 8),

        Text('UID: ${user.uid}'),

        const SizedBox(height: 4),

        Text('EMAIL: ${user.email ?? "-"}'),

        const SizedBox(height: 4),

        Text('NAME: ${user.name ?? "-"}'),
      ],
    );
  }
}