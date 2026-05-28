import 'package:drift/drift.dart';

// Normalized tables for darts analytics

class TrainingSessions extends Table {
  TextColumn get id => text()();
  TextColumn get playerId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  TextColumn get name => text().nullable()();
  TextColumn get mode => text().withLength(min: 0, max: 50).nullable()();
  TextColumn get metaJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class TrainingThrows extends Table {
  IntColumn get seq => integer().autoIncrement()();
  TextColumn get id => text().withLength(min: 1, max: 50)();
  TextColumn get sessionId => text().customConstraint('REFERENCES training_sessions(id)')();
  TextColumn get playerId => text().nullable()();
  DateTimeColumn get thrownAt => dateTime()();
  IntColumn get score => integer()();
  TextColumn get target => text().nullable()();
  IntColumn get multiplier => integer().withDefault(const Constant(1))();
  RealColumn get x => real().nullable()();
  RealColumn get y => real().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  TextColumn get extraJson => text().nullable()();
}

class MatchSessions extends Table {
  TextColumn get id => text()();
  TextColumn get gameType => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  TextColumn get metaJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class MatchTurns extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get sessionId => text().customConstraint('REFERENCES match_sessions(id)')();
  IntColumn get leg => integer().nullable()();
  IntColumn get round => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get metaJson => text().nullable()();
}

class MatchDarts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get sessionId => text().customConstraint('REFERENCES match_sessions(id)')();
  IntColumn get turnId => integer().customConstraint('REFERENCES match_turns(id)')();
  TextColumn get playerId => text().nullable()();
  DateTimeColumn get thrownAt => dateTime()();
  IntColumn get score => integer()();
  TextColumn get target => text().nullable()();
  IntColumn get multiplier => integer().withDefault(const Constant(1))();
  RealColumn get x => real().nullable()();
  RealColumn get y => real().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  TextColumn get extraJson => text().nullable()();
}

class UserProfiles extends Table {
  TextColumn get uid => text()();
  TextColumn get email => text().nullable()();
  TextColumn get firstName => text().nullable()();
  TextColumn get lastName => text().nullable()();
  TextColumn get nickname => text().nullable()();
  IntColumn get avatarId => integer().nullable()();
  TextColumn get avatarUrl => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get syncStatus => text().withDefault(const Constant('synced'))();

  @override
  Set<Column> get primaryKey => {uid};
}

class SessionSummaries extends Table {
  TextColumn get sessionId => text().customConstraint('UNIQUE REFERENCES training_sessions(id)')();
  IntColumn get totalDarts => integer().withDefault(const Constant(0))();
  RealColumn get hitRate => real().withDefault(const Constant(0.0))();
  RealColumn get avgScore => real().withDefault(const Constant(0.0))();
  RealColumn get precision => real().withDefault(const Constant(0.0))();
  RealColumn get checkoutPct => real().withDefault(const Constant(0.0))();
  IntColumn get marksPerRound => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {sessionId};
}


