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

    // Carica da entrambe le collezioni
    final x01Snapshot = await db
        .collection('users')
        .doc(user.uid)
        .collection('x01_matches')
        .where('status', isEqualTo: 'complete')
        .get();

    final cricketSnapshot = await db
        .collection('users')
        .doc(user.uid)
        .collection('cricket_matches')
        .where('status', isEqualTo: 'complete')
        .get();

    // Combina i risultati
    final allDocs = [...x01Snapshot.docs, ...cricketSnapshot.docs];

    for (final doc in allDocs) {
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

  /// 🔥 RECUPERA TUTTI I MATCH X01 DIRETTAMENTE DA FIRESTORE (senza filtro status)
  /// 🔥 RECUPERA TUTTI I MATCH X01 IN PARALLELO (VELOCE)
  Future<List<LocalMatchRecord>> fetchX01MatchesFromFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    final db = FirebaseFirestore.instance;

    try {
      final stopwatch = Stopwatch()..start();

      // 1. Prendi TUTTI i match X01 in una sola chiamata
      final x01Snapshot = await db
          .collection('users')
          .doc(user.uid)
          .collection('x01_matches')
          .get();

      print('🔥 Trovati ${x01Snapshot.docs.length} match X01');

      if (x01Snapshot.docs.isEmpty) return [];

      // 2. Carica la gerarchia di TUTTI i match IN PARALLELO
      final futures = x01Snapshot.docs.map((doc) async {
        final data = doc.data();
        final matchSets = await _fetchMatchHierarchyOptimized(doc.reference);

        final playerId = user.uid;
        final playerTurnsMap = await _extractPlayerTurns(matchSets, playerId);
        final turnsList = playerTurnsMap[playerId] ?? [];

        final totalTurns = turnsList.length;
        final totalDarts = turnsList.fold(0, (sum, t) => sum + t.throws.length);

        return LocalMatchRecord(
          localId: data['matchId'] ?? doc.id,
          remoteId: doc.id,
          mode: data['mode'] ?? 'x01',
          winnerId: data['winnerId'] ?? '',
          winnerName: data['winnerName'] ?? '',
          playerIds: List<String>.from(data['playerIds'] ?? []),
          playerNames: List<String>.from(data['playerNames'] ?? []),
          finalScores: Map<String, int>.from(data['finalScores'] ?? {}),
          legsWon: Map<String, int>.from(data['legsWon'] ?? {}),
          setsWon: Map<String, int>.from(data['setsWon'] ?? {}),
          startTime: (data['startTime'] as Timestamp).toDate(),
          endTime: (data['endTime'] as Timestamp).toDate(),
          totalTurns: totalTurns,
          totalDarts: totalDarts,
          gameConfig: Map<String, dynamic>.from(data['gameConfig'] ?? {}),
          matchConfig: Map<String, dynamic>.from(data['matchConfig'] ?? {}),
          teamSize: data['teamSize'] ?? 0,
          playerToTeam: data['playerToTeam'] != null
              ? Map<String, String>.from(data['playerToTeam'])
              : null,
          playerTurns: playerTurnsMap,
          matchSets: matchSets,
          syncStatus: LocalMatchSyncStatus.synced,
        );
      }).toList();

      // 3. Attendi TUTTI i caricamenti in parallelo
      final matches = await Future.wait(futures);

      // 4. Salva in cache
      final allCached = await _getAll();
      for (final match in matches) {
        final existingIndex = allCached.indexWhere((m) => m.remoteId == match.remoteId);
        if (existingIndex != -1) {
          allCached[existingIndex] = match;
        } else {
          allCached.add(match);
        }
      }
      await _saveAll(allCached);

      stopwatch.stop();
      print('✅ Caricati ${matches.length} match in ${stopwatch.elapsedMilliseconds}ms');

      return matches;

    } catch (e) {
      print('❌ Errore fetch X01 matches: $e');
      return [];
    }
  }

  /// 🔥 VERSIONE OTTIMIZZATA - carica tutta la gerarchia in parallelo
  Future<List<Map<String, dynamic>>> _fetchMatchHierarchyOptimized(DocumentReference matchRef) async {
    final matchSets = <Map<String, dynamic>>[];

    // 1. Prendi tutti i sets in una chiamata
    final setsSnapshot = await matchRef
        .collection('sets')
        .orderBy('setNumber')
        .get();

    if (setsSnapshot.docs.isEmpty) return matchSets;

    // 2. Per ogni set, carica legs in parallelo
    final setFutures = setsSnapshot.docs.map((setDoc) async {
      final setData = setDoc.data();
      final legs = <Map<String, dynamic>>[];

      final legsSnapshot = await setDoc.reference
          .collection('legs')
          .orderBy('legNumber')
          .get();

      // 3. Per ogni leg, carica rounds in parallelo
      final legFutures = legsSnapshot.docs.map((legDoc) async {
        final legData = legDoc.data();
        final rounds = <Map<String, dynamic>>[];

        final roundsSnapshot = await legDoc.reference
            .collection('rounds')
            .orderBy('roundNumber')
            .get();

        // 4. Per ogni round, carica turns in parallelo
        final roundFutures = roundsSnapshot.docs.map((roundDoc) async {
          final roundData = roundDoc.data();
          final turns = <Map<String, dynamic>>[];

          final turnsSnapshot = await roundDoc.reference
              .collection('turns')
              .orderBy('turnNumber')
              .get();

          for (final turnDoc in turnsSnapshot.docs) {
            turns.add(turnDoc.data());
          }

          return {
            'roundNumber': roundData['roundNumber'],
            'timestamp': roundData['timestamp'],
            'turns': turns,
          };
        }).toList();

        final loadedRounds = await Future.wait(roundFutures);
        rounds.addAll(loadedRounds);

        return {
          'legNumber': legData['legNumber'],
          'winnerId': legData['winnerId'],
          'winningScore': legData['winningScore'],
          'startTime': legData['startTime'],
          'endTime': legData['endTime'],
          'rounds': rounds,
          'cricketMarks': legData['cricketMarks'] ?? {},
          'cricketPoints': legData['cricketPoints'] ?? {},
        };
      }).toList();

      final loadedLegs = await Future.wait(legFutures);
      legs.addAll(loadedLegs);

      return {
        'setNumber': setData['setNumber'],
        'winnerId': setData['winnerId'],
        'startTime': setData['startTime'],
        'endTime': setData['endTime'],
        'legs': legs,
      };
    }).toList();

    final loadedSets = await Future.wait(setFutures);
    matchSets.addAll(loadedSets);

    return matchSets;
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
          'cricketMarks': legData['cricketMarks'] ?? {},
          'cricketPoints': legData['cricketPoints'] ?? {},
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
// local_match_sync_service.dart - Aggiungi questo metodo

  /// Estrae i turni di un giocatore specifico PIÙ i dati Cricket del leg
  Future<({Map<String, List<PlayerTurn>> turns, Map<String, dynamic> cricketData})>
  _extractPlayerTurnsWithCricket(
      List<Map<String, dynamic>> matchSets,
      String playerId,
      ) async {
    final turns = <PlayerTurn>[];
    final cricketData = <String, dynamic>{}; // legKey -> {marks, points}

    for (final setMap in matchSets) {
      final legs = setMap['legs'] as List;
      for (final legMap in legs) {
        final legNumber = legMap['legNumber'];
        final legKey = 'S${setMap['setNumber']}_L$legNumber';

        // Salva dati Cricket del leg
        cricketData[legKey] = {
          'cricketMarks': legMap['cricketMarks'] ?? {},
          'cricketPoints': legMap['cricketPoints'] ?? {},
        };

        final rounds = legMap['rounds'] as List;
        for (final roundMap in rounds) {
          final turnMaps = roundMap['turns'] as List;
          for (final turnMap in turnMaps) {
            if (turnMap['playerId'] == playerId) {
              final turn = PlayerTurn(
                playerId: turnMap['playerId'],
                turnNumber: turnMap['turnNumber'],
                roundNumber: turnMap['roundNumber'] ?? 1,
                legNumber: turnMap['legNumber'] ?? legNumber,
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

    return (turns: {playerId: turns}, cricketData: cricketData);
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

  Future<int> deleteRecordsByMode(String mode) async {
    final normalizedMode = mode.trim().toLowerCase();
    if (normalizedMode != 'x01' && normalizedMode != 'cricket') return 0;

    final all = await _getAll();
    final localToDelete = all
        .where((record) => record.mode.trim().toLowerCase() == normalizedMode)
        .toList();

    final toKeep = all
        .where((record) => record.mode.trim().toLowerCase() != normalizedMode)
        .toList();

    var deletedCount = localToDelete.length;

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final collectionName = normalizedMode == 'x01'
          ? 'x01_matches'
          : 'cricket_matches';

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection(collectionName)
          .get();

      for (final doc in snapshot.docs) {
        deletedCount += await _deleteMatchDocumentHierarchy(doc.reference);
      }
    }

    await _saveAll(toKeep);

    for (final record in localToDelete) {
      _syncStatusController.add({record.localId: LocalMatchSyncStatus.synced});
      if (record.remoteId != null) {
        _syncStatusController.add({record.remoteId!: LocalMatchSyncStatus.synced});
      }
    }

    return deletedCount;
  }

  Future<int> _deleteMatchDocumentHierarchy(
      DocumentReference<Map<String, dynamic>> matchRef,
      ) async {
    var deletedCount = 0;
    final db = FirebaseFirestore.instance;

    final setsSnapshot = await matchRef.collection('sets').get();

    for (final setDoc in setsSnapshot.docs) {
      final legsSnapshot = await setDoc.reference.collection('legs').get();

      for (final legDoc in legsSnapshot.docs) {
        final roundsSnapshot = await legDoc.reference.collection('rounds').get();

        for (final roundDoc in roundsSnapshot.docs) {
          final turnsSnapshot = await roundDoc.reference.collection('turns').get();

          if (turnsSnapshot.docs.isNotEmpty) {
            final turnsBatch = db.batch();
            for (final turnDoc in turnsSnapshot.docs) {
              turnsBatch.delete(turnDoc.reference);
            }
            await turnsBatch.commit();
            deletedCount += turnsSnapshot.docs.length;
          }

          final roundBatch = db.batch();
          roundBatch.delete(roundDoc.reference);
          await roundBatch.commit();
          deletedCount++;
        }

        final legBatch = db.batch();
        legBatch.delete(legDoc.reference);
        await legBatch.commit();
        deletedCount++;
      }

      final setBatch = db.batch();
      setBatch.delete(setDoc.reference);
      await setBatch.commit();
      deletedCount++;
    }

    await matchRef.delete();
    deletedCount++;

    return deletedCount;
  }


  Future<LocalMatchRecord?> getById(String id) async {
    final all = await _getAll();
    for (final r in all) {
      if (r.localId == id || r.remoteId == id) return r;
    }
    return null;
  }

  Future<void> deleteRecord(String id) async {
    final all = await _getAll();

    all.removeWhere((r) => r.localId == id || r.remoteId == id);

    await _saveAll(all);
    _syncStatusController.add({id: LocalMatchSyncStatus.synced});
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