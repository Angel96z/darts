import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class GuestAuthResult {
  final String uid;
  final String? email;
  final String? name;

  GuestAuthResult({
    required this.uid,
    this.email,
    this.name,
  });
}

class GuestAuthService {
  static int _counter = 0;

  Future<GuestAuthResult> signIn({
    required String email,
    required String password,
  }) async {
    final appName = 'guest_app_${_counter++}';

    final app = await Firebase.initializeApp(
      name: appName,
      options: Firebase.app().options,
    );

    final auth = FirebaseAuth.instanceFor(app: app);

    final cred = await auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = cred.user!;
    return GuestAuthResult(
      uid: user.uid,
      email: user.email,
      name: user.displayName,
    );
  }
}