import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'room_data.dart';

class RoomRepository {
  final FirebaseFirestore db;

  // Il controller è l'unico punto di uscita dei dati verso la UI.
  final StreamController<RoomData> _controller =
  StreamController<RoomData>.broadcast();

  RoomData? _state;
  StreamSubscription<DocumentSnapshot>? _remoteSub;

  RoomRepository(this.db);

  /// La UI ascolta solo questo stream.
  Stream<RoomData> watch() async* {
    if (_state != null) {
      yield _state!;
    }
    yield* _controller.stream;
  }

  /// Getter per lo stato attuale in memoria.
  RoomData? get current => _state;

  /// 1. INIT: Crea lo stato iniziale in memoria locale.
  Future<void> initLocal(RoomData data) async {
    _state = data;
    // NON emettere subito: sarà letto da watch() al primo subscribe
  }

  /// 2. UPDATE: L'unico punto di scrittura di tutta l'app.
  /// Gestisce sia il salvataggio locale che quello remoto.
  Future<void> update(RoomData newData) async {
    // Se siamo ONLINE: scriviamo su Firestore.
    // Non aggiorniamo il controller qui: ci penserà il listener di connectToRoom.
    if (newData.roomId != null) {
      await db.collection('rooms').doc(newData.roomId).set(newData.toMap());
    } else {
      // Se siamo LOCALE: aggiorniamo la memoria e lo stream.
      _state = newData;
      _controller.add(newData);
    }
  }

  /// 3. CONNECT: Aggancia il flusso dati da Firebase.
  /// Qualsiasi modifica esterna (backend) o interna (update) passerà da qui.
  Future<void> connectToRoom(String roomId) async {
    await _remoteSub?.cancel();

    _remoteSub = db.collection('rooms').doc(roomId).snapshots().listen((doc) {
      final data = doc.data();
      if (data == null) return;

      final room = RoomData.fromMap(data);
      _state = room; // Sincronizza lo stato locale con il DB.
      _controller.add(room); // Notifica la UI.
    });
  }

  /// 4. CREATE ONLINE: Trasforma la room locale in una room online.
  Future<String> createOnline() async {
    if (_state == null) throw Exception("Stato non inizializzato");

    final doc = db.collection('rooms').doc();
    final id = doc.id;

    // Creiamo il nuovo oggetto con l'ID assegnato.
    final updated = _state!.copyWith(roomId: id);

    // Prima attiviamo l'ascolto sul nuovo documento.
    await connectToRoom(id);

    // Poi salviamo il dato (questo scatenerà il listener sopra).
    await update(updated);

    return id;
  }

  Future<void> dispose() async {
    await _remoteSub?.cancel();
    await _controller.close();
  }
}