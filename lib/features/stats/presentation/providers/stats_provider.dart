import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/services/stats_aggregator_service.dart';

// Provider per statistiche X01 (da implementare dopo)
final x01StatsProvider = FutureProvider((ref) async {
  // TODO: implementare recupero statistiche X01
  return null;
});

// Provider per statistiche Cricket (da implementare dopo)
final cricketStatsProvider = FutureProvider((ref) async {
  // TODO: implementare recupero statistiche Cricket
  return null;
});

final statsAggregatorServiceProvider = Provider<StatsAggregatorService>((ref) {
  return StatsAggregatorService.instance;
});