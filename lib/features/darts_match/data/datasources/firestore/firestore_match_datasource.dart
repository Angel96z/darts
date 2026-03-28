/// File: firestore_match_datasource.dart. Contiene accesso e trasformazione dati (datasource, dto, repository o mapper).

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../dto/match_dto.dart';

class FirestoreMatchDataSource {
  FirestoreMatchDataSource(this._firestore);
  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _matchRef(String roomId, String matchId) =>
      _firestore.collection('rooms').doc(roomId).collection('matches').doc(matchId);

  /// Funzione: descrive in modo semplice questo blocco di logica.
  Stream<MatchDto> watchMatch(String roomId, String matchId) {
    /// Funzione: descrive in modo semplice questo blocco di logica.
    return _matchRef(roomId, matchId).snapshots().map((s) => MatchDto.fromMap(s.data() ?? <String, dynamic>{}));
  }

  /// Funzione: descrive in modo semplice questo blocco di logica.
  Future<MatchDto?> getMatch(String roomId, String matchId) async {
    final snap = await _matchRef(roomId, matchId).get();
    final data = snap.data();
    return data == null ? null : MatchDto.fromMap(data);
  }

  /// Funzione: descrive in modo semplice questo blocco di logica.
  Future<void> saveMatch(MatchDto dto) => _matchRef(dto.roomId, dto.matchId).set(dto.toMap(), SetOptions(merge: true));

  /// Funzione: descrive in modo semplice questo blocco di logica.
  Future<void> appendEvent({required String roomId, required String matchId, required String eventId, required Map<String, dynamic> event}) {
    return _matchRef(roomId, matchId).collection('events').doc(eventId).set(event);
  }
}
