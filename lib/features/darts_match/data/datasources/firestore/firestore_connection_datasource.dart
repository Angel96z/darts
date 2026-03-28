/// File: firestore_connection_datasource.dart. Contiene accesso e trasformazione dati (datasource, dto, repository o mapper).

import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreConnectionDataSource {
  const FirestoreConnectionDataSource(this._firestore);

  final FirebaseFirestore _firestore;

  /// Funzione: descrive in modo semplice questo blocco di logica.
  Future<bool> checkBackendConnection() async {
    try {
      await _firestore
          .collection('rooms')
          .limit(1)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 3));
      return true;
    } catch (_) {
      return false;
    }
  }
}
