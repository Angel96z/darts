/// File: local_match_sync_service.dart
/// Servizio di sincronizzazione match (cache locale + Firestore)

import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../room_v4/domain/models/dart_throw.dart';
import '../../../room_v4/domain/models/player_turn.dart';
import '../../domain/entities/local_match_record.dart';
import '../repositories/match_repository.dart';

class LocalMatchSyncService {
  static const _key = 'match_queue_v2';
  static LocalMatchSyncService? _instance;

  final MatchRepository _repository = MatchRepository();
  final _uuid = const Uuid();
  bool _running = false;

  LocalMatchSyncService._internal();

  static LocalMatchSyncService get instance {
    _instance ??= LocalMatchSyncService._internal();
    return _instance!;
  }

  /// Salva un match in locale (cache) e avvia sync
  Future<LocalMatchSaveResult> saveMatch(LocalMatchRecord record) async {
    final localId = await _saveLocal(record);

    if (!await _checkBackendConnection()) {
      return LocalMatchSaveResult(
        localId: localId,
        status: LocalMatchSyncStatus.pending,
      );
    }

    await syncAll();
    final updated = await getById(localId);

    return LocalMatchSaveResult(
      localId: localId,
      status: updated?.syncStatus ?? LocalMatchSyncStatus.failed,
    );
  }

  Future<String> _saveLocal(LocalMatchRecord record) async {
    final all = await _getAll();
    all.add(record);
    await _saveAll(all);
    return record.localId;
  }

  Future<bool> _checkBackendConnection() async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .limit(1)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 3));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Sincronizza tutti i match pendenti
  Future<void> syncAll() async {
    if (_running) return;
    if (!await _checkBackendConnection()) return;
    _running = true;

    await _pushLocalToRemote();
    await _pullRemoteToLocal();

    _running = false;
  }
  final _syncStatusController = StreamController<Map<String, LocalMatchSyncStatus>>.broadcast();
  Stream<Map<String, LocalMatchSyncStatus>> get onSyncStatusChanged => _syncStatusController.stream;

  Future<void> _pushLocalToRemote() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final all = await _getAll();

    for (int i = 0; i < all.length; i++) {
      final r = all[i];

      if (r.syncStatus == LocalMatchSyncStatus.synced) continue;
      // 🔥 NOTIFICA CHE STA PARTENDO LA SINCRONIZZAZIONE
      if (r.syncStatus != LocalMatchSyncStatus.syncing) {
        _syncStatusController.add({r.localId: LocalMatchSyncStatus.syncing});
      }
      if (r.syncStatus == LocalMatchSyncStatus.failed) {
        if (r.retryCount >= 3) continue;
        if (r.lastSyncAttempt != null) {
          final hoursSinceLastAttempt = DateTime.now().difference(r.lastSyncAttempt!).inHours;
          if (hoursSinceLastAttempt < 1) continue;
        }
      }

      // Marca come syncing
      all[i] = r.copyWith(
        syncStatus: LocalMatchSyncStatus.syncing,
        retryCount: r.retryCount + 1,
        lastSyncAttempt: DateTime.now(),
      );
      await _saveAll(all);
      _syncStatusController.add({r.localId: LocalMatchSyncStatus.syncing});

      try {
        final remoteId = await _repository.saveMatch(r);

        all[i] = r.copyWith(
          remoteId: remoteId,
          syncStatus: LocalMatchSyncStatus.synced,
          retryCount: 0,
        );
        _syncStatusController.add({r.localId: LocalMatchSyncStatus.synced});

      } catch (e) {
        print('❌ Errore push match: $e');
        all[i] = r.copyWith(syncStatus: LocalMatchSyncStatus.failed);
      }

      await _saveAll(all);
    }
  }

  Future<void> _pullRemoteToLocal() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final db = FirebaseFirestore.instance;
    final local = await _getAll();
    final existingIds = local.map((e) => e.remoteId).toSet();

    final snapshot = await db
        .collection('users')
        .doc(user.uid)
        .collection('matches')
        .where('status', isEqualTo: 'complete')
        .get();

    for (final doc in snapshot.docs) {
      if (existingIds.contains(doc.id)) continue;

      final data = doc.data();

      // 🔥 RECUPERA LA GERARCHIA COMPLETA
      final matchSets = await _fetchMatchHierarchy(doc.reference);

      // 🔥 ESTRAI I TURNI DEL GIOCATORE CORRENTE
      final playerId = user.uid;
      final playerTurnsMap = await _extractPlayerTurns(matchSets, playerId);
      final turnsList = playerTurnsMap[playerId] ?? [];

      final totalTurns = turnsList.length;
      final totalDarts = turnsList.fold(0, (sum, t) => sum + t.throws.length);

      final record = LocalMatchRecord(
        localId: data['matchId'] ?? doc.id,
        remoteId: doc.id,
        mode: data['mode'],
        winnerId: data['winnerId'],
        winnerName: data['winnerName'],
        playerIds: List<String>.from(data['playerIds']),
        playerNames: List<String>.from(data['playerNames']),
        finalScores: Map<String, int>.from(data['finalScores']),
        legsWon: Map<String, int>.from(data['legsWon']),
        setsWon: Map<String, int>.from(data['setsWon']),
        startTime: (data['startTime'] as Timestamp).toDate(),
        endTime: (data['endTime'] as Timestamp).toDate(),
        totalTurns: totalTurns,
        totalDarts: totalDarts,
        gameConfig: Map<String, dynamic>.from(data['gameConfig']),
        matchConfig: Map<String, dynamic>.from(data['matchConfig']),
        teamSize: data['teamSize'],
        playerToTeam: data['playerToTeam'] != null
            ? Map<String, String>.from(data['playerToTeam'])
            : null,
        playerTurns: playerTurnsMap,
        matchSets: matchSets,
        syncStatus: LocalMatchSyncStatus.synced,
      );

      local.add(record);
    }

    await _saveAll(local);
  }

  /// Recupera l'intera gerarchia del match
  Future<List<Map<String, dynamic>>> _fetchMatchHierarchy(DocumentReference matchRef) async {
    final matchSets = <Map<String, dynamic>>[];

    final setsSnapshot = await matchRef
        .collection('sets')
        .orderBy('setNumber')
        .get();

    for (final setDoc in setsSnapshot.docs) {
      final setData = setDoc.data();
      final legs = <Map<String, dynamic>>[];

      final legsSnapshot = await setDoc.reference
          .collection('legs')
          .orderBy('legNumber')
          .get();

      for (final legDoc in legsSnapshot.docs) {
        final legData = legDoc.data();
        final rounds = <Map<String, dynamic>>[];

        final roundsSnapshot = await legDoc.reference
            .collection('rounds')
            .orderBy('roundNumber')
            .get();

        for (final roundDoc in roundsSnapshot.docs) {
          final roundData = roundDoc.data();
          final turns = <Map<String, dynamic>>[];

          final turnsSnapshot = await roundDoc.reference
              .collection('turns')
              .orderBy('turnNumber')
              .get();

          for (final turnDoc in turnsSnapshot.docs) {
            turns.add(turnDoc.data());
          }

          rounds.add({
            'roundNumber': roundData['roundNumber'],
            'timestamp': roundData['timestamp'],
            'turns': turns,
          });
        }

        legs.add({
          'legNumber': legData['legNumber'],
          'winnerId': legData['winnerId'],
          'winningScore': legData['winningScore'],
          'startTime': legData['startTime'],
          'endTime': legData['endTime'],
          'rounds': rounds,
        });
      }

      matchSets.add({
        'setNumber': setData['setNumber'],
        'winnerId': setData['winnerId'],
        'startTime': setData['startTime'],
        'endTime': setData['endTime'],
        'legs': legs,
      });
    }

    return matchSets;
  }

  /// Estrae i turni di un giocatore specifico dalla gerarchia
  Future<Map<String, List<PlayerTurn>>> _extractPlayerTurns(
      List<Map<String, dynamic>> matchSets,
      String playerId,
      ) async {
    final turns = <PlayerTurn>[];

    for (final setMap in matchSets) {
      final legs = setMap['legs'] as List;
      for (final legMap in legs) {
        final rounds = legMap['rounds'] as List;
        for (final roundMap in rounds) {
          final turnMaps = roundMap['turns'] as List;
          for (final turnMap in turnMaps) {
            if (turnMap['playerId'] == playerId) {
              final turn = PlayerTurn(
                playerId: turnMap['playerId'],
                turnNumber: turnMap['turnNumber'],
                roundNumber: turnMap['roundNumber'] ?? 1,
                legNumber: turnMap['legNumber'] ?? 1,
                throws: (turnMap['throws'] as List)
                    .map((d) => DartThrow(
                  dartNumber: d['dartNumber'],
                  target: d['target'],
                  multiplier: d['multiplier'],
                  score: d['score'],
                  timestamp: DateTime.parse(d['timestamp']),
                ))
                    .toList(),
                total: turnMap['total'],
                totalMarks: turnMap['totalMarks'] ?? 0,
                initialScore: turnMap['initialScore'],
                score: turnMap['score'],
                isBust: turnMap['isBust'],
                isCheckout: turnMap['isCheckout'],
                timestamp: DateTime.parse(turnMap['timestamp']),
              );
              turns.add(turn);
            }
          }
        }
      }
    }

    return {playerId: turns};
  }


  Future<LocalMatchRecord?> getById(String id) async {
    final all = await _getAll();
    for (final r in all) {
      if (r.localId == id || r.remoteId == id) return r;
    }
    return null;
  }

  Future<List<LocalMatchRecord>> getAllRecords() async {
    return await _getAll();
  }

  Future<List<LocalMatchRecord>> _getAll() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw == null) return [];

    return (jsonDecode(raw) as List)
        .map((e) => LocalMatchRecord.fromMap(e))
        .toList();
  }

  Future<void> _saveAll(List<LocalMatchRecord> list) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode(list.map((e) => e.toMap()).toList()));
  }

  Future<void> retryFailed() async {
    await syncAll();
  }
}