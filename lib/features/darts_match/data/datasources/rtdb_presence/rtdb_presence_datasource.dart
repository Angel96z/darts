/// File: rtdb_presence_datasource.dart. Contiene accesso e trasformazione dati (datasource, dto, repository o mapper).

import 'package:firebase_database/firebase_database.dart';

class RtdbPresenceDataSource {
  RtdbPresenceDataSource(this._database);
  final FirebaseDatabase _database;

  /// Funzione: descrive in modo semplice questo blocco di logica.
  DatabaseReference _presenceRef(String roomId, String playerId) =>
      _database.ref('presence/$roomId/$playerId');

  /// Funzione: descrive in modo semplice questo blocco di logica.
  Future<void> heartbeat({required String roomId, required String playerId}) {
    /// Funzione: descrive in modo semplice questo blocco di logica.
    return _presenceRef(roomId, playerId).set({
      'status': 'connected',
      'lastSeen': ServerValue.timestamp,
    });
  }
}
