/// File: user_notifier.dart
/// TARGET: StateNotifier per gestione stato utente con AppStatus
/// LOGIC GOAL: Coordinare fetch, update, e operazioni asincrone sul profilo
/// REACTION: UI reagisce a loading, success, error tramite enum AppStatus
/// ERROR STRATEGY: Stato error con Failure tipizzata
/// ANTI-REGRESSION: Mantenere login/logout esistente, aggiungere gestione profilo

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/failure.dart';
import '../../players/domain/user_profile.dart';
import '../../players/data/user_repository.dart';

enum AppStatus { idle, loading, success, error }

@immutable
class UserState {
  final UserProfile? profile;
  final AppStatus status;
  final Failure? failure;

  const UserState({
    this.profile,
    this.status = AppStatus.idle,
    this.failure,
  });

  bool get isLoading => status == AppStatus.loading;
  bool get hasError => status == AppStatus.error;
  bool get isAuthenticated => FirebaseAuth.instance.currentUser != null;

  String get displayName {
    if (profile != null) return profile!.displayName;

    final email = FirebaseAuth.instance.currentUser?.email?.trim() ?? '';
    if (email.isNotEmpty) return email.split('@').first;

    return 'Ospite';
  }

  String get initials {
    if (profile != null) return profile!.initials;

    final email = FirebaseAuth.instance.currentUser?.email?.trim() ?? '';
    if (email.isNotEmpty) return email[0].toUpperCase();

    return '?';
  }

  String get fullName => profile?.fullName ?? displayName;

  UserState copyWith({
    UserProfile? profile,
    AppStatus? status,
    Failure? failure,
  }) {
    return UserState(
      profile: profile ?? this.profile,
      status: status ?? this.status,
      failure: failure ?? this.failure,
    );
  }
}

class UserNotifier extends StateNotifier<UserState> {
  final UserRepository _repository;
  StreamSubscription<UserProfile>? _profileSubscription;

  UserNotifier(this._repository) : super(const UserState());

  /// Carica profilo utente corrente
  /// Carica profilo utente corrente e ascolta cambiamenti in tempo reale
  Future<void> loadProfile() async {
    if (state.isLoading) return;

    state = state.copyWith(status: AppStatus.loading, failure: null);

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      state = state.copyWith(status: AppStatus.error, failure: const AuthFailure(message: 'Utente non autenticato'));
      return;
    }

    try {
      // 1. Prima lettura singola
      final profile = await _repository.fetchOrCreateProfile();
      state = state.copyWith(profile: profile, status: AppStatus.success);

      // 2. Poi ascolta gli aggiornamenti in tempo reale
      _profileSubscription?.cancel();
      _profileSubscription = _repository.watchProfile(uid).listen(
            (updatedProfile) {
          if (mounted) {
            state = state.copyWith(profile: updatedProfile);
            debugPrint('📡 Profilo aggiornato in tempo reale: ${updatedProfile.displayName}');
          }
        },
        onError: (error) {
          debugPrint('❌ Errore stream profilo: $error');
        },
      );
    } catch (e) {
      final failure = e is Failure ? e : ProfileNotFoundFailure(technicalDetails: e.toString());
      state = state.copyWith(status: AppStatus.error, failure: failure);
    }
  }

  Future<void> updateProfileInfo({
    required String firstName,
    required String lastName,
    required String nickname,
  }) async {
    if (state.isLoading) return;

    state = state.copyWith(status: AppStatus.loading, failure: null);

    try {
      final currentProfile = state.profile ?? await _repository.fetchOrCreateProfile();

      await _repository.updateProfileInfo(
        firstName: firstName,
        lastName: lastName,
        nickname: nickname,
      );

      final updatedProfile = currentProfile.copyWith(
        firstName: firstName,
        lastName: lastName,
        nickname: nickname,
        updatedAt: DateTime.now(),
      );

      state = state.copyWith(profile: updatedProfile, status: AppStatus.success);
    } catch (e) {
      final failure = e is Failure ? e : ProfileSaveFailure(technicalDetails: e.toString());
      state = state.copyWith(status: AppStatus.error, failure: failure);
    }
  }

  /// Aggiorna preferenze
  Future<void> updatePreferences(UserPreferences preferences) async {
    if (state.isLoading) return;

    state = state.copyWith(status: AppStatus.loading, failure: null);

    try {
      await _repository.updatePreferences(preferences);

      final updatedProfile = state.profile?.copyWith(preferences: preferences);

      state = state.copyWith(profile: updatedProfile, status: AppStatus.success);
    } catch (e) {
      final failure = e is Failure ? e : ProfileSaveFailure(technicalDetails: e.toString());
      state = state.copyWith(status: AppStatus.error, failure: failure);
    }
  }

  /// Aggiorna avatar
  Future<void> updateAvatar(String? avatarUrl) async {
    if (state.isLoading) return;

    state = state.copyWith(status: AppStatus.loading, failure: null);

    try {
      await _repository.updateAvatar(avatarUrl);

      final updatedProfile = state.profile?.copyWith(avatarUrl: avatarUrl);

      state = state.copyWith(profile: updatedProfile, status: AppStatus.success);
    } catch (e) {
      final failure = e is Failure ? e : ProfileSaveFailure(technicalDetails: e.toString());
      state = state.copyWith(status: AppStatus.error, failure: failure);
    }
  }

  /// Aggiorna statistiche aggregate
  Future<void> updateAggregatedStats(UserAggregatedStats stats) async {
    try {
      await _repository.updateAggregatedStats(stats);

      final updatedProfile = state.profile?.copyWith(stats: stats);

      state = state.copyWith(profile: updatedProfile);
    } catch (e) {
      // Silenzioso - non bloccare UI per stats update fallito
      debugPrint('Errore aggiornamento stats: $e');
    }
  }

  /// Reset error state
  void clearError() {
    if (state.hasError) {
      state = state.copyWith(status: AppStatus.idle, failure: null);
    }
  }

  /// Logout - resetta stato
  void reset() {
    state = const UserState();
  }

  // Aggiungi questi metodi alla classe UserNotifier

  /// Elimina account
  Future<void> deleteAccount() async {
    if (state.isLoading) return;

    state = state.copyWith(status: AppStatus.loading, failure: null);

    try {
      await _repository.deleteAccount();
      state = const UserState(); // Reset completo
    } catch (e) {
      final failure = e is Failure ? e : ProfileSaveFailure(technicalDetails: e.toString());
      state = state.copyWith(status: AppStatus.error, failure: failure);
    }
  }

  /// Aggiorna avatar
  Future<void> updateAvatarId(int? avatarId) async {
    if (state.isLoading) return;

    state = state.copyWith(status: AppStatus.loading, failure: null);

    try {
      await _repository.updateAvatarId(avatarId);

      final updatedProfile = state.profile?.copyWith(avatarId: avatarId);
      state = state.copyWith(profile: updatedProfile, status: AppStatus.success);
    } catch (e) {
      final failure = e is Failure ? e : ProfileSaveFailure(technicalDetails: e.toString());
      state = state.copyWith(status: AppStatus.error, failure: failure);
    }
  }

  /// Invia verifica email
  Future<void> sendVerificationEmail() async {
    if (state.isLoading) return;

    state = state.copyWith(status: AppStatus.loading, failure: null);

    try {
      await _repository.sendEmailVerification();
      state = state.copyWith(status: AppStatus.success);
    } catch (e) {
      final failure = e is Failure ? e : ProfileSaveFailure(technicalDetails: e.toString());
      state = state.copyWith(status: AppStatus.error, failure: failure);
    }
  }

  /// Aggiorna stato verifica email
  Future<bool> refreshEmailVerification() async {
    try {
      final isVerified = await _repository.checkEmailVerified();
      if (isVerified && state.profile != null) {
        // Ricarica profilo se appena verificato
        await loadProfile();
      }
      return isVerified;
    } catch (e) {
      return false;
    }
  }

  /// Cambia password
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (state.isLoading) return;

    state = state.copyWith(status: AppStatus.loading, failure: null);

    try {
      await _repository.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      state = state.copyWith(status: AppStatus.success);
    } catch (e) {
      final failure = e is Failure ? e : AuthFailure(message: e.toString());
      state = state.copyWith(status: AppStatus.error, failure: failure);
    }
  }

  /// Reset password (dimenticata)
  Future<void> resetPassword(String email) async {
    if (state.isLoading) return;

    state = state.copyWith(status: AppStatus.loading, failure: null);

    try {
      await _repository.sendPasswordResetEmail(email);
      state = state.copyWith(status: AppStatus.success);
    } catch (e) {
      final failure = e is Failure ? e : AuthFailure(message: e.toString());
      state = state.copyWith(status: AppStatus.error, failure: failure);
    }
  }

  @override
  void dispose() {
    _profileSubscription?.cancel();
    super.dispose();
  }
}


final userProvider = StateNotifierProvider<UserNotifier, UserState>((ref) {
  final repository = ref.watch(userRepositoryProvider);
  return UserNotifier(repository);
});