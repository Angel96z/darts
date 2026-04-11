import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_links/app_links.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _pendingRoomIdKey = 'pending_room_id';
const _pendingWatchRoomIdKey = 'pending_watch_room_id';

class AppLinkState {
  final String? pendingRoomId;
  final String? pendingWatchRoomId;

  const AppLinkState({
    this.pendingRoomId,
    this.pendingWatchRoomId,
  });

  AppLinkState copyWith({
    String? pendingRoomId,
    String? pendingWatchRoomId,
    bool clearRoomId = false,
    bool clearWatchRoomId = false,
  }) {
    return AppLinkState(
      pendingRoomId: clearRoomId ? null : (pendingRoomId ?? this.pendingRoomId),
      pendingWatchRoomId: clearWatchRoomId
          ? null
          : (pendingWatchRoomId ?? this.pendingWatchRoomId),
    );
  }
}

final appLinkCoordinatorProvider =
StateNotifierProvider<AppLinkCoordinator, AppLinkState>(
      (ref) => AppLinkCoordinator(),
);

class AppLinkCoordinator extends StateNotifier<AppLinkState> {
  AppLinkCoordinator() : super(const AppLinkState());

  final _appLinks = AppLinks();
  StreamSubscription? _sub;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final prefs = await SharedPreferences.getInstance();

    // 🔥 1. SOLO LINK REALI (no fallback automatici sporchi)
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri != null) {
        await _handleUri(uri);
      }
    } catch (_) {}

    final webRoomId = Uri.base.queryParameters['roomId'];
    final webWatchRoomId = Uri.base.queryParameters['watchRoomId'];

    if ((webRoomId != null && webRoomId.isNotEmpty) ||
        (webWatchRoomId != null && webWatchRoomId.isNotEmpty)) {
      await _handleUri(Uri.base);
    }

    // 🔥 2. RIPRISTINO SOLO SE NON C'È GIÀ STATO (ONE-SHOT)
    if (state.pendingRoomId == null) {
      final saved = prefs.getString(_pendingRoomIdKey);
      if (saved != null && saved.isNotEmpty) {
        state = AppLinkState(
          pendingRoomId: saved.trim(),
          pendingWatchRoomId: null,
        );
      }
    }

    if (state.pendingWatchRoomId == null) {
      final saved = prefs.getString(_pendingWatchRoomIdKey);
      if (saved != null && saved.isNotEmpty) {
        state = AppLinkState(
          pendingRoomId: null,
          pendingWatchRoomId: saved.trim(),
        );
      }
    }

    // 🔥 3. STREAM LINK (SEMPRE SOVRASCRIVE)
    _sub = _appLinks.uriLinkStream.listen((uri) async {
      if (uri == null) return;
      await _handleUri(uri);
    });
  }

  Future<void> _handleUri(Uri uri) async {
    final prefs = await SharedPreferences.getInstance();
    final params = uri.queryParameters;

    final rawRoomId = params['roomId'];
    final rawWatchRoomId = params['watchRoomId'];

    if ((rawRoomId == null || rawRoomId.trim().isEmpty) &&
        (rawWatchRoomId == null || rawWatchRoomId.trim().isEmpty)) {
      return;
    }

    // 🔥 PRIORITÀ: roomId > watchRoomId
    if (rawRoomId != null && rawRoomId.trim().isNotEmpty) {
      final roomId = rawRoomId.trim();

      state = AppLinkState(
        pendingRoomId: roomId,
        pendingWatchRoomId: null,
      );

      await prefs.setString(_pendingRoomIdKey, roomId);
      await prefs.remove(_pendingWatchRoomIdKey);
      return;
    }

    if (rawWatchRoomId != null && rawWatchRoomId.trim().isNotEmpty) {
      final watchRoomId = rawWatchRoomId.trim();

      state = AppLinkState(
        pendingRoomId: null,
        pendingWatchRoomId: watchRoomId,
      );

      await prefs.setString(_pendingWatchRoomIdKey, watchRoomId);
      await prefs.remove(_pendingRoomIdKey);
    }
  }

  // =========================
  // ONE-SHOT CONSUME
  // =========================

  Future<String?> consumeRoomId() async {
    final id = state.pendingRoomId;
    if (id == null || id.isEmpty) return null;

    // 🔥 RESET IMMEDIATO (memory + prefs)
    state = const AppLinkState();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingRoomIdKey);
    await prefs.remove(_pendingWatchRoomIdKey);

    return id;
  }

  Future<String?> consumeWatchRoomId() async {
    final id = state.pendingWatchRoomId;
    if (id == null || id.isEmpty) return null;

    state = const AppLinkState();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingRoomIdKey);
    await prefs.remove(_pendingWatchRoomIdKey);

    return id;
  }

  // =========================
  // HARD RESET
  // =========================

  Future<void> clearAll() async {
    state = const AppLinkState();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingRoomIdKey);
    await prefs.remove(_pendingWatchRoomIdKey);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}