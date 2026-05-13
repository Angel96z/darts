// lib/features/room_v4/bot/bot_level.dart
enum BotLevel {
  beginner('Principiante', 35.0, 5.0, 0.15),   // media, checkout%, doubles accuracy
  casual('Casuale', 45.0, 12.0, 0.30),
  intermediate('Intermedio', 55.0, 20.0, 0.50),
  advanced('Avanzato', 65.0, 28.0, 0.65),
  expert('Esperto', 75.0, 35.0, 0.80);

  final String displayName;
  final double average;           // Media su 3 dardi (es: 35, 45, 55...)
  final double checkoutPercentage; // % di successo checkout
  final double doublesAccuracy;    // Precisione sui double (0-1)

  const BotLevel(this.displayName, this.average, this.checkoutPercentage, this.doublesAccuracy);

  static BotLevel fromIndex(int index) {
    return values[index % values.length];
  }

  /// Calcola la probabilità di fare un checkout basata sul livello
  double getCheckoutChance(int score) {
    // Più basso è il double, più è probabile
    // D16 (32) è più facile di D20 (40) o D18 (36)
    double baseChance = checkoutPercentage / 100;

    // Penalità per double alti
    if (score > 40) return baseChance * 0.4;
    if (score > 32) return baseChance * 0.7;
    if (score > 16) return baseChance * 0.85;
    return baseChance;
  }
}