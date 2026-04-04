class LocalMatchStorage {
  static final Map<String, Map<String, dynamic>> _cache = {};

  static void save(String matchId, Map<String, dynamic> data) {
    _cache[matchId] = data;
  }

  static Map<String, dynamic>? get(String matchId) {
    return _cache[matchId];
  }

  static void clear(String matchId) {
    _cache.remove(matchId);
  }
}