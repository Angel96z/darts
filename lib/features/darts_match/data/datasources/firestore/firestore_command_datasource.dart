/// File: firestore_command_datasource.dart. Contiene accesso e trasformazione dati (datasource, dto, repository o mapper).

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../dto/command_dto.dart';

class FirestoreCommandDataSource {
  FirestoreCommandDataSource(this._firestore);
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _commands(String roomId) =>
      _firestore.collection('rooms').doc(roomId).collection('commands');

  /// Funzione: descrive in modo semplice questo blocco di logica.
  Future<void> enqueue(CommandDto dto) => _commands(dto.roomId).doc(dto.commandId).set(dto.toMap());
}
