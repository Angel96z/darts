// lib/features/room_v4/bot/bot_level.dart
import 'dart:math';

enum BotLevel {
  beginner('Principiante', 25, 40, 2, 8, 0.10, 40),
  casual('Amatoriale', 40, 55, 8, 15, 0.20, 60),
  intermediate('Intermedio', 55, 70, 15, 25, 0.35, 100),
  advanced('Avanzato', 70, 85, 25, 35, 0.50, 140),
  expert('Esperto', 85, 100, 35, 45, 0.65, 170);

  final String displayName;
  final int avgMin;
  final int avgMax;
  final int checkoutMin;
  final int checkoutMax;
  final double doublesAccuracy;
  final int maxCheckout;

  const BotLevel(
      this.displayName,
      this.avgMin,
      this.avgMax,
      this.checkoutMin,
      this.checkoutMax,
      this.doublesAccuracy,
      this.maxCheckout,
      );

  /// Restituisce una media casuale nel range
  double getRandomAverage() {
    final random = Random();
    return avgMin + random.nextDouble() * (avgMax - avgMin);
  }

  /// Restituisce la percentuale di checkout per un punteggio
  double getCheckoutChance(int score) {
    if (score > maxCheckout) return 0.0;

    final random = Random();
    final baseChancePercent = checkoutMin + random.nextDouble() * (checkoutMax - checkoutMin);
    double finalChance = baseChancePercent / 100;

    // Penalità per checkout alti
    if (score > 100) {
      finalChance *= 0.3;
    } else if (score > 60) {
      finalChance *= 0.6;
    } else if (score > 40) {
      finalChance *= 0.8;
    }

    return finalChance.clamp(0.01, 0.90);
  }

  /// Restituisce la probabilità di colpire un doppio specifico
  double getDoubleAccuracyForScore(int score) {
    double base = doublesAccuracy;
    if (score == 32 || score == 40) { // D16 e D20 più facili
      base *= 1.1;
    } else if (score == 50) { // Bull più difficile
      base *= 0.8;
    }
    return base.clamp(0.05, 0.85);
  }

  static BotLevel fromIndex(int index) {
    return values[index % values.length];
  }
}