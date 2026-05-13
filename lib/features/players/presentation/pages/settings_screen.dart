/// File: settings_screen.dart - Allineato al tema ufficiale AppTokens

import 'package:flutter/material.dart';

import '../../../../app/app.dart';
import '../../../../app_theme.dart';


class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late ThemeMode _themeMode;

  @override
  void initState() {
    super.initState();
    _themeMode = ThemeController.themeMode.value;
    _listenToThemeChanges();
  }

  void _listenToThemeChanges() {
    ThemeController.themeMode.addListener(() {
      if (mounted) {
        setState(() {
          _themeMode = ThemeController.themeMode.value;
        });
      }
    });
  }

  void _setTheme(ThemeMode mode) {
    ThemeController.setTheme(mode);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        title: Text(
          "Impostazioni",
          style: TextStyle(color: t.textPrimary),
        ),
        backgroundColor: t.surface,
        elevation: 0,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 10),

          // Sezione Aspetto
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              "Aspetto",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: t.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ),

          RadioListTile<ThemeMode>(
            title: Text(
              "Sistema",
              style: TextStyle(color: t.textPrimary),
            ),
            value: ThemeMode.system,
            groupValue: _themeMode,
            activeColor: t.accent,
            onChanged: (v) => _setTheme(v!),
          ),

          RadioListTile<ThemeMode>(
            title: Text(
              "Chiaro",
              style: TextStyle(color: t.textPrimary),
            ),
            value: ThemeMode.light,
            groupValue: _themeMode,
            activeColor: t.accent,
            onChanged: (v) => _setTheme(v!),
          ),

          RadioListTile<ThemeMode>(
            title: Text(
              "Scuro",
              style: TextStyle(color: t.textPrimary),
            ),
            value: ThemeMode.dark,
            groupValue: _themeMode,
            activeColor: t.accent,
            onChanged: (v) => _setTheme(v!),
          ),

          Divider(color: t.divider, height: 32, indent: 16, endIndent: 16),

          // Sezione App
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              "App",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: t.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ),

          ListTile(
            leading: Icon(Icons.info_outline, color: t.textSecondary),
            title: Text(
              "Versione app",
              style: TextStyle(color: t.textPrimary),
            ),
            subtitle: Text(
              "1.0.0",
              style: TextStyle(color: t.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}