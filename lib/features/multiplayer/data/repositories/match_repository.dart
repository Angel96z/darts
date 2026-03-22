import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models.dart';

class MatchRepository {
  MatchRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _matchesRef(String roomId) {
    return _firestore.collection('rooms').doc(roomId).collection('matches');
  }

  DocumentReference<Map<String, dynamic>> matchRef(String roomId, String matchId) {
    return _matchesRef(roomId).doc(matchId);
  }

  Stream<MatchSnapshot?> watchMatch(String roomId, String matchId) {
    return matchRef(roomId, matchId).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }
      return MatchSnapshot.fromMap(roomId: roomId, matchId: snapshot.id, map: snapshot.data()!);
    });
  }

  Future<MatchSnapshot?> getMatch(String roomId, String matchId) async {
    final snapshot = await matchRef(roomId, matchId).get();
    if (!snapshot.exists || snapshot.data() == null) {
      return null;
    }
    return MatchSnapshot.fromMap(roomId: roomId, matchId: snapshot.id, map: snapshot.data()!);
  }

  Future<void> createMatch({
    required String roomId,
    required String matchId,
    required MatchSnapshot match,
  }) {
    return matchRef(roomId, matchId).set(match.toMap());
  }

  Future<void> updateMatchFields({
    required String roomId,
    required String matchId,
    required Map<String, dynamic> fields,
  }) {
    return matchRef(roomId, matchId).update(fields);
  }

  Future<T> runTransaction<T>(Future<T> Function(Transaction tx) action) {
    return _firestore.runTransaction((tx) => action(tx));
  }
}
