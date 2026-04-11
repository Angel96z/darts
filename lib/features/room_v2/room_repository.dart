import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:darts/features/room_v2/user_room_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'local_match_storage.dart';
import 'room_data.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:darts/features/room_v2/user_room_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'room_data.dart';
import 'match_leg_rebuilder.dart';

class RoomRepository {
  final FirebaseFirestore db;

  final StreamController<RoomData> _controller =
  StreamController<RoomData>.broadcast();

  RoomData? _state;
  StreamSubscription<DocumentSnapshot>? _remoteSub;
  Timer? _heartbeatTimer;

  RoomRepository(this.db);
// =========================
// QUEUE SERIALIZZATA
// =========================

  final List<Future<void> Function()> _queue = [];
  bool _isRunning = false;

  Future<void> enqueue(Future<void> Function() job) async {
    final completer = Completer<void>();

    _queue.add(() async {
      try {
        await job();
        if (!completer.isCompleted) {
          completer.complete();
        }
      } catch (e, st) {
        if (!completer.isCompleted) {
          completer.completeError(e, st);
        }
      }
    });

    _runQueue();
    await completer.future;
  }

  Future<void> _runQueue() async {
    if (_isRunning) return;

    _isRunning = true;

    try {
      while (_queue.isNotEmpty) {
        final job = _queue.removeAt(0);
        await job();
      }
    } finally {
      _isRunning = false;

      if (_queue.isNotEmpty) {
        _runQueue();
      }
    }
  }
  // =========================
  // CORE STATE
  // =========================

  Stream<RoomData> watch() => _controller.stream;

  RoomData? get current => _state;

  void initLocal(RoomData data) {
    _state = data;
    _controller.add(data);
  }

  Future<void> update(RoomData data, {bool delayTurnSwitch = false}) async {
    Future<void> job() async {
      _state = data;
      _controller.add(data);

      if (delayTurnSwitch) {
        await Future.delayed(const Duration(seconds: 3));
      }

      if (data.roomId != null) {
        await db.collection('rooms').doc(data.roomId).set(
          data.toMap(),
          SetOptions(merge: true),
        );
      }
    };

    await enqueue(job);
  }

  // =========================
  // CONNECTION MANAGEMENT
  // =========================

  Future<void> connectToRoom(String roomId) async {
    _stopHeartbeat();
    await _remoteSub?.cancel();
    _remoteSub = null;

    final roomRef = db.collection('rooms').doc(roomId);

    final firstSnap = await roomRef.get(const GetOptions(source: Source.serverAndCache));

    if (!firstSnap.exists) {
      clearLocal();
      return;
    }

    final firstData = firstSnap.data();
    if (firstData != null) {
      final room = RoomData.fromMap(firstData);
      _state = room;
      _controller.add(room);
    }

    _remoteSub = roomRef.snapshots().listen(
          (doc) {
        if (!doc.exists) {
          clearLocal();
          return;
        }

        final raw = doc.data();
        if (raw == null) return;

        final room = RoomData.fromMap(raw);
        _state = room;
        _controller.add(room);
      },
      onError: (_, __) {},
      cancelOnError: false,

    );

    _startHeartbeat();
  }

  void clearLocal() {
    _stopHeartbeat();

    _remoteSub?.cancel();
    _remoteSub = null;

    _state = null;
  }

  // =========================
  // HEARTBEAT
  // =========================

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();

    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 8),
          (_) => _heartbeat(),
    );
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  Future<void> _heartbeat() async {
    final state = _state;
    if (state == null) return;

    final roomId = state.roomId;
    if (roomId == null) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final roomRef = db.collection('rooms').doc(roomId);
      final doc = await roomRef.get(const GetOptions(source: Source.serverAndCache));

      if (!doc.exists) {
        clearLocal();
        return;
      }

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

      await roomRef.update({
        'players': updatedPlayers,
      });

    } catch (_) {}
  }
  // =========================
  // ONLINE FLOW
  // =========================

  Future<String> createOnline() async {
    final currentRoomId = _state?.roomId;

    if (currentRoomId != null && currentRoomId.isNotEmpty) {
      return currentRoomId;
    }

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

    await UserRoomRepository(db).setCurrentRoom(uid, newId);

    await docRef.set(onlineData.toMap());

    _state = onlineData;
    _controller.add(onlineData);

    connectToRoom(newId);

    return newId;
  }

  Future<void> joinRoom(String roomId, String userId) async {
    final doc = db.collection('rooms').doc(roomId);

    final snap = await doc.get();
    if (!snap.exists) return;

    final data = snap.data() as Map<String, dynamic>;
    final players = List<Map<String, dynamic>>.from(data['players'] ?? []);

    final already = players.any((p) => p['id'] == userId);
    if (already) return;

    players.add({
      'id': userId,
      'ownerId': userId,
      'name': userId,
      'isGuest': false,
    });

    await doc.update({'players': players});
  }

  // =========================
  // MATCH RESULTS
  // =========================

  Future<void> saveMatchResults(RoomData data) async {
    final matchId = data.matchId ??
        DateTime.now().millisecondsSinceEpoch.toString();

    final updatedData = data.copyWith(matchId: matchId);

    final rebuilt = MatchLegRebuilder.buildPerPlayer(updatedData);

    LocalMatchStorage.save(matchId, {
      'players': rebuilt,
    });

    final newState = updatedData.copyWith(phase: RoomPhase.result);
    _state = newState;
    _controller.add(newState);

    final roomId = data.roomId;
    if (roomId == null) return;

    final roomRef = db.collection('rooms').doc(roomId);
    final snap = await roomRef.get();

    if (!snap.exists) return;

    await db.runTransaction((tx) async {
      for (final p in updatedData.players) {
        final playerId = p['id']?.toString();
        final isGuest = p['isGuest'] == true;

        if (playerId == null || playerId.isEmpty || isGuest) continue;

        final playerData = rebuilt[playerId];
        if (playerData == null) continue;

        tx.set(
          db
              .collection('users')
              .doc(playerId)
              .collection('match_legs')
              .doc(matchId),
          {
            'playerId': playerId,
            'matchId': matchId,
            'roomId': updatedData.roomId,
            'game': updatedData.game.toMap(),
            'matchConfig': updatedData.matchConfig.toMap(),
            'sets': playerData['sets'],
            'createdAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      tx.set(
        roomRef,
        newState.toMap(),
        SetOptions(merge: true),
      );
    });
  }

  // =========================
  // DISPOSE
  // =========================

  Future<void> dispose() async {
    _stopHeartbeat();
    await _remoteSub?.cancel();
    await _controller.close();
  }
}