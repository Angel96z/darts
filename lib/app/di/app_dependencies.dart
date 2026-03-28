import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../features/stats/data/datasources/local_training_sync_service.dart';
import '../../features/stats/data/repositories_impl/training_repository.dart';
import '../../firebase_options.dart';

class AppDependencies {
  static Future<void> initialize() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    await LocalTrainingSyncService.initialize(TrainingRepository());

    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
    );
  }
}
