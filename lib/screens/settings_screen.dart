import 'package:flutter/material.dart';

import '../app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {

  ThemeMode _themeMode = ThemeController.themeMode.value;

  void _setTheme(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
    });

    ThemeController.setTheme(mode);
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text("Impostazioni"),
      ),
      body: ListView(
        children: [

          const SizedBox(height: 10),

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