/// File: offline_controller.dart. Contiene componenti condivisi usati in più parti dell'app.

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/darts_match/application/usecases/providers.dart';

final offlineControllerProvider =
StateNotifierProvider<OfflineController, bool>(
      (ref) => OfflineController(ref),
);

class OfflineController extends StateNotifier<bool> {
  /// Funzione: descrive in modo semplice questo blocco di logica.
  OfflineController(this._ref) : super(false) {
    _start();
  }

  final Ref _ref;
  Timer? _timer;

  /// Funzione: descrive in modo semplice questo blocco di logica.
  void _start() {
    _check();

    _timer = Timer.periodic(
      /// Funzione: descrive in modo semplice questo blocco di logica.
      const Duration(seconds: 8),
          (_) => _check(),
    );
  }

  /// Funzione: descrive in modo semplice questo blocco di logica.
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
  /// Funzione: descrive in modo semplice questo blocco di logica.
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
