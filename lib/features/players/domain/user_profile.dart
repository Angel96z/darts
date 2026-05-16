/// File: user_profile.dart
/// TARGET: Modello utente immutabile con profilo esteso (nome, cognome, nickname, statistiche aggregate)
/// LOGIC GOAL: Gestire dati profilo utente con copyWith, getter calcolati e metodi di serializzazione
/// REACTION: UI reagisce a cambiamenti di nome, nickname, statistiche
/// ERROR STRATEGY: Campi opzionali con fallback safe, nickname fallback a firstName se vuoto
/// ANTI-REGRESSION: Mantenere compatibilità con sistema auth esistente, nessuna modifica a FirebaseAuth

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// ========== AVATAR SYSTEM ==========
// Aggiungi questa enum e modifica UserProfile

enum AvatarId {
  avatar1(1, 'assets/avatars/avatar_1.png'),
  avatar2(2, 'assets/avatars/avatar_2.png'),
  avatar3(3, 'assets/avatars/avatar_3.png'),
  avatar4(4, 'assets/avatars/avatar_4.png'),
  avatar5(5, 'assets/avatars/avatar_5.png'),
  avatar6(6, 'assets/avatars/avatar_6.png'),
  avatar7(7, 'assets/avatars/avatar_7.png'),
  avatar8(8, 'assets/avatars/avatar_8.png');

  final int id;
  final String assetPath;

  const AvatarId(this.id, this.assetPath);

  static AvatarId fromId(int? id) {
    return values.firstWhere(
          (a) => a.id == id,
      orElse: () => avatar1,
    );
  }

  static List<AvatarId> get all => values;
}

@immutable
class UserProfile {
  final String uid;
  final String email;
  final String firstName;
  final String lastName;
  final String nickname;

  final DateTime createdAt;
  final DateTime updatedAt;
  final String? avatarUrl;
  final UserPreferences preferences;
  final UserAggregatedStats stats;
  final int? avatarId;

  const UserProfile({
    required this.uid,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.nickname,
    required this.createdAt,
    required this.updatedAt,
    this.avatarUrl,
    this.avatarId,
    this.preferences = const UserPreferences(),
    this.stats = const UserAggregatedStats(),
  });

  // ========== GETTER CALCOLATI ==========
  // GETTER per avatar
  String get avatarAssetPath {
    return AvatarId.fromId(avatarId).assetPath;
  }

  bool get hasCustomAvatar => avatarId != null;

  String get fullName => '$firstName $lastName';

  String get displayName {
    // 1. Priorità massima al nickname (scelto dall'utente)
    if (nickname.trim().isNotEmpty) return nickname.trim();
    // 2. Fallback al nome se presente
    if (firstName.trim().isNotEmpty) return firstName.trim();
    // 3. Fallback alla parte prima della @ nell'email
    final emailLocal = email.trim();
    if (emailLocal.isNotEmpty && emailLocal.contains('@')) {
      return emailLocal.split('@').first;
    }
    // 4. Fallback estremo: solo 'Utente'
    return 'Utente';
  }

  String get initials {
    final first = firstName.isNotEmpty ? firstName[0] : '';
    final last = lastName.isNotEmpty ? lastName[0] : '';
    if (first.isEmpty && last.isEmpty) return email.isNotEmpty ? email[0].toUpperCase() : '?';
    return '$first$last'.toUpperCase();
  }

  bool get hasCompleteProfile => firstName.isNotEmpty && lastName.isNotEmpty && nickname.isNotEmpty;

  // ========== SERIALIZATION ==========

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'nickname': nickname,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'avatarUrl': avatarUrl,
      'preferences': preferences.toMap(),
      'stats': stats.toMap(),
    };
  }

  factory UserProfile.fromMap(String uid, Map<String, dynamic> map) {
    return UserProfile(
      uid: uid,
      email: map['email'] ?? '',
      firstName: map['firstName'] ?? '',
      lastName: map['lastName'] ?? '',
      nickname: map['nickname'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      avatarUrl: map['avatarUrl']?.toString(),
      preferences: UserPreferences.fromMap(map['preferences'] as Map<String, dynamic>? ?? {}),
      stats: UserAggregatedStats.fromMap(map['stats'] as Map<String, dynamic>? ?? {}),
      avatarId: map['avatarId'] as int?,
    );
  }

  UserProfile copyWith({
    String? firstName,
    String? lastName,
    String? nickname,
    String? avatarUrl,
    UserPreferences? preferences,
    UserAggregatedStats? stats,
    DateTime? updatedAt,
    int? avatarId,


  }) {
    return UserProfile(
      uid: uid,
      email: email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      nickname: nickname ?? this.nickname,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      avatarUrl: avatarUrl ?? this.avatarUrl,
      preferences: preferences ?? this.preferences,
      stats: stats ?? this.stats,
      avatarId: avatarId ?? this.avatarId,

    );
  }
}

@immutable
class UserPreferences {
  final ThemeMode themeMode;
  final bool notificationsEnabled;
  final bool soundEffectsEnabled;
  final bool hapticFeedbackEnabled;
  final int? avatarId;

  const UserPreferences({
    this.themeMode = ThemeMode.system,
    this.notificationsEnabled = true,
    this.soundEffectsEnabled = true,
    this.hapticFeedbackEnabled = true,
    this.avatarId,
  });

  Map<String, dynamic> toMap() {
    return {
      'themeMode': themeMode.index,
      'notificationsEnabled': notificationsEnabled,
      'soundEffectsEnabled': soundEffectsEnabled,
      'hapticFeedbackEnabled': hapticFeedbackEnabled,
      'avatarId': avatarId,
    };
  }

  factory UserPreferences.fromMap(Map<String, dynamic> map) {
    return UserPreferences(
      themeMode: ThemeMode.values[map['themeMode'] ?? 0],
      notificationsEnabled: map['notificationsEnabled'] ?? true,
      soundEffectsEnabled: map['soundEffectsEnabled'] ?? true,
      hapticFeedbackEnabled: map['hapticFeedbackEnabled'] ?? true,
    );
  }

  UserPreferences copyWith({
    ThemeMode? themeMode,
    bool? notificationsEnabled,
    bool? soundEffectsEnabled,
    bool? hapticFeedbackEnabled,
  }) {
    return UserPreferences(
      themeMode: themeMode ?? this.themeMode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      soundEffectsEnabled: soundEffectsEnabled ?? this.soundEffectsEnabled,
      hapticFeedbackEnabled: hapticFeedbackEnabled ?? this.hapticFeedbackEnabled,
    );
  }
}

@immutable
class UserAggregatedStats {
  final int totalMatches;
  final int totalMatchesWon;
  final int totalTrainingSessions;
  final int totalTrainingThrows;
  final double bestX01Average;
  final int bestLegDarts;  // 🔥 NUOVO: minimo dardi per chiudere una partita
  final double bestCricketMPR;
  final int total180s;
  final int total140s;
  final int total100s;
  final int totalCheckouts;
  final int bestCheckout;
  final DateTime? lastMatchDate;
  final DateTime? lastTrainingDate;

  const UserAggregatedStats({
    this.totalMatches = 0,
    this.totalMatchesWon = 0,
    this.totalTrainingSessions = 0,
    this.totalTrainingThrows = 0,
    this.bestX01Average = 0.0,
    this.bestLegDarts = 999,  // 🔥 Default alto, minimo sarà 9 (con 3 dardi per turno)
    this.bestCricketMPR = 0.0,
    this.total180s = 0,
    this.total140s = 0,
    this.total100s = 0,
    this.totalCheckouts = 0,
    this.bestCheckout = 0,
    this.lastMatchDate,
    this.lastTrainingDate,
  });

  double get winRate => totalMatches > 0 ? (totalMatchesWon / totalMatches) * 100 : 0.0;

  Map<String, dynamic> toMap() {
    return {
      'totalMatches': totalMatches,
      'totalMatchesWon': totalMatchesWon,
      'totalTrainingSessions': totalTrainingSessions,
      'totalTrainingThrows': totalTrainingThrows,
      'bestX01Average': bestX01Average,
      'bestLegDarts': bestLegDarts,
      'bestCricketMPR': bestCricketMPR,
      'total180s': total180s,
      'total140s': total140s,
      'total100s': total100s,
      'totalCheckouts': totalCheckouts,
      'bestCheckout': bestCheckout,
      'lastMatchDate': lastMatchDate != null ? Timestamp.fromDate(lastMatchDate!) : null,
      'lastTrainingDate': lastTrainingDate != null ? Timestamp.fromDate(lastTrainingDate!) : null,
    };
  }

  factory UserAggregatedStats.fromMap(Map<String, dynamic> map) {
    return UserAggregatedStats(
      totalMatches: map['totalMatches'] ?? 0,
      totalMatchesWon: map['totalMatchesWon'] ?? 0,
      totalTrainingSessions: map['totalTrainingSessions'] ?? 0,
      totalTrainingThrows: map['totalTrainingThrows'] ?? 0,
      bestX01Average: (map['bestX01Average'] ?? 0.0).toDouble(),
      bestLegDarts: map['bestLegDarts'] ?? 999,
      bestCricketMPR: (map['bestCricketMPR'] ?? 0.0).toDouble(),
      total180s: map['total180s'] ?? 0,
      total140s: map['total140s'] ?? 0,
      total100s: map['total100s'] ?? 0,
      totalCheckouts: map['totalCheckouts'] ?? 0,
      bestCheckout: map['bestCheckout'] ?? 0,
      lastMatchDate: (map['lastMatchDate'] as Timestamp?)?.toDate(),
      lastTrainingDate: (map['lastTrainingDate'] as Timestamp?)?.toDate(),
    );
  }

  UserAggregatedStats copyWith({
    int? totalMatches,
    int? totalMatchesWon,
    int? totalTrainingSessions,
    int? totalTrainingThrows,
    double? bestX01Average,
    int? bestLegDarts,
    double? bestCricketMPR,
    int? total180s,
    int? total140s,
    int? total100s,
    int? totalCheckouts,
    int? bestCheckout,
    DateTime? lastMatchDate,
    DateTime? lastTrainingDate,
  }) {
    return UserAggregatedStats(
      totalMatches: totalMatches ?? this.totalMatches,
      totalMatchesWon: totalMatchesWon ?? this.totalMatchesWon,
      totalTrainingSessions: totalTrainingSessions ?? this.totalTrainingSessions,
      totalTrainingThrows: totalTrainingThrows ?? this.totalTrainingThrows,
      bestX01Average: bestX01Average ?? this.bestX01Average,
      bestLegDarts: bestLegDarts ?? this.bestLegDarts,
      bestCricketMPR: bestCricketMPR ?? this.bestCricketMPR,
      total180s: total180s ?? this.total180s,
      total140s: total140s ?? this.total140s,
      total100s: total100s ?? this.total100s,
      totalCheckouts: totalCheckouts ?? this.totalCheckouts,
      bestCheckout: bestCheckout ?? this.bestCheckout,
      lastMatchDate: lastMatchDate ?? this.lastMatchDate,
      lastTrainingDate: lastTrainingDate ?? this.lastTrainingDate,
    );
  }
}