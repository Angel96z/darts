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

  /// Recupera profilo utente corrente (con fallback creazione se non esiste)
  Future<UserProfile> fetchOrCreateProfile() async {
    final uid = _currentUid;
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthFailure(message: 'Utente non autenticato');
    }
    final email = user.email ?? '';

    try {
      return await fetchProfile(uid);
    } on ProfileNotFoundFailure {
      // Crea profilo di default
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
    await _profileRef(uid).update({
      'firstName': firstName,
      'lastName': lastName,
      'nickname': nickname,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Aggiorna preferenze utente
  Future<void> updatePreferences(UserPreferences preferences) async {
    final uid = _currentUid;
    await _profileRef(uid).update({
      'preferences': preferences.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Aggiorna avatar URL
  Future<void> updateAvatar(String? avatarUrl) async {
    final uid = _currentUid;
    await _profileRef(uid).update({
      'avatarUrl': avatarUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    });
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
}

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository();
});