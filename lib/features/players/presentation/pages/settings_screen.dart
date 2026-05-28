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
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        title: Text(
          "Impostazioni",
          style: tt.titleMedium?.copyWith(color: t.textPrimary),
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
              style: tt.labelSmall?.copyWith(color: t.textSecondary),
            ),
          ),

          RadioListTile<ThemeMode>(
            title: Text(
              "Sistema",
              style: tt.bodyMedium?.copyWith(color: t.textPrimary),
            ),
            value: ThemeMode.system,
            groupValue: _themeMode,
            activeColor: t.accent,
            onChanged: (v) => _setTheme(v!),
          ),

          RadioListTile<ThemeMode>(
            title: Text(
              "Chiaro",
              style: tt.bodyMedium?.copyWith(color: t.textPrimary),
            ),
            value: ThemeMode.light,
            groupValue: _themeMode,
            activeColor: t.accent,
            onChanged: (v) => _setTheme(v!),
          ),

          RadioListTile<ThemeMode>(
            title: Text(
              "Scuro",
              style: tt.bodyMedium?.copyWith(color: t.textPrimary),
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
              style: tt.labelSmall?.copyWith(color: t.textSecondary),
            ),
          ),

          ListTile(
            leading: Icon(Icons.info_outline, color: t.textSecondary),
            title: Text(
              "Versione app",
              style: tt.bodyMedium?.copyWith(color: t.textPrimary),
            ),
            subtitle: Text(
              "1.0.0",
              style: tt.bodySmall?.copyWith(color: t.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}
