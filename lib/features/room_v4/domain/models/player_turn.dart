import 'package:flutter/foundation.dart';
import 'dart_throw.dart';

@immutable
class PlayerTurn {
  final String playerId;
  final int turnNumber;
  final int roundNumber;
  final int legNumber;
  final List<DartThrow> throws;
  final int total;        // X01: somma punteggi, Cricket: 0 (non usato)
  final int totalMarks;   // 🆕 Cricket: somma moltiplicatori, X01: 0
  final int initialScore;
  final int score;
  final bool isBust;
  final bool isCheckout;
  final DateTime timestamp;

  const PlayerTurn({
    required this.playerId,
    required this.turnNumber,
    required this.roundNumber,
    required this.legNumber,
    required this.throws,
    required this.total,
    required this.totalMarks,  // 🆕
    required this.initialScore,
    required this.score,
    required this.isBust,
    required this.isCheckout,
    required this.timestamp,
  });

  int get dartsThrown => throws.length;
  int get remainingThrows => 3 - throws.length;
  bool get isComplete => throws.length >= 3 || isBust || isCheckout;

  Map<String, dynamic> toMap() {
    return {
      'playerId': playerId,
      'turnNumber': turnNumber,
      'roundNumber': roundNumber,
      'legNumber': legNumber,
      'throws': throws.map((d) => d.toMap()).toList(),
      'total': total,
      'totalMarks': totalMarks,  // 🆕
      'initialScore': initialScore,
      'score': score,
      'isBust': isBust,
      'isCheckout': isCheckout,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory PlayerTurn.fromMap(Map<String, dynamic> map) {
    return PlayerTurn(
      playerId: map['playerId'],
      turnNumber: map['turnNumber'],
      roundNumber: map['roundNumber'] ?? 1,
      legNumber: map['legNumber'] ?? 1,
      throws: (map['throws'] as List)
          .map((d) => DartThrow.fromMap(d as Map<String, dynamic>))
          .toList(),
      total: map['total'],
      totalMarks: map['totalMarks'] ?? 0,  // 🆕 fallback per vecchi dati
      initialScore: map['initialScore'],
      score: map['score'],
      isBust: map['isBust'],
      isCheckout: map['isCheckout'],
      timestamp: DateTime.parse(map['timestamp']),
    );
  }

  PlayerTurn copyWith({
    String? playerId,
    int? turnNumber,
    int? roundNumber,
    int? legNumber,
    List<DartThrow>? throws,
    int? total,
    int? totalMarks,  // 🆕
    int? initialScore,
    int? score,
    bool? isBust,
    bool? isCheckout,
    DateTime? timestamp,
  }) {
    return PlayerTurn(
      playerId: playerId ?? this.playerId,
      turnNumber: turnNumber ?? this.turnNumber,
      roundNumber: roundNumber ?? this.roundNumber,
      legNumber: legNumber ?? this.legNumber,
      throws: throws ?? this.throws,
      total: total ?? this.total,
      totalMarks: totalMarks ?? this.totalMarks,  // 🆕
      initialScore: initialScore ?? this.initialScore,
      score: score ?? this.score,
      isBust: isBust ?? this.isBust,
      isCheckout: isCheckout ?? this.isCheckout,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}