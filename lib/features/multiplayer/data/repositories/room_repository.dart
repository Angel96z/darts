import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models.dart';

class RoomRepository {
  RoomRepository(this._firestore);

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> roomRef(String roomId) =>
      _firestore.collection('rooms').doc(roomId);

  Stream<RoomSnapshot?> watchRoom(String roomId) {
    return roomRef(roomId).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }
      return RoomSnapshot.fromMap(snapshot.id, snapshot.data()!);
    });
  }

  Future<RoomSnapshot?> getRoom(String roomId) async {
    final snapshot = await roomRef(roomId).get();
    if (!snapshot.exists || snapshot.data() == null) {
      return null;
    }
    return RoomSnapshot.fromMap(snapshot.id, snapshot.data()!);
  }

  Future<void> createRoom({required String roomId, required RoomSnapshot room}) {
    return roomRef(roomId).set(room.toMap());
  }

  Future<void> updateRoomFields(String roomId, Map<String, dynamic> fields) {
    return roomRef(roomId).update(fields);
  }

  Future<void> deleteRoom(String roomId) {
    return roomRef(roomId).delete();
  }

  Future<T> runRoomTransaction<T>(
    String roomId,
    Future<T> Function(Transaction tx, DocumentReference<Map<String, dynamic>> roomRef) action,
  ) {
    return _firestore.runTransaction((tx) async {
      return action(tx, this.roomRef(roomId));
    });
  }
}
