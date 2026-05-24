import 'package:flutter/foundation.dart';

enum AiCoachMode { training, x01, cricket }

@immutable
class AiCoachSignal {
  final String label;
  final double value;
  final String unit;
  final bool higherIsBetter;
  final String category;

  const AiCoachSignal({
    required this.label,
    required this.value,
    required this.unit,
    required this.higherIsBetter,
    required this.category,
  });

  double get normalizedScore {
    final isScale10 = unit.trim().toLowerCase() == 'su 10';
    final bounded = isScale10
        ? (value.clamp(0, 10).toDouble() * 10)
        : value.clamp(0, 100).toDouble();

    return higherIsBetter ? bounded : 100 - bounded;
  }
}

@immutable
class AiCoachSessionSnapshot {
  final String sessionId;
  final String label;
  final DateTime date;
  final String target;
  final String group; // top | worst
  final double score0to100;
  final Map<String, double> metrics;
  final Map<String, double> feedback;

  const AiCoachSessionSnapshot({
    required this.sessionId,
    required this.label,
    required this.date,
    required this.target,
    required this.group,
    required this.score0to100,
    required this.metrics,
    required this.feedback,
  });

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'label': label,
      'date': date.toIso8601String(),
      'target': target,
      'group': group,
      'score0to100': score0to100,
      'metrics': metrics,
      'feedback': feedback,
    };
  }
}

@immutable
class AiCoachInput {
  final AiCoachMode mode;
  final String title;
  final String subtitle;
  final String fingerprint;
  final List<AiCoachSignal> signals;
  final List<AiCoachSessionSnapshot> sessionSnapshots;
  final DateTime updatedAt;

  const AiCoachInput({
    required this.mode,
    required this.title,
    required this.subtitle,
    required this.fingerprint,
    required this.signals,
    this.sessionSnapshots = const [],
    required this.updatedAt,
  });

  String? get validationError {
    if (fingerprint.trim().isEmpty) return 'Fingerprint dati mancante.';
    if (signals.isEmpty) return 'Dati insufficienti per generare un consiglio.';
    return null;
  }

  bool get isValid => validationError == null;
}

@immutable
class AiCoachAdvice {
  final String summary;
  final String mainIssue;
  final List<String> technicalAdvice;
  final String nextDrill;
  final double confidence;
  final String sourceFingerprint;
  final DateTime generatedAt;

  const AiCoachAdvice({
    required this.summary,
    required this.mainIssue,
    required this.technicalAdvice,
    required this.nextDrill,
    required this.confidence,
    required this.sourceFingerprint,
    required this.generatedAt,
  });

  bool isFreshFor(AiCoachInput input) {
    return sourceFingerprint == input.fingerprint;
  }
}