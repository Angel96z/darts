import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/enums.dart';

class UserRoomRecord {
  const UserRoomRecord({
    required this.uid,
    required this.roomId,
    required this.role,
    required this.participantIds,
  });

  final String uid;
  final String roomId;
  final RoomRole role;
  final List<String> participantIds;

  Map<String, dynamic> toMap() {
    return {
      'roomId': roomId,
      'role': role.name,
      'participantIds': participantIds,
    };
  }

  static UserRoomRecord fromMap(String uid, Map<String, dynamic> map) {
    return UserRoomRecord(
      uid: uid,
      roomId: map['roomId'] as String,
      role: RoomRole.values.byName(map['role'] as String),
      participantIds: List<String>.from(map['participantIds'] as List<dynamic>? ?? const []),
    );
  }
}

class UserRoomRepository {
  UserRoomRepository(this._firestore);

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> userRoomRef(String uid) => _firestore.collection('user_rooms').doc(uid);

  Future<UserRoomRecord?> get(String uid) async {
    final snapshot = await userRoomRef(uid).get();
    if (!snapshot.exists || snapshot.data() == null) {
      return null;
    }
    return UserRoomRecord.fromMap(snapshot.id, snapshot.data()!);
  }

  Stream<UserRoomRecord?> watch(String uid) {
    return userRoomRef(uid).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }
      return UserRoomRecord.fromMap(snapshot.id, snapshot.data()!);
    });
  }

  Future<void> upsert(UserRoomRecord record) {
    return userRoomRef(record.uid).set(record.toMap(), SetOptions(merge: true));
  }

  Future<void> clear(String uid) {
    return userRoomRef(uid).delete();
  }
}
