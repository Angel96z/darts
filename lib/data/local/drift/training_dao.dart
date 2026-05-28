import 'package:drift/drift.dart';
import 'app_db.dart';
import 'tables.dart';
part 'training_dao.g.dart';

@DriftAccessor(tables: [TrainingSessions, TrainingThrows, SessionSummaries])
class TrainingDao extends DatabaseAccessor<AppDb> with _$TrainingDaoMixin {
  final AppDb db;
  TrainingDao(this.db) : super(db);

  Future<void> insertSession(TrainingSessionsCompanion session) async {
    await transaction(() async {
      await into(trainingSessions).insert(session);
      await into(sessionSummaries).insert(SessionSummariesCompanion.insert(
        sessionId: session.id.value,
        totalDarts: const Value(0),
        hitRate: const Value(0.0),
        avgScore: const Value(0.0),
        precision: const Value(0.0),
        checkoutPct: const Value(0.0),
        marksPerRound: const Value(0),
        updatedAt: Value(DateTime.now()),
      ), mode: InsertMode.insertOrReplace);
    });
  }

  Stream<List<TrainingSession>> watchSessions({int limit = 50, int offset = 0}) {
    final query = (select(trainingSessions)
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)])
          ..limit(limit, offset: offset));
    return query.watch();
  }

  Future<void> insertThrow(TrainingThrowsCompanion throwRow) async {
    await transaction(() async {
      await into(trainingThrows).insert(throwRow);
      final sid = throwRow.sessionId.value;
      final sc = throwRow.score.value;

      if (sid != null && sc != null) {
        await _updateSummaryOnNewThrow(sid, sc);
      }
    });
  }

  Future<void> _updateSummaryOnNewThrow(String sessionId, int score) async {
    final summary = await (select(sessionSummaries)..where((s) => s.sessionId.equals(sessionId))).getSingleOrNull();
    if (summary == null) {
      await into(sessionSummaries).insert(SessionSummariesCompanion.insert(
        sessionId: sessionId,
        totalDarts: const Value(1),
        avgScore: Value(score.toDouble()),
        hitRate: const Value(0.0),
        precision: const Value(0.0),
        checkoutPct: const Value(0.0),
        marksPerRound: const Value(0),
        updatedAt: Value(DateTime.now()),
      ));
      return;
    }
    final newTotal = summary.totalDarts + 1;
    final newAvg = ((summary.avgScore * summary.totalDarts) + score) / newTotal;
    await (update(sessionSummaries)..where((s) => s.sessionId.equals(sessionId))).write(
      SessionSummariesCompanion(
        totalDarts: Value(newTotal),
        avgScore: Value(newAvg),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Stream<List<TrainingThrow>> watchThrowsForSession(String sessionId, {int limit = 100, int offset = 0}) {
    final q = (select(trainingThrows)
          ..where((t) => t.sessionId.equals(sessionId))
          ..orderBy([(t) => OrderingTerm(expression: t.thrownAt, mode: OrderingMode.asc)])
          ..limit(limit, offset: offset));
    return q.watch();
  }

  Future<double> computeHitRate(String sessionId, {String target = 'T20'}) async {
    final result = await customSelect('''
      SELECT
        SUM(CASE WHEN target = ? THEN 1 ELSE 0 END) as hits,
        COUNT(*) as total
      FROM training_throws
      WHERE session_id = ?
    ''', variables: [Variable<String>(target), Variable<String>(sessionId)], readsFrom: {trainingThrows}).getSingleOrNull();
    if (result == null) return 0.0;
    final hits = result.data['hits'] as int? ?? 0;
    final total = result.data['total'] as int? ?? 0;
    if (total == 0) return 0.0;
    return hits / total;
  }

  Future<List<String>> getThrowIdsForSession(String sessionId, {int limit = 100, int offset = 0}) async {
    final rows = await customSelect('SELECT id FROM training_throws WHERE session_id = ? ORDER BY thrown_at LIMIT ? OFFSET ?', variables: [Variable(sessionId), Variable(limit), Variable(offset)], readsFrom: {trainingThrows}).get();
    return rows.map((r) => r.read<String>('id')).toList();
  }

  /// Process all throws in chunks to avoid loading everything into memory.
  Future<void> processAllThrowsInChunks(String sessionId, Future<void> Function(List<TrainingThrow>) consumer, {int chunk = 1000}) async {
    int offset = 0;
    while (true) {
      final rows = await (select(trainingThrows)
            ..where((t) => t.sessionId.equals(sessionId))
            ..orderBy([(t) => OrderingTerm(expression: t.thrownAt, mode: OrderingMode.asc)])
            ..limit(chunk, offset: offset))
          .get();
      if (rows.isEmpty) break;
      await consumer(rows);
      offset += rows.length;
    }
  }
}

