/// FILE: main.dart
/// TARGET: Entry point pulito e minimale.
/// LOGIC GOAL: Inizializzare widgets e delegare bootstrap a componente separato.
/// REACTION: Delegare interamente la logica di startup a _DartsStartupGate.
/// ERROR STRATEGY: Affidata interamente a DartBootSplash.
/// ANTI-REGRESSION: Mantenere Firebase init, sync, stats, userProvider, container.

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';
import 'app/di/app_dependencies.dart';
import 'app/link/app_link_state.dart';
import 'features/bootstrap/presentation/dart_boot_splash.dart';
import 'features/match_sync/data/services/local_match_sync_service.dart';
import 'features/players/application/user_notifier.dart';
import 'features/stats/data/datasources/local_training_sync_service.dart';
import 'features/stats/domain/services/stats_aggregator_service.dart';
import 'features/stats/shared/stats_repository.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer();
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: _DartsStartupGate(container: container),
    ),
  );
}

class _DartsStartupGate extends StatefulWidget {
  final ProviderContainer container;
  const _DartsStartupGate({required this.container});

  @override
  State<_DartsStartupGate> createState() => _DartsStartupGateState();
}

class _DartsStartupGateState extends State<_DartsStartupGate> {
  double _progress = 0.02;
  String _label = 'AVVIO ARENA...';
  bool _ready = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    try {
      await _update(0.06, 'PREPARO INTERFACCIA...');
      await Future<void>.delayed(const Duration(milliseconds: 80));

      await _update(0.16, 'CARICO DIPENDENZE...');
      await AppDependencies.initialize();

      await _update(0.30, 'CONNETTO FIREBASE...');
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      FirebaseFirestore.instance.settings =
      const Settings(persistenceEnabled: true);

      await _update(0.42, 'VERIFICO ACCESSO...');
      final user = await FirebaseAuth.instance.authStateChanges().first;

      await _update(0.50, 'INIZIALIZZO LINK APP...');
      await widget.container.read(appLinkCoordinatorProvider.notifier).init();

      if (user != null) {
        await _update(0.60, 'CARICO PROFILO...');
        await widget.container.read(userProvider.notifier).loadProfile();

        await _update(0.64, 'SINCRONIZZO MATCH...');
        await LocalMatchSyncService.instance.syncAll();

        await _update(0.74, 'SINCRONIZZO TRAINING...');
        await LocalTrainingSyncService.instance.syncAll();

        await _update(0.84, 'FINALIZZO...');
        StatsRepository.instance.invalidateCache();
      } else {
        await _update(0.94, 'PREPARO LOGIN...');
        await Future<void>.delayed(const Duration(milliseconds: 240));
      }

      await _update(1.0, '');
      await Future<void>.delayed(const Duration(milliseconds: 2060));

      if (!mounted) return;
      setState(() => _ready = true);
    } catch (e, st) {
      debugPrint('BOOT ERROR: $e');
      debugPrintStack(stackTrace: st);
      if (!mounted) return;
      setState(() {
        _error = e;
        _label = 'ERRORE AVVIO';
      });
    }
  }

  Future<void> _update(double progress, String label) async {
    if (!mounted) return;

    final target = progress.clamp(0.0, 1.0);
    final start = _progress;

    if (target <= start) {
      setState(() => _label = label);
      return;
    }

    const stepSize = 0.01;
    var current = start;

    while (current < target) {
      if (!mounted) return;

      current = (current + stepSize).clamp(0.0, target);

      setState(() {
        _progress = current;
        _label = label;
      });

      await Future<void>.delayed(const Duration(milliseconds: 28));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return const DartsApp();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: DartBootSplash(
        appName: 'My Darts Roser Trainer',
        state: BootState(
          progress: _progress,
          label: _label,
          error: _error,
          onRetry: _error == null
              ? null
              : () {
            setState(() {
              _progress = 0.02;
              _label = 'AVVIO ARENA...';
              _error = null;
            });
            _bootstrap();
          },
        ),
      ),
    );
  }
}