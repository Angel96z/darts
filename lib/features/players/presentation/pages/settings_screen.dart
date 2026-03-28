/// File: settings_screen.dart. Contiene logica di presentazione (UI, widget o controller) per questa parte dell'app.

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  /// Funzione: descrive in modo semplice questo blocco di logica.
  const SettingsScreen({super.key});

  @override
  /// Funzione: descrive in modo semplice questo blocco di logica.
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {

  ThemeMode _themeMode = ThemeController.themeMode.value;

  /// Funzione: descrive in modo semplice questo blocco di logica.
  void _setTheme(ThemeMode mode) {
    /// Funzione: descrive in modo semplice questo blocco di logica.
    setState(() {
      _themeMode = mode;
    });

    ThemeController.setTheme(mode);
  }

  @override
  /// Funzione: descrive in modo semplice questo blocco di logica.
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text("Impostazioni"),
      ),
      body: ListView(
        children: [

          const SizedBox(height: 10),

          /// Funzione: descrive in modo semplice questo blocco di logica.
          const ListTile(
            title: Text(
              "Aspetto",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),

          RadioListTile<ThemeMode>(
            title: const Text("Sistema"),
            value: ThemeMode.system,
            groupValue: _themeMode,
            onChanged: (v) => _setTheme(v!),
          ),

          RadioListTile<ThemeMode>(
            title: const Text("Chiaro"),
            value: ThemeMode.light,
            groupValue: _themeMode,
            onChanged: (v) => _setTheme(v!),
          ),

          RadioListTile<ThemeMode>(
            title: const Text("Scuro"),
            value: ThemeMode.dark,
            groupValue: _themeMode,
            onChanged: (v) => _setTheme(v!),
          ),

          const Divider(),

          const ListTile(
            title: Text(
              "App",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),

          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text("Versione app"),
            subtitle: const Text("1.0.0"),
          ),

        ],
      ),
    );
  }
}
