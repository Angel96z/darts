// ════════════════════════════════════════════════════════════
//  APP THEME — Design Tokens
//  Uso: final t = AppTokens.of(context);
//       Container(color: t.surface)
//       Text('ciao', style: TextStyle(color: t.textPrimary))
// ════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

/// Token set completo per dark e light mode.
/// Aggiorna i valori qui e tutte le UI si adeguano.
class AppTokens {
  // ── Sfondi ─────────────────────────────────────────────
  final Color bg;           // sfondo pagina
  final Color surface;      // card / pannello primo livello
  final Color surfaceHigh;  // elemento sopra surface (chip, slot)
  final Color overlay;      // modale / dialog

  // ── Bordi e divisori ───────────────────────────────────
  final Color divider;      // linea sottile
  final Color border;       // bordo card neutro

  // ── Testi ──────────────────────────────────────────────
  final Color textPrimary;    // titolo / dato principale
  final Color textSecondary;  // label secondaria
  final Color textMuted;      // placeholder / hint

  // ── Accenti semantici ──────────────────────────────────
  final Color accent;       // azione primaria (amber dark, blue light)
  final Color accentFg;     // testo sopra accent bg
  final Color green;        // OUT / successo
  final Color red;          // BUST / errore
  final Color orange;       // NO OUT / warning
  final Color grey;         // FROZEN / neutro

  const AppTokens._({
    required this.bg,
    required this.surface,
    required this.surfaceHigh,
    required this.overlay,
    required this.divider,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.accentFg,
    required this.green,
    required this.red,
    required this.orange,
    required this.grey,
  });

  // ── Dark ───────────────────────────────────────────────
  static const dark = AppTokens._(
    bg:           Color(0xFF0A0A0A),
    surface:      Color(0xFF141414),
    surfaceHigh:  Color(0xFF1C1C1C),
    overlay:      Color(0xFF1A1A1A),
    divider:      Color(0xFF222222),
    border:       Color(0xFF2A2A2A),
    textPrimary:  Color(0xFFFFFFFF),
    textSecondary:Color(0xFF8A8A8A),
    textMuted:    Color(0xFF7A7A7A),
    accent:       Color(0xFFFBBF24),
    accentFg:     Color(0xFF000000),
    green:        Color(0xFF22C55E),
    red:          Color(0xFFEF4444),
    orange:       Color(0xFFF97316),
    grey:         Color(0xFF6B7280),
  );

  // ── Light ──────────────────────────────────────────────
  static const light = AppTokens._(
    bg:           Color(0xFFF2F2F7),
    surface:      Color(0xFFFFFFFF),
    surfaceHigh:  Color(0xFFF7F7F7),
    overlay:      Color(0xFFFFFFFF),
    divider:      Color(0xFFE8E8E8),
    border:       Color(0xFFDDDDDD),
    textPrimary:  Color(0xFF111111),
    textSecondary:Color(0xFF666666),
    textMuted:    Color(0xFF8C8C8C),
    accent:       Color(0xFF2563EB),
    accentFg:     Color(0xFFFFFFFF),
    green:        Color(0xFF16A34A),
    red:          Color(0xFFDC2626),
    orange:       Color(0xFFEA580C),
    grey:         Color(0xFF9CA3AF),
  );

  // ── Accessor ───────────────────────────────────────────
  static AppTokens of(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? dark : light;
  }

  // ── Helpers semantici ──────────────────────────────────

  /// Colore bordo card partita (OUT, BUST, FROZEN…)
  Color statusBorder({
    required bool isOut,
    required bool isBust,
    required bool isCheckoutBlocked,
    required bool isFrozen,
  }) {
    if (isOut) return green;
    if (isBust) return red;
    if (isCheckoutBlocked) return orange;
    if (isFrozen) return grey;
    return Colors.transparent;
  }

  /// Colore live (score / turn color)
  Color liveColor({
    required bool isOut,
    required bool isBust,
    required bool isCheckoutBlocked,
  }) {
    if (isOut) return green;
    if (isBust) return red;
    if (isCheckoutBlocked) return orange;
    return accent;
  }

  // ── Border radius ──────────────────────────────────────
  static const r4  = BorderRadius.all(Radius.circular(4));
  static const r6  = BorderRadius.all(Radius.circular(6));
  static const r8  = BorderRadius.all(Radius.circular(8));
  static const r10 = BorderRadius.all(Radius.circular(10));
  static const r12 = BorderRadius.all(Radius.circular(12));
  static const r16 = BorderRadius.all(Radius.circular(16));

  // ── TextStyles base ────────────────────────────────────
  /// Intestazione sezione (GIOCATORI, SCORE…)
  TextStyle labelCaps(Color color) => TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    color: color,
    letterSpacing: 1.0,
  );

  TextStyle bodySmall(Color color) => TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: color,
  );

  TextStyle bodyBold(Color color) => TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: color,
  );

  TextStyle numericLarge(Color color) => TextStyle(
    fontSize: 72,
    height: 1,
    fontWeight: FontWeight.w900,
    color: color,
    letterSpacing: -2,
  );

  TextStyle numericMedium(Color color) => TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w800,
    color: color,
  );
}

// ════════════════════════════════════════════════════════════
//  THEME DATA FACTORY
//  Usare in MaterialApp: theme: AppThemeData.dark()
// ════════════════════════════════════════════════════════════

abstract class AppThemeData {
  static ThemeData dark() => _build(Brightness.dark);
  static ThemeData light() => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final t = brightness == Brightness.dark
        ? AppTokens.dark
        : AppTokens.light;

    final cs = ColorScheme(
      brightness: brightness,
      primary:   t.accent,
      onPrimary: t.accentFg,
      secondary: t.accent,
      onSecondary: t.accentFg,
      error:     t.red,
      onError:   Colors.white,
      surface:   t.surface,
      onSurface: t.textPrimary,
      surfaceContainerHighest: t.surfaceHigh,
      outlineVariant: t.border,
    );

    return ThemeData(
      brightness: brightness,
      colorScheme: cs,
      scaffoldBackgroundColor: t.bg,
      cardColor: t.surface,
      dividerColor: t.divider,
      dialogTheme: DialogThemeData(
        backgroundColor: t.overlay,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: t.bg,
        foregroundColor: t.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: t.textPrimary,
        ),
      ),
      textTheme: TextTheme(
        titleSmall: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: t.textPrimary),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: t.textPrimary),
        bodySmall:  TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: t.textSecondary),
        labelSmall: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: t.textMuted, letterSpacing: 0.8),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.surfaceHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: t.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: t.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: t.accent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        hintStyle: TextStyle(color: t.textMuted, fontSize: 13),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: t.accent,
          foregroundColor: t.accentFg,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: t.textPrimary,
          side: BorderSide(color: t.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: TextStyle(fontSize: 13, color: t.textPrimary),
      ),
    );
  }
}
