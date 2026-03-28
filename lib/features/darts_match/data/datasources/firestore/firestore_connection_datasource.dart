import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreConnectionDataSource {
  const FirestoreConnectionDataSource(this._firestore);

  final FirebaseFirestore _firestore;

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
