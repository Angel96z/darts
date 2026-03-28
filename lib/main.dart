/// File: main.dart. Contiene codice Dart del progetto.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/di/app_dependencies.dart';
import 'app/link/app_link_state.dart';

/// Funzione: descrive in modo semplice questo blocco di logica.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppDependencies.initialize();

  final container = ProviderContainer();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const DartsApp(),
    ),
  );
}