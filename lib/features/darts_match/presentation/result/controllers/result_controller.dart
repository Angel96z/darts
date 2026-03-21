import 'package:flutter_riverpod/flutter_riverpod.dart';

class ResultVm {
  const ResultVm({required this.winnerId, required this.highestScore, required this.average});

  final String winnerId;
  final int highestScore;
  final int average;
}

class ResultController extends StateNotifier<ResultVm?> {
  ResultController() : super(null);

  void setResult({required String winnerId, required int highestScore, required int average}) {
    state = ResultVm(winnerId: winnerId, highestScore: highestScore, average: average);
  }
}

final resultControllerProvider = StateNotifierProvider<ResultController, ResultVm?>((ref) => ResultController());
