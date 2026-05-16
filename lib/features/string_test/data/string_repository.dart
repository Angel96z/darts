import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../domain/string_entity.dart';

part 'string_repository.g.dart';

// Definizione del Result Pattern
sealed class Result<T> {
  const Result();
}
class Success<T> extends Result<T> {
  final T value;
  const Success(this.value);
}
class Failure<T> extends Result<T> {
  final AppFailure error;
  const Failure(this.error);
}

class StringRepository {
  final FirebaseFirestore _db;
  static const String _collection = 'string_test';

  StringRepository(this._db);

  Future<Result<StringEntity>> create(StringEntity entity) async {
    try {
      final docRef = _db.collection(_collection).doc();
      final newEntity = entity.copyWith(id: docRef.id);
      await docRef.set(newEntity.toMap());
      return Success(newEntity);
    } catch (e) {
      return Failure(NetworkFailure(e.toString()));
    }
  }

  Future<Result<void>> update(StringEntity entity) async {
    if (entity.id == null) return Failure(const DocumentNotFoundFailure());
    try {
      await _db.collection(_collection).doc(entity.id).set(entity.toMap());
      return const Success(null);
    } catch (e) {
      return Failure(NetworkFailure(e.toString()));
    }
  }

  Future<Result<void>> delete(String id) async {
    try {
      await _db.collection(_collection).doc(id).delete();
      return const Success(null);
    } catch (e) {
      return Failure(NetworkFailure(e.toString()));
    }
  }

  Stream<StringEntity?> watch(String id) {
    return _db.collection(_collection).doc(id).snapshots().map((doc) {
      final data = doc.data();
      if (!doc.exists || data == null) return null;
      return StringEntity.fromFirestore(doc.id, data);
    });
  }
}

@riverpod
StringRepository stringRepository(StringRepositoryRef ref) {
  return StringRepository(FirebaseFirestore.instance);
}