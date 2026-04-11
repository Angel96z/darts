import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'room_repository.dart';

final _roomRepository = RoomRepository(FirebaseFirestore.instance);

final roomRepositoryProvider = Provider<RoomRepository>((ref) {
  return _roomRepository;
});