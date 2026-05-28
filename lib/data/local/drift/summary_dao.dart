import 'package:drift/drift.dart';
import 'app_db.dart';
import 'tables.dart';
part 'summary_dao.g.dart';

@DriftAccessor(tables: [SessionSummaries, TrainingThrows])
class SummaryDao extends DatabaseAccessor<AppDb> with _$SummaryDaoMixin {
  final AppDb db;
  SummaryDao(this.db) : super(db);

  Stream<List<SessionSummary>> watchSummaries({int limit = 100, int offset = 0}) {
    final q = (select(sessionSummaries)
          ..orderBy([(s) => OrderingTerm(expression: s.updatedAt, mode: OrderingMode.desc)])
          ..limit(limit, offset: offset));
    return q.watch();
  }

  Future<void> recomputeSummaryForSession(String sessionId) async {
    // Example recompute: total darts and avg score
    final res = await customSelect('SELECT COUNT(*) as total, AVG(score) as avg FROM training_throws WHERE session_id = ?', variables: [Variable(sessionId)], readsFrom: {trainingThrows}).getSingle();
    final total = res.data['total'] as int? ?? 0;
    final avg = (res.data['avg'] as num?)?.toDouble() ?? 0.0;
    await (update(sessionSummaries)..where((s) => s.sessionId.equals(sessionId))).write(SessionSummariesCompanion(
      totalDarts: Value(total),
      avgScore: Value(avg),
      updatedAt: Value(DateTime.now()),
    ));
  }

  Future<void> recomputeAllSummaries({int chunk = 200}) async {
    final rows = await customSelect('SELECT session_id FROM training_throws GROUP BY session_id LIMIT ?', variables: [Variable(chunk)], readsFrom: {trainingThrows}).get();
    for (final r in rows) {
      final sid = r.read<String>('session_id');
      await recomputeSummaryForSession(sid);
    }
  }
}

