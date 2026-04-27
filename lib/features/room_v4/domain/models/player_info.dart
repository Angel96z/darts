// TARGET: Informazioni del giocatore
// LOGIC GOAL: Tracciare nome, ordine, tipo
// REACTION: UI mostra nome e badge guest
// ERROR STRATEGY: N/A

import 'package:flutter/foundation.dart';

@immutable
class PlayerInfo {
  final String id;
  final String name;
  final bool isGuest;
  final int order;

  const PlayerInfo({
    required this.id,
    required this.name,
    required this.isGuest,
    required this.order,
  });

  PlayerInfo copyWith({
    String? id,
    String? name,
    bool? isGuest,
    int? order,
  }) {
    return PlayerInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      isGuest: isGuest ?? this.isGuest,
      order: order ?? this.order,
    );
  }
}