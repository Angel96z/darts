import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ai_coach_repository.dart';
import '../domain/ai_coach_models.dart';

enum AiCoachStatus { idle, loading, success, error }

@immutable
class AiCoachState {
  final AiCoachStatus status;
  final AiCoachAdvice? advice;
  final String? errorMessage;
  final DateTime updatedAt;

  const AiCoachState({
    this.status = AiCoachStatus.idle,
    this.advice,
    this.errorMessage,
    required this.updatedAt,
  });

  factory AiCoachState.initial() {
    return AiCoachState(updatedAt: DateTime.now());
  }

  bool hasFreshAdviceFor(AiCoachInput input) {
    return advice?.isFreshFor(input) ?? false;
  }

  AiCoachState copyWith({
    AiCoachStatus? status,
    AiCoachAdvice? advice,
    String? errorMessage,
    DateTime? updatedAt,
  }) {
    return AiCoachState(
      status: status ?? this.status,
      advice: advice ?? this.advice,
      errorMessage: errorMessage,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}

final aiCoachRepositoryProvider = Provider<AiCoachRepository>((ref) {
  // Sostituito LocalAiCoachRepository con il nuovo repository basato su Gemini
  return const RemoteGeminiAiCoachRepository();
});

final aiCoachControllerProvider = StateNotifierProvider.autoDispose
    .family<AiCoachController, AiCoachState, String>((ref, scopeId) {
  final repository = ref.watch(aiCoachRepositoryProvider);
  return AiCoachController(repository);
});

class AiCoachController extends StateNotifier<AiCoachState> {
  final AiCoachRepository _repository;

  AiCoachController(this._repository) : super(AiCoachState.initial());

  Future<void> generate(AiCoachInput input) async {
    final error = input.validationError;
    if (error != null) {
      state = state.copyWith(
        status: AiCoachStatus.error,
        errorMessage: error,
      );
      return;
    }

    state = state.copyWith(
      status: AiCoachStatus.loading,
      errorMessage: null,
    );

    final result = await _repository.generateAdvice(input);

    switch (result) {
      case AiCoachSuccess<AiCoachAdvice>():
        state = state.copyWith(
          status: AiCoachStatus.success,
          advice: result.value,
          errorMessage: null,
        );
      case AiCoachFailure<AiCoachAdvice>():
        state = state.copyWith(
          status: AiCoachStatus.error,
          errorMessage: result.message,
        );
    }
  }

  void clear() {
    state = AiCoachState.initial();
  }
}