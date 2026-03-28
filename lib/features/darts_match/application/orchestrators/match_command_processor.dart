/// File: match_command_processor.dart. Contiene codice Dart del progetto.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/commands/match_command.dart';
import '../../domain/entities/match.dart';
import '../../domain/value_objects/identifiers.dart';
import 'match_orchestrator.dart';

class MatchCommandProcessor {
  /// Funzione: descrive in modo semplice questo blocco di logica.
  MatchCommandProcessor({
    required FirebaseFirestore firestore,
    required MatchOrchestrator orchestrator,
  })  : _firestore = firestore,
        _orchestrator = orchestrator;

  final FirebaseFirestore _firestore;
  final MatchOrchestrator _orchestrator;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  CollectionReference<Map<String, dynamic>> _commands(String roomId) =>
      _firestore.collection('rooms').doc(roomId).collection('commands');

  /// Funzione: descrive in modo semplice questo blocco di logica.
  void bindRoom(String roomId) {
    _sub?.cancel();
    _sub = _commands(roomId).where('status', isEqualTo: 'pending').snapshots().listen((snapshot) {
      for (final doc in snapshot.docs) {
        unawaited(_processDoc(doc));
      }
    });
  }

  /// Funzione: descrive in modo semplice questo blocco di logica.
  Future<void> _processDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final claimed = await _claimPending(doc.reference);
    if (!claimed) return;

    try {
      final data = doc.data();
      final command = _toCommand(data);
      if (command != null && command is SubmitTurnCommand) {
        await _orchestrator.handleCommand(command);
      }

      await doc.reference.set({
        'status': 'processed',
        'processedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      await doc.reference.set({
        'status': 'failed',
        'error': e.toString(),
      }, SetOptions(merge: true));
    }
  }

  /// Funzione: descrive in modo semplice questo blocco di logica.
  Future<bool> _claimPending(DocumentReference<Map<String, dynamic>> ref) async {
    /// Funzione: descrive in modo semplice questo blocco di logica.
    return _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final status = snap.data()?['status'] as String?;
      if (status != 'pending') return false;
      tx.set(ref, {
        'status': 'processing',
        'processingAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return true;
    });
  }

  /// Funzione: descrive in modo semplice questo blocco di logica.
  MatchCommand? _toCommand(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    if (type != 'SubmitTurnCommand') return null;
    final draftMap = Map<String, dynamic>.from((data['payload']?['draft'] as Map?) ?? const {});
    final inputsRaw = List<Map<String, dynamic>>.from((draftMap['inputs'] as List?) ?? const []);
    final inputs = inputsRaw
        .map((it) => DartInput(rawValue: (it['rawValue'] as num?)?.toInt() ?? 0, multiplier: (it['multiplier'] as num?)?.toInt() ?? 1))
        .toList();

    final draft = TurnDraft(
      playerId: PlayerId((draftMap['playerId'] ?? data['authorId']) as String),
      legNumber: (draftMap['legNumber'] as num?)?.toInt() ?? 1,
      turnNumber: (draftMap['turnNumber'] as num?)?.toInt() ?? 1,
      inputs: inputs,
      inputMode: InputMode.totalTurnInput,
    );

    return SubmitTurnCommand(
      commandId: CommandId((data['commandId'] ?? '') as String),
      authorId: PlayerId((data['authorId'] ?? '') as String),
      createdAt: DateTime.tryParse((data['createdAt'] ?? '') as String) ?? DateTime.now(),
      roomId: RoomId((data['roomId'] ?? '') as String),
      matchId: data['matchId'] == null ? null : MatchId(data['matchId'] as String),
      payload: {'draft': draft},
      idempotencyKey: (data['idempotencyKey'] ?? '') as String,
      status: CommandStatus.pending,
    );
  }

  /// Funzione: descrive in modo semplice questo blocco di logica.
  Future<void> dispose() async {
    await _sub?.cancel();
  }
}
