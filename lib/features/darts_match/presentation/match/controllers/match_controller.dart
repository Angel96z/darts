import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/match.dart';

class MatchViewModel {
  const MatchViewModel({required this.snapshot});
  final MatchStateSnapshot snapshot;
}

class MatchController extends StateNotifier<MatchViewModel?> {
  MatchController() : super(null);

  void bind(MatchStateSnapshot snapshot) {
    state = MatchViewModel(snapshot: snapshot);
  }
}

final matchControllerProvider = StateNotifierProvider<MatchController, MatchViewModel?>((ref) => MatchController());
