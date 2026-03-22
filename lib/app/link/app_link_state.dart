import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:app_links/app_links.dart';

class AppLinkState {
  final String? pendingRoomId;
  final bool consumed;

  const AppLinkState({
    this.pendingRoomId,
    this.consumed = false,
  });

  AppLinkState copyWith({
    String? pendingRoomId,
    bool? consumed,
  }) {
    return AppLinkState(
      pendingRoomId: pendingRoomId ?? this.pendingRoomId,
      consumed: consumed ?? this.consumed,
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
        consumed: false,
      );
    }
  }
  final _appLinks = AppLinks();
  StreamSubscription? _sub;

  Future<void> init() async {
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
      consumed: false,
    );

  }

  String? consumeRoomId() {
    if (state.pendingRoomId == null) return null;
    final id = state.pendingRoomId;
    state = state.copyWith(consumed: true);
    return id;
  }
}