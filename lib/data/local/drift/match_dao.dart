import 'package:drift/drift.dart';
import 'app_db.dart';
import 'tables.dart';
part 'match_dao.g.dart';

@DriftAccessor(tables: [MatchSessions, MatchTurns, MatchDarts, SessionSummaries])
class MatchDao extends DatabaseAccessor<AppDb> with _$MatchDaoMixin {
  final AppDb db;
  MatchDao(this.db) : super(db);

  Future<void> insertMatchSession(Insertable<MatchSession> session) async {
    await into(matchSessions).insert(session);
  }

  Future<void> insertTurn(MatchTurnsCompanion turn) async {
    await into(matchTurns).insert(turn);
  }

  Future<void> insertDart(MatchDartsCompanion dartRow) async {
    await into(matchDarts).insert(dartRow);
  }

  Stream<List<MatchDart>> watchDartsForSession(
      String sessionId, {
        int limit = 100,
        int offset = 0,
      }) {
    final q = (select(matchDarts)
      ..where((d) => d.sessionId.equals(sessionId))
      ..orderBy([
            (d) => OrderingTerm(
          expression: d.thrownAt,
          mode: OrderingMode.asc,
        ),
      ])
      ..limit(limit, offset: offset));

    return q.watch();
  }

  Future<double> computeCheckoutPct(String sessionId) async {
    // Example aggregate: count turns where a checkout occurred divided by total turns
    final result = await customSelect('''
      SELECT
        SUM(CASE WHEN (extraJson LIKE '%"is_checkout":true%') THEN 1 ELSE 0 END) as checkouts,
        COUNT(DISTINCT turn_id) as total_turns
      FROM match_darts
      WHERE session_id = ?
    ''', variables: [Variable(sessionId)], readsFrom: {matchDarts}).getSingleOrNull();
    if (result == null) return 0.0;
    final checkouts = result.data['checkouts'] as int? ?? 0;
    final total = result.data['total_turns'] as int? ?? 0;
    if (total == 0) return 0.0;
    return checkouts / total;
  }
}

