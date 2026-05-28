import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables.dart';
part 'app_db.g.dart';

@DriftDatabase(tables: [
  TrainingSessions,
  TrainingThrows,
  MatchSessions,
  MatchTurns,
  MatchDarts,
  SessionSummaries,
  UserProfiles,
])
class AppDb extends _$AppDb {
  @override
  int get schemaVersion => 1;
  AppDb._(QueryExecutor e) : super(e);

  static Future<AppDb> openConnection() async {
    final docs = await getApplicationDocumentsDirectory();
    final file = File(p.join(docs.path, 'darts_app.sqlite'));
    final executor = NativeDatabase(file, logStatements: false);
    return AppDb._(executor);
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          // Create required indexes to optimize queries
          await customStatement('CREATE INDEX IF NOT EXISTS idx_training_throws_session ON training_throws(session_id)');
          await customStatement('CREATE INDEX IF NOT EXISTS idx_training_throws_player ON training_throws(player_id)');
          await customStatement('CREATE INDEX IF NOT EXISTS idx_training_throws_target ON training_throws(target)');
          await customStatement('CREATE INDEX IF NOT EXISTS idx_training_throws_updated ON training_throws(updated_at)');
          await customStatement('CREATE INDEX IF NOT EXISTS idx_match_darts_session ON match_darts(session_id)');
          await customStatement('CREATE INDEX IF NOT EXISTS idx_match_darts_player ON match_darts(player_id)');
          await customStatement('CREATE INDEX IF NOT EXISTS idx_summary_updated ON session_summaries(updated_at)');
        },
        onUpgrade: (m, from, to) async {
          // Implement migrations incrementally. Keep backwards-compatible changes here.
        },
      );
}

