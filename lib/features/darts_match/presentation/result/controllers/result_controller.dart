import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/match.dart';

class ResultController extends StateNotifier<MatchResult?> {
  ResultController() : super(null);

  void setResult(MatchResult result) => state = result;
}

final resultControllerProvider = StateNotifierProvider<ResultController, MatchResult?>((ref) => ResultController());
