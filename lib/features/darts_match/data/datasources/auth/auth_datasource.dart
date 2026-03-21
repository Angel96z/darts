import 'package:firebase_auth/firebase_auth.dart';

class AuthDataSource {
  AuthDataSource(this._auth);
  final FirebaseAuth _auth;

  Future<UserCredential> signInAnonymously() => _auth.signInAnonymously();

  User? get currentUser => _auth.currentUser;
}
