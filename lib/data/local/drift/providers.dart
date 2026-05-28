import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_db.dart';
import 'training_dao.dart';
import 'match_dao.dart';
import 'summary_dao.dart';
import '../../repositories/drift_training_repository.dart';
import '../migration/migration_service.dart';
import 'user_profile_dao.dart';

final appDbAsyncProvider = FutureProvider<AppDb>((ref) async {
  return AppDb.openConnection();
});

final trainingDaoProvider = FutureProvider<TrainingDao>((ref) async {
  final db = await ref.watch(appDbAsyncProvider.future);
  return TrainingDao(db);
});

final matchDaoProvider = FutureProvider<MatchDao>((ref) async {
  final db = await ref.watch(appDbAsyncProvider.future);
  return MatchDao(db);
});

final summaryDaoProvider = FutureProvider<SummaryDao>((ref) async {
  final db = await ref.watch(appDbAsyncProvider.future);
  return SummaryDao(db);
});
final userProfileDaoProvider = FutureProvider<UserProfileDao>((ref) async {
  final db = await ref.watch(appDbAsyncProvider.future);
  return UserProfileDao(db);
});
final migrationServiceProvider = Provider<MigrationService>((ref) {
  final prefsFuture = SharedPreferences.getInstance();
  final db = ref.watch(appDbAsyncProvider).maybeWhen(data: (d) => d, orElse: () => throw StateError('DB not ready'));
  // NOTE: calling SharedPreferences synchronously isn't allowed here; use .then to construct service where needed.
  throw UnimplementedError('Use MigrationService with explicit construction where needed to handle async SharedPreferences');
});

final driftTrainingRepositoryProvider = Provider.autoDispose<dynamic>((ref) {
  throw UnimplementedError();
});

