import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/drift.dart';
import '../drift/app_db.dart';
import '../drift/tables.dart';

/// MigrationService: chunked, resumable migration from SharedPreferences JSON blobs to Drift.
class MigrationService {
  final SharedPreferences prefs;
  final AppDb db;
  static const _completedKey = 'drift_migration_completed';
  static const _cursorKey = 'drift_migration_cursor_sessions';

  MigrationService({required this.prefs, required this.db});

  Future<bool> isCompleted() async => prefs.getBool(_completedKey) ?? false;

  Future<void> migrateIfNeeded({int sessionChunk = 200}) async {
    if (await isCompleted()) return;
    // Try to find legacy sessions blob. We support multiple legacy shapes.
    // 1) single key 'legacy_all_sessions' (JSON array)
    // 2) multiple keys 'session:<id>'

    final legacyBlob = prefs.getString('legacy_all_sessions');
    if (legacyBlob != null) {
      await _migrateFromBlob(legacyBlob, sessionChunk);
      await prefs.setBool(_completedKey, true);
      return;
    }

    // Fallback: iterate keys session:<id>
    final keys = prefs.getKeys().where((k) => k.startsWith('session:')).toList();
    if (keys.isEmpty) {
      // nothing to migrate
      await prefs.setBool(_completedKey, true);
      return;
    }

    int cursor = prefs.getInt(_cursorKey) ?? 0;
    while (cursor < keys.length) {
      final end = (cursor + sessionChunk).clamp(0, keys.length);
      final chunkKeys = keys.sublist(cursor, end);
      await db.transaction(() async {
        for (final k in chunkKeys) {
          final jsonStr = prefs.getString(k);
          if (jsonStr == null) continue;
          try {
            final map = jsonDecode(jsonStr) as Map<String, dynamic>;
            final sid = map['id'] as String?;
            if (sid == null) continue;
            final sessionCompanion = TrainingSessionsCompanion.insert(
              id: sid,
              playerId: Value(map['playerId'] as String?),
              createdAt: DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now(),
              updatedAt: Value(map['updatedAt'] != null ? DateTime.tryParse(map['updatedAt'] as String) : null),
              name: Value(map['name'] as String?),
              mode: Value(map['mode'] as String?),
              metaJson: Value(map['metaJson'] != null ? jsonEncode(map['metaJson']) : null),
            );
            await db.into(db.trainingSessions).insert(sessionCompanion, mode: InsertMode.insertOrReplace);

            // throws: expect an array under 'throws'
            final throwsList = (map['throws'] as List<dynamic>?) ?? [];
            if (throwsList.isNotEmpty) {
              final companions = <Insertable<TrainingThrow>>[];
              for (final t in throwsList) {
                final tm = t as Map<String, dynamic>;
                companions.add(TrainingThrowsCompanion.insert(
                  id: tm['id'] as String,
                  sessionId: sid,
                  playerId: Value(tm['playerId'] as String?),
                  thrownAt: DateTime.tryParse(tm['thrownAt'] as String) ?? DateTime.now(),
                  score: tm['score'] as int? ?? 0,
                  target: Value(tm['target'] as String?),
                  multiplier: Value(tm['multiplier'] as int? ?? 1),
                  x: Value((tm['x'] as num?)?.toDouble()),
                  y: Value((tm['y'] as num?)?.toDouble()),
                  updatedAt: Value(tm['updatedAt'] != null ? DateTime.tryParse(tm['updatedAt'] as String) : null),
                  extraJson: Value(tm['extraJson'] != null ? jsonEncode(tm['extraJson']) : null),
                ));
              }
              // batch insert
              await db.batch((b) => b.insertAll(db.trainingThrows, companions));
            }
          } catch (e) {
            // ignore individual parse errors but continue
          }
        }
      });
      cursor = end;
      await prefs.setInt(_cursorKey, cursor);
    }

    await prefs.setBool(_completedKey, true);
  }

  Future<void> _migrateFromBlob(String blob, int chunk) async {
    final list = jsonDecode(blob) as List<dynamic>;
    int cursor = prefs.getInt(_cursorKey) ?? 0;
    while (cursor < list.length) {
      final end = (cursor + chunk).clamp(0, list.length);
      final chunkItems = list.sublist(cursor, end);
      await db.transaction(() async {
        for (final item in chunkItems) {
          try {
            final map = item as Map<String, dynamic>;
            final sid = map['id'] as String?;
            if (sid == null) continue;
            final sessionCompanion = TrainingSessionsCompanion.insert(
              id: sid,
              playerId: Value(map['playerId'] as String?),
              createdAt: DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now(),
              updatedAt: Value(map['updatedAt'] != null ? DateTime.tryParse(map['updatedAt'] as String) : null),
              name: Value(map['name'] as String?),
              mode: Value(map['mode'] as String?),
              metaJson: Value(map['metaJson'] != null ? jsonEncode(map['metaJson']) : null),
            );
            await db.into(db.trainingSessions).insert(sessionCompanion, mode: InsertMode.insertOrReplace);

            final throwsList = (map['throws'] as List<dynamic>?) ?? [];
            if (throwsList.isNotEmpty) {
              final companions = <Insertable<TrainingThrow>>[];
              for (final t in throwsList) {
                final tm = t as Map<String, dynamic>;
                companions.add(TrainingThrowsCompanion.insert(
                  id: tm['id'] as String,
                  sessionId: sid,
                  playerId: Value(tm['playerId'] as String?),
                  thrownAt: DateTime.tryParse(tm['thrownAt'] as String) ?? DateTime.now(),
                  score: tm['score'] as int? ?? 0,
                  target: Value(tm['target'] as String?),
                  multiplier: Value(tm['multiplier'] as int? ?? 1),
                  x: Value((tm['x'] as num?)?.toDouble()),
                  y: Value((tm['y'] as num?)?.toDouble()),
                  updatedAt: Value(tm['updatedAt'] != null ? DateTime.tryParse(tm['updatedAt'] as String) : null),
                  extraJson: Value(tm['extraJson'] != null ? jsonEncode(tm['extraJson']) : null),
                ));
              }
              await db.batch((b) => b.insertAll(db.trainingThrows, companions));
            }
          } catch (e) {
            // continue on errors
          }
        }
      });
      cursor = end;
      await prefs.setInt(_cursorKey, cursor);
    }
  }
}

