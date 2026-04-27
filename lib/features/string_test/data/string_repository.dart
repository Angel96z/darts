// TARGET: Repository per salvare/leggere una stringa su Firestore
// LOGIC GOAL: Solo operazioni CRUD (Create, Read, Update, Delete)
// ERROR STRATEGIA: Restituisce Result<T, StringFailure>
// ANTI-REGRESSION: Gestire tutti i casi di errore

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:darts/features/string_test/domain/string_entity.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 🔥 Result pattern (semplice)
sealed class Result<T, E> {
  const Result();
  factory Result.success(T value) = Success<T, E>;
  factory Result.failure(E error) = Failure<T, E>;

  bool get isSuccess => this is Success<T, E>;
  bool get isFailure => this is Failure<T, E>;
}

class Success<T, E> extends Result<T, E> {
  final T value;
  const Success(this.value);
}

class Failure<T, E> extends Result<T, E> {
  final E error;
  const Failure(this.error);
}

class StringRepository {
  final FirebaseFirestore _db;
  static const String _collection = 'string_test';

  StringRepository(this._db);

  // CREA: Salva una nuova stringa su Firestore
  Future<Result<StringEntity, StringFailure>> create(StringEntity entity) async {
    try {
      final docRef = _db.collection(_collection).doc();
      final newEntity = entity.copyWith(id: docRef.id);
      await docRef.set(newEntity.toMap());
      return Success(newEntity);
    } catch (e) {
      return Failure(NetworkFailure());
    }
  }

  // LEGGI: Recupera una stringa da Firestore
  Future<Result<StringEntity, StringFailure>> read(String id) async {
    try {
      final doc = await _db.collection(_collection).doc(id).get();
      if (!doc.exists) return Failure(DocumentNotFoundFailure());
      final data = doc.data();
      if (data == null) return Failure(DocumentNotFoundFailure());
      return Success(StringEntity.fromFirestore(doc.id, data));
    } catch (e) {
      return Failure(NetworkFailure());
    }
  }

  // AGGIORNA: Modifica una stringa esistente
  Future<Result<StringEntity, StringFailure>> update(StringEntity entity) async {
    if (entity.id == null) return Failure(DocumentNotFoundFailure());
    try {
      await _db.collection(_collection).doc(entity.id).set(entity.toMap());
      return Success(entity);
    } catch (e) {
      return Failure(NetworkFailure());
    }
  }

  // ELIMINA: Cancella una stringa
  Future<Result<void, StringFailure>> delete(String id) async {
    try {
      await _db.collection(_collection).doc(id).delete();
      return const Success(null);
    } catch (e) {
      return Failure(NetworkFailure());
    }
  }

  // STREAM: Ascolta i cambiamenti in tempo reale
  Stream<StringEntity?> watch(String id) {
    return _db.collection(_collection).doc(id).snapshots().map((doc) {
      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null) return null;
      return StringEntity.fromFirestore(doc.id, data);
    });
  }
}

// Provider per il repository
final stringRepositoryProvider = Provider<StringRepository>((ref) {
  return StringRepository(FirebaseFirestore.instance);
});