/// File: main.dart. Contiene codice Dart del progetto.

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/di/app_dependencies.dart';
import 'app/link/app_link_state.dart';
import 'firebase_options.dart';

/// Funzione: descrive in modo semplice questo blocco di logica.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppDependencies.initialize();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  final app = Firebase.app();
  print("FIREBASE APP ID: ${app.options.appId}");
  print("FIREBASE PROJECT ID: ${app.options.projectId}");
  print("FIREBASE API KEY: ${app.options.apiKey}");  final container = ProviderContainer();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const DartsApp(),
    ),
  );
}