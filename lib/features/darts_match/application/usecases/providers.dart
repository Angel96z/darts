import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/firestore/firestore_command_datasource.dart';
import '../../data/datasources/firestore/firestore_match_datasource.dart';
import '../../data/datasources/firestore/firestore_room_datasource.dart';
import '../../data/datasources/rtdb_presence/rtdb_presence_datasource.dart';
import '../../data/mappers/match_mapper.dart';
import '../../data/mappers/room_mapper.dart';
import '../../data/repositories/firebase_repositories.dart';
import '../../domain/repositories/repositories.dart';

final roomRepositoryProvider = Provider<RoomRepository>((ref) {
  return FirebaseRoomRepository(
    FirestoreRoomDataSource(FirebaseFirestore.instance),
    const RoomMapper(),
  );
});

final matchRepositoryProvider = Provider<MatchRepository>((ref) {
  return FirebaseMatchRepository(
    FirestoreMatchDataSource(FirebaseFirestore.instance),
    const MatchMapper(),
  );
});

final commandRepositoryProvider = Provider<CommandRepository>((ref) {
  return FirebaseCommandRepository(FirestoreCommandDataSource(FirebaseFirestore.instance));
});

final presenceRepositoryProvider = Provider<PresenceRepository>((ref) {
  return FirebasePresenceRepository(RtdbPresenceDataSource(FirebaseDatabase.instance));
});
