// TARGET: Entità immutabile per una stringa da salvare su Firestore
// LOGIC GOAL: Contiene SOLO la stringa, l'id, e il timestamp
// REACTION: La UI reagisce ai cambiamenti di questi valori
// ERROR STRATEGY: Failure per errori di rete
// ANTI-REGRESSION: Mantenere immutabilità con copyWith

import 'package:flutter/foundation.dart';

@immutable
class StringEntity {
  final String? id;           // ID del documento su Firestore
  final String value;         // LA STRINGA (unica cosa che ci interessa)
  final DateTime updatedAt;   // Quando è stata aggiornata

  const StringEntity({
    this.id,
    required this.value,
    required this.updatedAt,
  });

  // Costruttore per una nuova stringa (senza ID)
  factory StringEntity.create(String value) {
    return StringEntity(
      value: value,
      updatedAt: DateTime.now(),
    );
  }

  // Costruttore per una stringa esistente (con ID)
  factory StringEntity.fromFirestore(String id, Map<String, dynamic> map) {
    return StringEntity(
      id: id,
      value: map['value'] as String? ?? '',
      updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  // copyWith per immutabilità
  StringEntity copyWith({
    String? id,
    String? value,
    DateTime? updatedAt,
  }) {
    return StringEntity(
      id: id ?? this.id,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Converte in Map per Firestore
  Map<String, dynamic> toMap() {
    return {
      'value': value,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

// FAILURE per errori
abstract class StringFailure {
  final String message;
  const StringFailure(this.message);
}

class NetworkFailure extends StringFailure {
  const NetworkFailure() : super('Errore di connessione');
}

class DocumentNotFoundFailure extends StringFailure {
  const DocumentNotFoundFailure() : super('Documento non trovato');
}