// TARGET: StateNotifier per gestire la stringa
// LOGIC GOAL: Coordinare operazioni CRUD e stream
// REACTION: UI reagisce con loading/success/error
// ERROR STRATEGY: Messaggi di errore visibili all'utente
// ANTI-REGRESSION: Gestire stream e cleanup

import 'dart:async';
import 'package:darts/features/string_test/data/string_repository.dart';
import 'package:darts/features/string_test/domain/string_entity.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum StringStatus { initial, loading, success, error }

@immutable
class StringState {
  final StringEntity? entity;
  final StringStatus status;
  final String? errorMessage;
  final String? currentId;

  const StringState({
    this.entity,
    this.status = StringStatus.initial,
    this.errorMessage,
    this.currentId,
  });

  StringState copyWith({
    StringEntity? entity,
    StringStatus? status,
    String? errorMessage,
    String? currentId,
  }) {
    return StringState(
      entity: entity ?? this.entity,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      currentId: currentId ?? this.currentId,
    );
  }
}

class StringNotifier extends StateNotifier<StringState> {
  final StringRepository _repo;
  StreamSubscription<StringEntity?>? _subscription;

  StringNotifier(this._repo) : super(const StringState());

  void _listenToDocument(String id) {
    _subscription?.cancel();
    _subscription = _repo.watch(id).listen(
          (entity) {
        if (entity != null) {
          state = state.copyWith(
            entity: entity,
            status: StringStatus.success,
            errorMessage: null,
          );
        } else {
          state = state.copyWith(
            status: StringStatus.error,
            errorMessage: 'Documento non trovato',
          );
        }
      },
      onError: (e) {
        state = state.copyWith(
          status: StringStatus.error,
          errorMessage: 'Errore stream: $e',
        );
      },
    );
  }

  // Crea un nuovo documento
  Future<void> create(String value) async {
    state = state.copyWith(status: StringStatus.loading);

    final result = await _repo.create(StringEntity.create(value));

    if (result.isSuccess) {
      final entity = (result as Success<StringEntity, StringFailure>).value;
      state = state.copyWith(
        entity: entity,
        currentId: entity.id,
        status: StringStatus.success,
      );
      _listenToDocument(entity.id!);
    } else {
      final failure = (result as Failure<StringEntity, StringFailure>).error;
      state = state.copyWith(
        status: StringStatus.error,
        errorMessage: failure.message,
      );
    }
  }

  // Carica un documento esistente
  Future<void> load(String id) async {
    if (id.isEmpty) return;

    state = state.copyWith(status: StringStatus.loading);

    final result = await _repo.read(id);

    if (result.isSuccess) {
      final entity = (result as Success<StringEntity, StringFailure>).value;
      state = state.copyWith(
        entity: entity,
        currentId: entity.id,
        status: StringStatus.success,
      );
      _listenToDocument(entity.id!);
    } else {
      final failure = (result as Failure<StringEntity, StringFailure>).error;
      state = state.copyWith(
        status: StringStatus.error,
        errorMessage: failure.message,
      );
    }
  }

  // Aggiorna la stringa
  Future<void> update(String newValue) async {
    final current = state.entity;
    if (current == null || current.id == null) return;

    state = state.copyWith(status: StringStatus.loading);

    final updated = current.copyWith(value: newValue, updatedAt: DateTime.now());
    final result = await _repo.update(updated);

    if (result.isSuccess) {
      // Lo stream aggiornerà lo stato
      state = state.copyWith(status: StringStatus.success);
    } else {
      final failure = (result as Failure<StringEntity, StringFailure>).error;
      state = state.copyWith(
        status: StringStatus.error,
        errorMessage: failure.message,
      );
    }
  }

  // Elimina il documento
  Future<void> delete() async {
    final id = state.currentId;
    if (id == null || id.isEmpty) return;

    state = state.copyWith(status: StringStatus.loading);

    final result = await _repo.delete(id);

    if (result.isSuccess) {
      _subscription?.cancel();
      state = const StringState(
        entity: null,
        currentId: null,
        status: StringStatus.success,
      );
    } else {
      final failure = (result as Failure<void, StringFailure>).error;
      state = state.copyWith(
        status: StringStatus.error,
        errorMessage: failure.message,
      );
    }
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final stringNotifierProvider = StateNotifierProvider<StringNotifier, StringState>((ref) {
  final repo = ref.watch(stringRepositoryProvider);
  return StringNotifier(repo);
});