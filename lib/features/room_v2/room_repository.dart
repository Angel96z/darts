import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:darts/features/room_v2/user_room_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'room_data.dart';

class RoomRepository {
  final FirebaseFirestore db;
  final StreamController<RoomData> _controller =
  StreamController<RoomData>.broadcast();

  RoomData? _state;
  StreamSubscription<DocumentSnapshot>? _remoteSub;

  RoomRepository(this.db);
  Timer? _heartbeatTimer;

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();

    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 8),
          (_) => _heartbeat(),
    );
  }

  Future<void> _heartbeat() async {
    final state = _state;
    if (state == null) return;

    final roomId = state.roomId;
    if (roomId == null) return;

    final roomRef = db.collection('rooms').doc(roomId);
    final doc = await roomRef.get();

    // 🔴 ROOM NON ESISTE → STOP TOTALE
    if (!doc.exists) {
      _stopHeartbeat();
      _remoteSub?.cancel();
      _remoteSub = null;
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;

    final updatedPlayers = state.players.map((p) {
      final owner = p['ownerId'];
      final id = p['id'];

      final isMine = owner == uid || id == uid;
      if (!isMine) return p;

      final updated = Map<String, dynamic>.from(p);
      updated['lastSeen'] = now;
      return updated;
    }).toList();

    final newData = state.copyWith(players: updatedPlayers);

    _state = newData;
    _controller.add(newData);

    try {
      await roomRef.set(newData.toMap());
    } catch (_) {}
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
  }
  Stream<RoomData> watch() => _controller.stream;

  RoomData? get current => _state;

// =========================
// QUEUE SERIALIZZATA
// =========================
  final List<Future<void> Function()> _queue = [];
  bool _isRunning = false;

  Future<void> enqueue(Future<void> Function() job) async {
    _queue.add(job);
    _runQueue();
  }

  Future<void> _runQueue() async {
    if (_isRunning) return;
    _isRunning = true;

    while (_queue.isNotEmpty) {
      final job = _queue.removeAt(0);
      await job();
    }

    _isRunning = false;
  }


  void initLocal(RoomData data) {
    _state = data;
    _controller.add(data);
  }
  Future<void> startMatch() async {
    if (_state == null) return;

    final updated = _state!.initMatch();
    await update(updated);
  }
  Future<void> update(RoomData data) async {
    _state = data;
    _controller.add(data);

    await db.collection('rooms').doc(data.roomId).set(
      data.toMap(),
      SetOptions(merge: true),
    );
  }

  void connectToRoom(String roomId) {
    _stopHeartbeat();
    _remoteSub?.cancel();

    _remoteSub = db.collection('rooms').doc(roomId).snapshots().listen((doc) {
      // 🔴 ROOM ELIMINATA → STOP TOTALE
      if (!doc.exists) {
        _stopHeartbeat();
        _remoteSub?.cancel();
        _remoteSub = null;
        return;
      }

      final room = RoomData.fromMap(doc.data() as Map<String, dynamic>);
      _state = room;
      _controller.add(room);
    });

    _startHeartbeat();
  }

  Future<String> createOnline() async {
    if (_state == null) {
      throw Exception('Errore: stato locale nullo');
    }

    final docRef = db.collection('rooms').doc();
    final newId = docRef.id;
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final onlineData = _state!.copyWith(
      roomId: newId,
      creatorId: uid,
      adminIds: {
        ..._state!.adminIds,
        uid,
      }.toList(),
    );

// collega SEMPRE il creator alla room
    await UserRoomRepository(db).setCurrentRoom(uid, newId);

    await docRef.set(onlineData.toMap());

    _state = onlineData;
    _controller.add(onlineData);

    connectToRoom(newId);
    _startHeartbeat();

    return newId;
  }


  Future<void> dispose() async {
    _stopHeartbeat();
    await _remoteSub?.cancel();
    await _controller.close();
  }
}

