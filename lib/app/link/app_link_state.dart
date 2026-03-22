import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _pendingRoomIdKey = 'pending_room_id';

class AppLinkState {
  final String? pendingRoomId;

  const AppLinkState({
    this.pendingRoomId,
  });

  AppLinkState copyWith({
    String? pendingRoomId,
  }) {
    return AppLinkState(
      pendingRoomId: pendingRoomId,
    );
  }
}

final appLinkCoordinatorProvider =
StateNotifierProvider<AppLinkCoordinator, AppLinkState>(
      (ref) => AppLinkCoordinator(),
);

class AppLinkCoordinator extends StateNotifier<AppLinkState> {
  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
  AppLinkCoordinator() : super(const AppLinkState()) {
    // fallback web
    final uri = Uri.base;
    final roomId = uri.queryParameters['roomId'];
    if (roomId != null && roomId.isNotEmpty) {
      state = AppLinkState(
        pendingRoomId: roomId,
      );
    }
  }
  final _appLinks = AppLinks();
  StreamSubscription? _sub;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedRoomId = prefs.getString(_pendingRoomIdKey);
    if ((state.pendingRoomId == null || state.pendingRoomId!.isEmpty) &&
        savedRoomId != null &&
        savedRoomId.isNotEmpty) {
      state = AppLinkState(pendingRoomId: savedRoomId);
    }

    try {
      // cold start
      final uri = await _appLinks.getInitialLink();
      if (uri != null) {
        setIncomingLink(uri.toString());
      }
    } catch (_) {}

    _sub = _appLinks.uriLinkStream.listen(
          (uri) {
        if (uri != null) {
          setIncomingLink(uri.toString());
        }
      },
      onError: (_) {},
    );
  }

  void setIncomingLink(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return;

    final roomId = uri.queryParameters['roomId'];
    if (roomId == null || roomId.isEmpty) return;

    state = AppLinkState(
      pendingRoomId: roomId,
    );

    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(_pendingRoomIdKey, roomId);
    });

  }

  String? consumeRoomId() {
    final id = state.pendingRoomId;
    state = const AppLinkState(pendingRoomId: null);

    SharedPreferences.getInstance().then((prefs) {
      prefs.remove(_pendingRoomIdKey);
    });

    return id;
  }
}
