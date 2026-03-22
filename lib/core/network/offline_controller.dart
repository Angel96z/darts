import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/darts_match/application/usecases/providers.dart';

final offlineControllerProvider =
StateNotifierProvider<OfflineController, bool>(
      (ref) => OfflineController(ref),
);

class OfflineController extends StateNotifier<bool> {
  OfflineController(this._ref) : super(false) {
    _start();
  }

  final Ref _ref;
  Timer? _timer;

  void _start() {
    _check();

    _timer = Timer.periodic(
      const Duration(seconds: 3),
          (_) => _check(),
    );
  }

  Future<void> _check() async {
    try {
      final online = await _ref
          .read(backendConnectionServiceProvider)
          .checkBackendConnection();

      state = online;
    } catch (_) {
      state = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}