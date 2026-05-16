import 'package:flutter/foundation.dart';

@immutable
class StringEntity {
  final String? id;
  final String value;
  final DateTime updatedAt;

  const StringEntity({this.id, required this.value, required this.updatedAt});

  // --- LOGICA DI CALCOLO & VALIDAZIONE ---
  int get charCount => value.length;
  bool get containsNumbers => value.contains(RegExp(r'[0-9]'));

  // Validazione: ritorna una stringa di errore o null se è valida
  String? get validationError {
    if (value.isEmpty) return 'Il testo non può essere vuoto';
    if (value.length < 3) return 'Troppo corto (minimo 3 caratteri)';
    if (containsNumbers) return 'I numeri non sono ammessi in questo test';
    return null;
  }

  bool get isValid => validationError == null;

  // Conta le parole
  int get wordCount {
    if (value.trim().isEmpty) return 0;
    return value.trim().split(RegExp(r'\s+')).length;
  }


  // ----------------------------------

  // Crea una nuova istanza (senza ID)
  factory StringEntity.create(String value) => StringEntity(
    value: value,
    updatedAt: DateTime.now(),
  );

  // Mappa da Firestore
  factory StringEntity.fromFirestore(String id, Map<String, dynamic> map) =>
      StringEntity(
        id: id,
        value: map['value'] as String? ?? '',
        updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? '') ??
            DateTime.now(),
      );

  // Mappa per Firestore
  Map<String, dynamic> toMap() => {
    'value': value,
    'updatedAt': updatedAt.toIso8601String(),
  };

  StringEntity copyWith({String? id, String? value, DateTime? updatedAt}) =>
      StringEntity(
        id: id ?? this.id,
        value: value ?? this.value,
        updatedAt: updatedAt ?? this.updatedAt,
      );
} // <--- Chiusura corretta della classe StringEntity

// --- GESTIONE ERRORI ---

abstract class AppFailure {
  final String message;
  const AppFailure(this.message);
}

class NetworkFailure extends AppFailure {
  const NetworkFailure([String? msg]) : super(msg ?? 'Errore di connessione');
}

class DocumentNotFoundFailure extends AppFailure {
  const DocumentNotFoundFailure() : super('Documento non trovato');
}