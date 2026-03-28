/// File: app_theme.dart. Contiene componenti condivisi usati in più parti dell'app.

import 'package:flutter/material.dart';
import 'package:flutter/material.dart';

class AppTheme {

  static final light = ThemeData(
    brightness: Brightness.light,
    colorSchemeSeed: Colors.deepPurple,
    useMaterial3: true,

    scaffoldBackgroundColor: Colors.white,

    appBarTheme: const AppBarTheme(
      elevation: 0,
      centerTitle: false,
    ),

    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
    ),
  );


  static final dark = ThemeData(
    brightness: Brightness.dark,
    colorSchemeSeed: Colors.deepPurple,
    useMaterial3: true,

    appBarTheme: const AppBarTheme(
      elevation: 0,
      centerTitle: false,
    ),

    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
    ),
  );

}


class ThemeController {
  static final ValueNotifier<ThemeMode> themeMode =
  ValueNotifier(ThemeMode.system);

  /// Funzione: descrive in modo semplice questo blocco di logica.
  static void setTheme(ThemeMode mode) {
    themeMode.value = mode;
  }
}