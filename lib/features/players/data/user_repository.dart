/// File: user_repository.dart
/// TARGET: Interfacciamento Firestore per profilo utente
/// LOGIC GOAL: CRUD operazioni su Firestore per profilo, preferenze, statistiche aggregate
/// ERROR STRATEGY: Restituisce Future<UserProfile> o lancia Failure tipizzate
/// ANTI-REGRESSION: Mantenere compatibilità con sistema auth esistente

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/failure.dart';
import '../../players/domain/user_profile.dart';

class UserRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _currentUid {
    final user = _auth.currentUser;
    if (user == null) throw const AuthFailure(message: 'Utente non autenticato');
    return user.uid;
  }

  DocumentReference _profileRef(String uid) {
    return _firestore.collection('users').doc(uid).collection('profile').doc('main');
  }

  /// Crea o aggiorna profilo utente
  Future<void> upsertProfile(UserProfile profile) async {
    try {
      await _profileRef(profile.uid).set(profile.toMap(), SetOptions(merge: true));
    } catch (e) {
      throw ProfileSaveFailure(technicalDetails: e.toString());
    }
  }

  /// Recupera profilo utente
  Future<UserProfile> fetchProfile(String uid) async {


    print('🔵 fetchProfile - uid: $uid');
    final doc = await _profileRef(uid).get();
    print('🔵 doc.exists: ${doc.exists}');
    print('🔵 doc.data(): ${doc.data()}');


    try {
      final doc = await _profileRef(uid).get();
      if (!doc.exists) {
        throw ProfileNotFoundFailure();
      }
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) {
        throw ProfileNotFoundFailure();
      }
      return UserProfile.fromMap(uid, data);
    } on ProfileNotFoundFailure {
      rethrow;
    } catch (e) {
      throw ProfileNotFoundFailure(technicalDetails: e.toString());
    }
  }
  /// Stream del profilo per sync in tempo reale
  Stream<UserProfile> watchProfile(String uid) {
    return _profileRef(uid).snapshots().map((doc) {
      if (!doc.exists) {
        throw ProfileNotFoundFailure();
      }
      final data = doc.data() as Map<String, dynamic>;
      return UserProfile.fromMap(uid, data);
    });
  }
  /// Recupera profilo utente corrente (con fallback creazione se non esiste)
  Future<UserProfile> fetchOrCreateProfile() async {
    final uid = _currentUid;
    final user = _auth.currentUser;
    final email = user?.email ?? '';

    print('🔵 fetchOrCreateProfile - uid: $uid');
    print('🔵 email: $email');

    try {
      final profile = await fetchProfile(uid);
      print('🟢 Profilo TROVATO: ${profile.displayName}');
      return profile;
    } on ProfileNotFoundFailure {
      print('🟡 Profilo NON TROVATO, creazione...');
      final newProfile = UserProfile(
        uid: uid,
        email: email,
        firstName: '',
        lastName: '',
        nickname: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await upsertProfile(newProfile);
      print('🟢 Profilo CREATO');
      return newProfile;
    }
  }

  /// Aggiorna informazioni base profilo
  Future<void> updateProfileInfo({
    required String firstName,
    required String lastName,
    required String nickname,
  }) async {
    final uid = _currentUid;
    await _profileRef(uid).set({
      'firstName': firstName,
      'lastName': lastName,
      'nickname': nickname,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Aggiorna preferenze utente
  Future<void> updatePreferences(UserPreferences preferences) async {
    final uid = _currentUid;
    await _profileRef(uid).set({
      'preferences': preferences.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Aggiorna avatar URL
  Future<void> updateAvatar(String? avatarUrl) async {
    final uid = _currentUid;
    await _profileRef(uid).set({
      'avatarUrl': avatarUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Aggiorna statistiche aggregate
  Future<void> updateAggregatedStats(UserAggregatedStats stats) async {
    final uid = _currentUid;
    try {
      // 🔥 Usa set con merge:true per sicurezza massima
      await _profileRef(uid).set({
        'stats': stats.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));  // ← KEY: merge true
    } catch (e) {
      throw ProfileSaveFailure(technicalDetails: e.toString());
    }
  }

  /// Verifica se profilo esiste
  Future<bool> profileExists(String uid) async {
    try {
      final doc = await _profileRef(uid).get();
      return doc.exists;
    } catch (_) {
      return false;
    }
  }

  /// Elimina completamente il profilo (usato durante delete account)
  Future<void> deleteProfile(String uid) async {
    try {
      await _profileRef(uid).delete();
    } catch (e) {
      throw ProfileSaveFailure(message: 'Errore eliminazione profilo', technicalDetails: e.toString());
    }
  }
  // Aggiungi questi metodi alla classe UserRepository

  /// Elimina completamente account utente (Auth + Firestore)
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthFailure(message: 'Utente non autenticato');

    final uid = user.uid;

    try {
      // 1. Elimina tutte le sottocollezioni dell'utente
      final userDoc = _firestore.collection('users').doc(uid);

      // Sottocollezioni da eliminare
      final subcollections = [
        'profile',
        'matches',
        'training_sessions',
        'x01_matches',
        'cricket_matches',
      ];

      for (final sub in subcollections) {
        await _deleteCollection(userDoc.collection(sub));
      }

      // 2. Elimina documento utente principale
      await userDoc.delete();

      // 3. Elimina account Firebase Auth
      await user.delete();

    } catch (e) {
      throw ProfileSaveFailure(
        message: 'Errore eliminazione account',
        technicalDetails: e.toString(),
      );
    }
  }

  /// Helper per eliminare collezione in batch
  Future<void> _deleteCollection(CollectionReference<Map<String, dynamic>> collection) async {
    while (true) {
      final snapshot = await collection.limit(400).get();
      if (snapshot.docs.isEmpty) break;

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      if (snapshot.docs.length < 400) break;
    }
  }

  /// Aggiorna avatar ID
  Future<void> updateAvatarId(int? avatarId) async {
    final uid = _currentUid;
    await _profileRef(uid).update({
      'avatarId': avatarId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Invia email di verifica
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthFailure(message: 'Utente non autenticato');
    if (user.emailVerified) return;

    try {
      await user.sendEmailVerification();
    } catch (e) {
      throw ProfileSaveFailure(
        message: 'Errore invio verifica email',
        technicalDetails: e.toString(),
      );
    }
  }

  /// Verifica se email è verificata (con refresh)
  Future<bool> checkEmailVerified() async {
    await _auth.currentUser?.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }

  /// Cambia password (richiede reautenticazione)
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthFailure(message: 'Utente non autenticato');
    if (user.email == null) throw const AuthFailure(message: 'Email non disponibile');

    try {
      // Reautentica
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);

      // Cambia password
      await user.updatePassword(newPassword);

    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password') {
        throw const AuthFailure(message: 'Password corrente errata');
      }
      throw AuthFailure(message: e.message ?? 'Errore cambio password');
    } catch (e) {
      throw AuthFailure(message: e.toString());
    }
  }

  /// Invia reset password (già presente, ma la aggiungo per completezza)
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      throw AuthFailure(message: 'Errore invio reset password');
    }
  }
}

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository();
});