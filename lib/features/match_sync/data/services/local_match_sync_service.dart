/// File: local_match_sync_service.dart
/// Servizio di sincronizzazione match (cache locale + Firestore)

import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../room_v4/domain/models/dart_throw.dart';
import '../../../room_v4/domain/models/player_turn.dart';
import '../../../stats/domain/services/stats_aggregator_service.dart';
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

    final index = all.indexWhere((cached) {
      final sameRemote = record.remoteId != null &&
          cached.remoteId != null &&
          cached.remoteId == record.remoteId;

      final sameLocalAndPlayer = cached.localId == record.localId &&
          _recordOwnerKey(cached) == _recordOwnerKey(record);

      return sameRemote || sameLocalAndPlayer;
    });

    if (index == -1) {
      all.add(record);
    } else {
      final current = all[index];

      if (current.syncStatus == LocalMatchSyncStatus.pendingDelete ||
          current.syncStatus == LocalMatchSyncStatus.failedDelete) {
        return current.localId;
      }

      all[index] = record;
    }

    await _saveAll(all);
    return record.localId;
  }

  Future<bool> _checkBackendConnection() async {
    try {
      final connectivity = await Connectivity()
          .checkConnectivity()
          .timeout(const Duration(milliseconds: 700));

      if (connectivity.contains(ConnectivityResult.none)) {
        return false;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .limit(1)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(milliseconds: 1200));

      return true;
    } catch (_) {
      return false;
    }
  }
  Future<void> deleteRecords(List<String> ids) async {
    if (ids.isEmpty) return;

    for (final id in ids) {
      await deleteRecord(id);
    }
  }
  /// Sincronizza i match senza queue separata:
  /// 1. push dei record locali pendenti
  /// 2. pull dei record remoti
  /// 3. aggiornamento stats una sola volta se qualcosa è cambiato
  Future<void> syncAll() async {
    if (_running) return;
    if (!await _checkBackendConnection()) return;

    _running = true;
    try {
      final pushedSomething = await _pushLocalToRemote();
      final pulledSomething = await _pullRemoteToLocal();

      if (pushedSomething || pulledSomething) {
        await StatsAggregatorService.instance.updateUserStats();
      }
    } finally {
      _running = false;
    }
  }


  final _syncStatusController = StreamController<Map<String, LocalMatchSyncStatus>>.broadcast();
  Stream<Map<String, LocalMatchSyncStatus>> get onSyncStatusChanged => _syncStatusController.stream;

  Future<bool> _pushLocalToRemote() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final all = await _getAll();
    var changed = false;

    for (int i = 0; i < all.length; i++) {
      final r = all[i];

      if (r.isSynced || r.isSyncing) continue;
      if (!r.canRetryNow) continue;

      if (r.isPendingDelete) {
        all[i] = r.copyWith(
          syncStatus: LocalMatchSyncStatus.failedDelete,
          retryCount: r.retryCount + 1,
          lastSyncAttempt: DateTime.now(),
          deletedAt: r.deletedAt ?? DateTime.now(),
        );
        await _saveAll(all);

        try {
          if (r.hasRemoteId) {
            await _deleteRemoteMatchByRecord(user.uid, r);
          }

          all.removeAt(i);
          i--;
          changed = true;

          _syncStatusController.add({r.localId: LocalMatchSyncStatus.synced});
          if (r.remoteId != null) {
            _syncStatusController.add({r.remoteId!: LocalMatchSyncStatus.synced});
          }

          await _saveAll(all);
        } catch (e) {
          print('❌ Errore delete match remoto: $e');
          _syncStatusController.add({r.localId: LocalMatchSyncStatus.failedDelete});
          await _saveAll(all);
        }

        continue;
      }

      if (!r.isPendingUpload) continue;

      final syncingRecord = r.copyWith(
        syncStatus: LocalMatchSyncStatus.syncing,
        retryCount: r.retryCount + 1,
        lastSyncAttempt: DateTime.now(),
      );

      all[i] = syncingRecord;
      await _saveAll(all);
      _syncStatusController.add({r.localId: LocalMatchSyncStatus.syncing});

      try {
        final remoteId = await _repository.saveMatch(syncingRecord);

        all[i] = syncingRecord.copyWith(
          remoteId: remoteId,
          syncStatus: LocalMatchSyncStatus.synced,
          retryCount: 0,
          updatedAt: DateTime.now(),
        );

        changed = true;
        _syncStatusController.add({r.localId: LocalMatchSyncStatus.synced});
      } catch (e) {
        print('❌ Errore push match: $e');

        all[i] = syncingRecord.copyWith(
          syncStatus: LocalMatchSyncStatus.failed,
          lastSyncAttempt: DateTime.now(),
        );

        _syncStatusController.add({r.localId: LocalMatchSyncStatus.failed});
      }

      await _saveAll(all);
    }

    return changed;
  }

  Future<bool> _pullRemoteToLocal() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final db = FirebaseFirestore.instance;
    final local = await _getAll();
    var changed = false;

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

    final allDocs = [...x01Snapshot.docs, ...cricketSnapshot.docs];

    for (final doc in allDocs) {
      final existingDeleteIndex = local.indexWhere((record) {
        final sameRemote = record.remoteId == doc.id;
        final sameLocal = record.localId == doc.data()['matchId'];
        final isDelete = record.syncStatus == LocalMatchSyncStatus.pendingDelete ||
            record.syncStatus == LocalMatchSyncStatus.failedDelete;
        return isDelete && (sameRemote || sameLocal);
      });

      if (existingDeleteIndex != -1) continue;

      final existingPendingIndex = local.indexWhere((record) {
        final sameRemote = record.remoteId == doc.id;
        final sameLocal = record.localId == doc.data()['matchId'];
        return (sameRemote || sameLocal) &&
            (record.isPendingUpload || record.isPendingDelete || record.isSyncing);
      });

      if (existingPendingIndex != -1) continue;

      final data = doc.data();
      final matchSets = await _fetchMatchHierarchy(doc.reference);

      final playerId = user.uid;
      final playerTurnsMap = await _extractPlayerTurns(matchSets, playerId);
      final turnsList = playerTurnsMap[playerId] ?? [];

      final totalTurns = turnsList.length;
      final totalDarts = turnsList.fold<int>(
        0,
            (sum, t) => sum + t.throws.length,
      );

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
        createdAt: data['createdAt'] is Timestamp
            ? (data['createdAt'] as Timestamp).toDate()
            : (data['startTime'] as Timestamp).toDate(),
        updatedAt: data['updatedAt'] is Timestamp
            ? (data['updatedAt'] as Timestamp).toDate()
            : (data['endTime'] as Timestamp).toDate(),
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

      final existingIndex = local.indexWhere((cached) {
        final sameRemote = cached.remoteId != null && cached.remoteId == doc.id;
        final sameLocalAndPlayer = cached.localId == record.localId &&
            _recordOwnerKey(cached) == _recordOwnerKey(record);
        return sameRemote || sameLocalAndPlayer;
      });

      if (existingIndex == -1) {
        local.add(record);
        changed = true;
      } else {
        final existing = local[existingIndex];

        if (existing.updatedAt.isBefore(record.updatedAt) ||
            existing.syncStatus != LocalMatchSyncStatus.synced) {
          local[existingIndex] = record;
          changed = true;
        }
      }
    }

    if (changed) {
      await _saveAll(local);
    }

    return changed;
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
    var affectedCount = 0;

    for (int i = 0; i < all.length; i++) {
      final record = all[i];
      if (record.mode.trim().toLowerCase() != normalizedMode) continue;

      affectedCount++;

      all[i] = record.copyWith(
        syncStatus: LocalMatchSyncStatus.pendingDelete,
        deletedAt: DateTime.now(),
      );

      _syncStatusController.add({record.localId: LocalMatchSyncStatus.pendingDelete});
      if (record.remoteId != null) {
        _syncStatusController.add({record.remoteId!: LocalMatchSyncStatus.pendingDelete});
      }
    }

    await _saveAll(all);
    await syncAll();

    return affectedCount;
  }


  String _recordOwnerKey(LocalMatchRecord record) {
    if (record.playerTurns.keys.isNotEmpty) {
      return record.playerTurns.keys.first;
    }

    if (record.playerIds.isNotEmpty) {
      return record.playerIds.first;
    }

    return '';
  }

  String _collectionNameForMode(String mode) {
    return mode.trim().toLowerCase() == 'cricket'
        ? 'cricket_matches'
        : 'x01_matches';
  }

  Future<void> _deleteRemoteMatchByRecord(
      String uid,
      LocalMatchRecord record,
      ) async {
    final remoteId = record.remoteId;
    if (remoteId == null || remoteId.isEmpty) return;

    final collectionName = _collectionNameForMode(record.mode);

    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection(collectionName)
        .doc(remoteId);

    await _deleteMatchDocumentHierarchy(ref);
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

    final index = all.indexWhere((r) => r.localId == id || r.remoteId == id);
    if (index == -1) return;

    final record = all[index];

    all[index] = record.copyWith(
      syncStatus: LocalMatchSyncStatus.pendingDelete,
      deletedAt: DateTime.now(),
    );

    await _saveAll(all);
    _syncStatusController.add({id: LocalMatchSyncStatus.pendingDelete});

    await syncAll();
  }

  Future<List<LocalMatchRecord>> getAllRecords() async {
    final all = await _getAll();

    return all
        .where((record) =>
    record.syncStatus != LocalMatchSyncStatus.pendingDelete &&
        record.syncStatus != LocalMatchSyncStatus.failedDelete)
        .toList();
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