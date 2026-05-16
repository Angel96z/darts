import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../data/string_repository.dart';
import '../domain/string_entity.dart';

part 'string_notifier.g.dart';

@riverpod
class StringController extends _$StringController {
  StreamSubscription? _sub;

  @override
  FutureOr<StringEntity?> build() {
    ref.onDispose(() => _sub?.cancel());
    return null;
  }

  void watch(String id) {
    if (id.isEmpty) return;
    state = const AsyncLoading();
    _sub?.cancel();
    _sub = ref.read(stringRepositoryProvider).watch(id).listen(
          (data) => state = AsyncData(data),
      onError: (e, st) => state = AsyncError(e, st),
    );
  }

// Immaginiamo di voler mantenere il dato precedente anche se c'è un errore
  Future<void> updateValue(String newValue) async {
    final currentEntity = state.value;
    if (currentEntity == null) return;

    final updated = currentEntity.copyWith(value: newValue);

    if (!updated.isValid) {
      // SETTIAMO UN ERRORE MA NON USIAMO AsyncError!
      // Usiamo una variabile locale o un Side Effect per la UI.
      // Oppure, più semplicemente, passiamo l'errore alla UI tramite lo stato
      state = AsyncData(updated); // Il dato è "sporco" ma lo stato è vivo
      return;
    }

    // Se è valido, salviamo su Firestore
    await ref.read(stringRepositoryProvider).update(updated);
  }


  Future<void> create(String val) async {
    state = const AsyncLoading();
    final res = await ref.read(stringRepositoryProvider).create(StringEntity.create(val));
    if (res is Success<StringEntity>) {
      watch(res.value.id!);
    } else if (res is Failure<StringEntity>) {
      state = AsyncError(res.error.message, StackTrace.current);
    }
  }


  Future<void> delete() async {
    final id = state.value?.id;
    if (id == null) return;
    final res = await ref.read(stringRepositoryProvider).delete(id);
    if (res is Success) {
      _sub?.cancel();
      state = const AsyncData(null);
    }
  }


}

class StringState {
  final StringEntity? entity;
  final String? validationError; // L'errore "locale" di digitazione
  final bool isUpdating;

  StringState({this.entity, this.validationError, this.isUpdating = false});
}