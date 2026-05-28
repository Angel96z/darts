import 'package:drift/drift.dart';
import 'app_db.dart';
import 'tables.dart';

part 'user_profile_dao.g.dart';

@DriftAccessor(tables: [UserProfiles])
class UserProfileDao extends DatabaseAccessor<AppDb> with _$UserProfileDaoMixin {
  final AppDb db;
  UserProfileDao(this.db) : super(db);

  Future<void> upsertLocalProfile(UserProfilesCompanion profile) async {
    await into(userProfiles).insert(
      profile,
      mode: InsertMode.insertOrReplace,
    );
  }

  Future<UserProfile?> getLocalProfile(String uid) async {
    final query = select(userProfiles)..where((t) => t.uid.equals(uid));
    final result = await query.get();
    return result.isNotEmpty ? result.first : null;
  }

  Stream<UserProfile?> watchLocalProfile(String uid) {
    final query = select(userProfiles)..where((t) => t.uid.equals(uid));
    return query.watch().map((list) => list.isNotEmpty ? list.first : null);
  }

  Future<void> updateSyncStatus(String uid, String status) async {
    await (update(userProfiles)..where((t) => t.uid.equals(uid))).write(
      UserProfilesCompanion(
        syncStatus: Value(status),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<List<UserProfile>> getPendingSyncProfiles() async {
    final query = select(userProfiles)..where((t) => t.syncStatus.equals('pending'));
    return await query.get();
  }
}