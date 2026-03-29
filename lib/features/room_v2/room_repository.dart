import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'room_data.dart';

class RoomRepository {
  final FirebaseFirestore db;
  final StreamController<RoomData> _controller =
  StreamController<RoomData>.broadcast();

  RoomData? _state;
  StreamSubscription<DocumentSnapshot>? _remoteSub;

  RoomRepository(this.db);

  Stream<RoomData> watch() => _controller.stream;

  RoomData? get current => _state;

  void initLocal(RoomData data) {
    _state = data;
    _controller.add(data);
  }

  Future<void> update(RoomData newData) async {
    _state = newData;
    _controller.add(newData);
    if (newData.roomId != null) {
      await db.collection('rooms').doc(newData.roomId).set(newData.toMap());
    }
  }

  void connectToRoom(String roomId) {
    _remoteSub?.cancel();
    _remoteSub = db.collection('rooms').doc(roomId).snapshots().listen((doc) {
      if (!doc.exists) return;
      final room = RoomData.fromMap(doc.data() as Map<String, dynamic>);
      _state = room;
      _controller.add(room);
    });
  }

  Future<String> createOnline() async {
    if (_state == null) {
      throw Exception('Errore: stato locale nullo');
    }

    final docRef = db.collection('rooms').doc();
    final newId = docRef.id;
    final onlineData = _state!.copyWith(roomId: newId);

    await docRef.set(onlineData.toMap());

    _state = onlineData;
    _controller.add(onlineData);
    connectToRoom(newId);

    return newId;
  }

  Future<void> dispose() async {
    await _remoteSub?.cancel();
    await _controller.close();
  }
}