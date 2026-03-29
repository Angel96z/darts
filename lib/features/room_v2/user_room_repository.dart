import 'package:cloud_firestore/cloud_firestore.dart';

class UserRoomRepository {
  final FirebaseFirestore db;

  UserRoomRepository(this.db);

  Future<void> setCurrentRoom(String uid, String roomId) async {
    await db.collection('users').doc(uid).set({
      'currentRoomId': roomId,
    }, SetOptions(merge: true));
  }

  Future<void> clearCurrentRoom(String uid) async {
    await db.collection('users').doc(uid).set({
      'currentRoomId': null,
    }, SetOptions(merge: true));
  }

  Future<String?> getCurrentRoom(String uid) async {
    final doc = await db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return doc.data()?['currentRoomId'];
  }
}