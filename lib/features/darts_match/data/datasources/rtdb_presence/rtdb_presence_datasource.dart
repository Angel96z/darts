import 'package:firebase_database/firebase_database.dart';

class RtdbPresenceDataSource {
  RtdbPresenceDataSource(this._database);
  final FirebaseDatabase _database;

  DatabaseReference _presenceRef(String roomId, String playerId) =>
      _database.ref('presence/$roomId/$playerId');

  Future<void> heartbeat({required String roomId, required String playerId}) {
    return _presenceRef(roomId, playerId).set({
      'status': 'connected',
      'lastSeen': ServerValue.timestamp,
    });
  }
}
