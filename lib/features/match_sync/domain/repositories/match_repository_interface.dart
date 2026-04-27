/// File: match_repository_interface.dart

import '../entities/local_match_record.dart';

abstract class MatchRepositoryInterface {
  Future<String> saveMatch(LocalMatchRecord record);
  Future<void> updateMatchStatus(String matchId, String status);
  Future<bool> existsMatch(String matchId);
}