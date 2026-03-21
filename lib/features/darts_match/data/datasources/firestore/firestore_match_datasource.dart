import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../dto/match_dto.dart';

class FirestoreMatchDataSource {
  FirestoreMatchDataSource(this._firestore);
  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _matchRef(String roomId, String matchId) =>
      _firestore.collection('rooms').doc(roomId).collection('matches').doc(matchId);

  Stream<MatchDto> watchMatch(String roomId, String matchId) {
    return _matchRef(roomId, matchId).snapshots().map((s) => MatchDto.fromMap(s.data() ?? <String, dynamic>{}));
  }

  Future<MatchDto?> getMatch(String roomId, String matchId) async {
    final snap = await _matchRef(roomId, matchId).get();
    final data = snap.data();
    return data == null ? null : MatchDto.fromMap(data);
  }

  Future<void> saveMatch(MatchDto dto) => _matchRef(dto.roomId, dto.matchId).set(dto.toMap(), SetOptions(merge: true));

  Future<void> appendEvent({required String roomId, required String matchId, required String eventId, required Map<String, dynamic> event}) {
    return _matchRef(roomId, matchId).collection('events').doc(eventId).set(event);
  }
}
