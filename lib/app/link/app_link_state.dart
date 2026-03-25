import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_links/app_links.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _pendingRoomIdKey = 'pending_room_id';
const _pendingWatchRoomIdKey = 'pending_watch_room_id';

class AppLinkState {
  final String? pendingRoomId;
  final String? pendingWatchRoomId;

  const AppLinkState({this.pendingRoomId, this.pendingWatchRoomId});

  AppLinkState copyWith({
    String? pendingRoomId,
    String? pendingWatchRoomId,
    bool clearRoomId = false,
    bool clearWatchRoomId = false,
  }) {
    return AppLinkState(
      pendingRoomId: clearRoomId ? null : (pendingRoomId ?? this.pendingRoomId),
      pendingWatchRoomId: clearWatchRoomId ? null : (pendingWatchRoomId ?? this.pendingWatchRoomId),
    );
  }
}

final appLinkCoordinatorProvider =
StateNotifierProvider<AppLinkCoordinator, AppLinkState>(
      (ref) => AppLinkCoordinator(),
);

class AppLinkCoordinator extends StateNotifier<AppLinkState> {
  bool _initialized = false;
  AppLinkCoordinator() : super(const AppLinkState());

  final _appLinks = AppLinks();
  StreamSubscription? _sub;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final prefs = await SharedPreferences.getInstance();

    try {
      final uri = await _appLinks.getInitialLink();
      if (uri != null) {
        await _handleUri(uri);
      }
    } catch (_) {}

    final webRoomId = Uri.base.queryParameters['roomId'];
    if (webRoomId != null && webRoomId.isNotEmpty) {
      await _handleUri(Uri.base);
    }

    if (state.pendingRoomId == null || state.pendingRoomId!.isEmpty) {
      final saved = prefs.getString(_pendingRoomIdKey);
      if (saved != null && saved.isNotEmpty) {
        state = AppLinkState(pendingRoomId: saved.trim());
      }
    }

    if (state.pendingWatchRoomId == null || state.pendingWatchRoomId!.isEmpty) {
      final savedWatch = prefs.getString(_pendingWatchRoomIdKey);
      if (savedWatch != null && savedWatch.isNotEmpty) {
        state = state.copyWith(pendingWatchRoomId: savedWatch.trim());
      }
    }

    _sub = _appLinks.uriLinkStream.listen((uri) async {
      if (uri == null) return;
      await _handleUri(uri);
    });
  }

  Future<void> _handleUri(Uri uri) async {
    final prefs = await SharedPreferences.getInstance();

    // 🔥 NORMALIZZAZIONE UNICA
    // funziona per:
    // - produzione web
    // - localhost
    // - mobile deep link

    final params = uri.queryParameters;

    final raw = params['roomId'];
    final rawWatch = params['watchRoomId'];

    if ((raw == null || raw.isEmpty) &&
        (rawWatch == null || rawWatch.isEmpty)) {
      return;
    }

    if (raw != null && raw.trim().isNotEmpty) {
      final roomId = raw.trim();

      state = AppLinkState(
        pendingRoomId: roomId,
        pendingWatchRoomId: null,
      );

      await prefs.setString(_pendingRoomIdKey, roomId);
      return;
    }

    if (rawWatch != null && rawWatch.trim().isNotEmpty) {
      final watchId = rawWatch.trim();

      state = AppLinkState(
        pendingWatchRoomId: watchId,
        pendingRoomId: null,
      );
      await prefs.setString(_pendingWatchRoomIdKey, watchId);
    }
  }

  Future<String?> consumeRoomId() async {
    final id = state.pendingRoomId;
    if (id == null || id.isEmpty) return null;

// reset stato
    state = const AppLinkState(pendingRoomId: null);

// pulizia storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingRoomIdKey);

    return id;

  }

  Future<String?> consumeWatchRoomId() async {
    final id = state.pendingWatchRoomId;
    if (id == null || id.isEmpty) return null;

    state = state.copyWith(clearWatchRoomId: true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingWatchRoomIdKey);
    return id;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
