/// File: offline_controller.dart. Contiene componenti condivisi usati in più parti dell'app.

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

final backendConnectionServiceProvider =
Provider<_BackendConnectionService>((ref) {
  return _BackendConnectionService();
});

class _BackendConnectionService {
  Future<bool> checkBackendConnection() async {
    try {
      // Verifica reale: ping Firestore (backend reale usato dall'app)
      await FirebaseFirestore.instance
          .collection('_healthcheck')
          .limit(1)
          .get(const GetOptions(source: Source.server));

      return true;
    } catch (_) {
      return false;
    }
  }
}

final offlineControllerProvider =
StateNotifierProvider<OfflineController, bool>(
      (ref) => OfflineController(ref),
);

class OfflineController extends StateNotifier<bool> {
  OfflineController(this._ref) : super(true) {
    _start();
  }

  final Ref _ref;
  Timer? _timer;

  void _start() {
    _check();

    _timer = Timer.periodic(
      const Duration(seconds: 8),
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