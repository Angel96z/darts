// ════════════════════════════════════════════════════════════
//  APP THEME — Design Tokens
//
//  USO RAPIDO
//  ──────────
//  Colori:    final t = AppTokens.of(context);
//             Container(color: t.surface)
//
//  Testo:     Text('ciao', style: Theme.of(context).textTheme.bodyMedium)
//
//  Numerici:  Text('501', style: AppTokens.scoreStyle.copyWith(color: t.textPrimary))
//             → non scala con accessibilità (voluto — vedi clampScore)
// ════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

// ════════════════════════════════════════════════════════════
//  TOKENS
// ════════════════════════════════════════════════════════════

class AppTokens {
  // ── Sfondi ─────────────────────────────────────────────
  final Color bg;
  final Color surface;
  final Color surfaceHigh;
  final Color overlay;

  // ── Bordi e divisori ───────────────────────────────────
  final Color divider;
  final Color border;

  // ── Testi ──────────────────────────────────────────────
  // Dark:  non bianco puro — 87 % riduce l'abbagliamento su nero,
  //        standard Material e Apple per lettura prolungata.
  // Light: non nero puro — #1C1C1E è il nero di sistema iOS/macOS,
  //        meno duro del carbon puro ma contrasto WCAG AA garantito.
  final Color textPrimary;    // corpo principale, titoli
  final Color textSecondary;  // label secondarie, metadata
  final Color textMuted;      // placeholder, hint, disabled

  // ── Accenti semantici ──────────────────────────────────
  final Color accent;
  final Color accentFg;
  final Color green;
  final Color red;
  final Color orange;
  final Color grey;

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
  // Sfondo: nero pieno (OLED friendly).
  // Testi:  non bianchi puri — la differenza è sottile a schermo
  //         ma la fatica oculare su sessioni lunghe è misurabile.
  //   textPrimary   #E8E8E8  ≈ rgba(255,255,255,0.91)  → corpo, titoli
  //   textSecondary #A0A0A0  ≈ rgba(255,255,255,0.63)  → label secondarie
  //   textMuted     #686868  ≈ rgba(255,255,255,0.41)  → hint, placeholder
  static const dark = AppTokens._(
    bg:            Color(0xFF000000),
    surface:       Color(0xFF1C1C1C),
    surfaceHigh:   Color(0xFF2A2A2A),
    overlay:       Color(0xFF242424),
    divider:       Color(0xFF333333),
    border:        Color(0xFF484848),
    textPrimary:   Color(0xFFE8E8E8),  // ← era 0xFFFFFFFF (puro, abbagliante)
    textSecondary: Color(0xFFA0A0A0),  // ← era 0xFFAAAAAA (quasi uguale, ok)
    textMuted:     Color(0xFF686868),  // ← era 0xFF777777 (leggermente più leggibile)
    accent:        Color(0xFFFBBF24),
    accentFg:      Color(0xFF000000),
    green:         Color(0xFF22C55E),
    red:           Color(0xFFEF4444),
    orange:        Color(0xFFF97316),
    grey:          Color(0xFF6B7280),
  );

  // ── Light ──────────────────────────────────────────────
  // Sfondo: grigio sistema (non bianco puro, meno riflettente).
  // Testi:  nero Apple #1C1C1E invece di #111111.
  //   textPrimary   #1C1C1E  → corpo, titoli
  //   textSecondary #545456  → label secondarie
  //   textMuted     #8A8A8E  → hint, placeholder
  static const light = AppTokens._(
    bg:            Color(0xFFF2F2F7),
    surface:       Color(0xFFFFFFFF),
    surfaceHigh:   Color(0xFFF5F5F5),
    overlay:       Color(0xFFFFFFFF),
    divider:       Color(0xFFE5E5EA),
    border:        Color(0xFFD8D8DC),
    textPrimary:   Color(0xFF1C1C1E),  // ← era #111111 (nero più naturale)
    textSecondary: Color(0xFF545456),  // ← era #666666 (più scuro, contrasto migliore)
    textMuted:     Color(0xFF8A8A8E),  // ← era #8C8C8C (sistema iOS)
    accent:        Color(0xFF2563EB),
    accentFg:      Color(0xFFFFFFFF),
    green:         Color(0xFF16A34A),
    red:           Color(0xFFDC2626),
    orange:        Color(0xFFEA580C),
    grey:          Color(0xFF9CA3AF),
  );

  static AppTokens of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;

  // ── Status helpers ─────────────────────────────────────

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

  // ── Numerici display — NON scalano con il sistema ──────
  // Il punteggio a schermo deve restare leggibile a colpo d'occhio
  // indipendentemente dalle impostazioni di accessibilità.
  // Usa clampScore() per avvolgerli.

  /// Punteggio principale — 76 sp fissi.
  static const TextStyle scoreStyle = TextStyle(
    fontSize: 76,
    height:   1.0,
    fontWeight: FontWeight.w800,
    letterSpacing: -2,
    // Colore: .copyWith(color: t.textPrimary) nel widget
  );

  /// Punteggio secondario / subtotale — 20 sp fissi.
  static const TextStyle scoreSmallStyle = TextStyle(
    fontSize: 20,
    height:   1.2,
    fontWeight: FontWeight.w700,
  );

  /// Blocca textScaler a 1× per i widget numerici.
  /// Uso: MediaQuery(data: AppTokens.clampScore(context), child: ...)
  static MediaQueryData clampScore(BuildContext context) =>
      MediaQuery.of(context).copyWith(
        textScaler: MediaQuery.textScalerOf(context)
            .clamp(minScaleFactor: 1.0, maxScaleFactor: 1.0),
      );
}

// ════════════════════════════════════════════════════════════
//  THEME DATA FACTORY
// ════════════════════════════════════════════════════════════

abstract class AppThemeData {
  static ThemeData dark()  => _build(Brightness.dark);
  static ThemeData light() => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final t = brightness == Brightness.dark ? AppTokens.dark : AppTokens.light;

    final cs = ColorScheme(
      brightness:              brightness,
      primary:                 t.accent,
      onPrimary:               t.accentFg,
      secondary:               t.accent,
      onSecondary:             t.accentFg,
      error:                   t.red,
      onError:                 Colors.white,
      surface:                 t.surface,
      onSurface:               t.textPrimary,
      surfaceContainerHighest: t.surfaceHigh,
      outlineVariant:          t.border,
    );

    // ── TextTheme ─────────────────────────────────────────
    // Tutti gli stili scalano con MediaQuery.textScaler (impostazioni sistema).
    //
    // 5 ruoli:
    //
    //  titleMedium  →  intestazioni sezione, nome giocatore    17 sp  w600
    //  titleSmall   →  label sopra dato, tab, chip header      15 sp  w600
    //  bodyMedium   →  corpo principale, storico, descrizioni  16 sp  w400  ← il più usato
    //  bodySmall    →  note, metadata, hint                    14 sp  w400
    //  labelSmall   →  caps micro, badge                       12 sp  w500
    //
    // Regole pesi:
    //   w400 su tutto il corpo → standard lettura, non affatica
    //   w600 su titoli UI      → distinzione chiara senza urlare
    //   mai w700+ sotto 14 sp  → i tratti si fondono su OLED piccoli
    //
    // Regole interlinea:
    //   height 1.5  su body  → WCAG AA per lettura lunga (~24 px su 16 sp)
    //   height 1.35 su label → testo breve, niente aria in eccesso

    final tt = TextTheme(
      titleMedium: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: t.textPrimary,   height: 1.35),
      titleSmall:  TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: t.textPrimary,   height: 1.35),
      bodyMedium:  TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: t.textPrimary,   height: 1.5),
      bodySmall:   TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: t.textSecondary, height: 1.5),
      labelSmall:  TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: t.textMuted,     height: 1.35, letterSpacing: 0.6),
    );

    return ThemeData(
      brightness:              brightness,
      colorScheme:             cs,
      scaffoldBackgroundColor: t.bg,
      cardColor:               t.surface,
      dividerColor:            t.divider,
      textTheme:               tt,

      dialogTheme: DialogThemeData(
        backgroundColor:  t.overlay,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor:  t.bg,
        foregroundColor:  t.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation:        0,
        titleTextStyle:   tt.titleMedium,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled:    true,
        fillColor: t.surfaceHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:   BorderSide(color: t.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:   BorderSide(color: t.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:   BorderSide(color: t.accent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        hintStyle: tt.bodySmall,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: t.accent,
          foregroundColor: t.accentFg,
          elevation:       0,
          shape:           RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding:         const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle:       tt.titleSmall,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: t.textPrimary,
          side:            BorderSide(color: t.border),
          shape:           RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding:         const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle:       tt.bodySmall,
        ),
      ),

      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: tt.bodyMedium,
      ),
    );
  }
}