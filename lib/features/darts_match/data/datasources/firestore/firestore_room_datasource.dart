/// File: firestore_room_datasource.dart. Contiene accesso e trasformazione dati (datasource, dto, repository o mapper).

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../dto/room_dto.dart';

class FirestoreRoomDataSource {
  FirestoreRoomDataSource(this._firestore);
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _rooms => _firestore.collection('rooms');

  /// Funzione: descrive in modo semplice questo blocco di logica.
  Stream<RoomDto> watchRoom(String roomId) {
    return _rooms.doc(roomId).snapshots().map((s) => RoomDto.fromMap(s.data() ?? <String, dynamic>{}));
  }

  /// Funzione: descrive in modo semplice questo blocco di logica.
  Future<RoomDto?> getRoom(String roomId) async {
    final snap = await _rooms.doc(roomId).get();
    final data = snap.data();
    return data == null ? null : RoomDto.fromMap(data);
  }

  /// Funzione: descrive in modo semplice questo blocco di logica.
  Future<void> saveRoom(RoomDto room) => _rooms.doc(room.roomId).set(room.toMap(), SetOptions(merge: true));
}
