/// FILE: email_verification_screen.dart
/// Schermata dopo registrazione - attesa verifica email

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../app_theme.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;
  const EmailVerificationScreen({super.key, required this.email});

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _isChecking = false;
  String? _message;

  Future<void> _checkVerification() async {
    setState(() {
      _isChecking = true;
      _message = null;
    });

    await FirebaseAuth.instance.currentUser?.reload();
    final user = FirebaseAuth.instance.currentUser;

    if (user?.emailVerified == true) {
      if (mounted) {
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } else {
      setState(() {
        _isChecking = false;
        _message = 'Email non ancora verificata. Controlla la tua casella.';
      });
    }
  }

  Future<void> _resendVerification() async {
    setState(() => _isChecking = true);
    try {
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      setState(() {
        _message = 'Email di verifica reinviata!';
        _isChecking = false;
      });
    } catch (e) {
      setState(() {
        _message = 'Errore: ${e.toString()}';
        _isChecking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.mark_email_read, size: 80, color: t.accent),
              const SizedBox(height: 24),
              Text(
                'Verifica la tua email',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: t.textPrimary),
              ),
              const SizedBox(height: 16),
              Text(
                'Abbiamo inviato un link di verifica a:',
                style: TextStyle(color: t.textSecondary),
              ),
              const SizedBox(height: 8),
              Text(
                widget.email,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: t.accent),
              ),
              const SizedBox(height: 24),
              Text(
                'Clicca sul link nell\'email per completare la registrazione',
                textAlign: TextAlign.center,
                style: TextStyle(color: t.textSecondary),
              ),
              const SizedBox(height: 32),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(_message!, style: TextStyle(color: _message!.contains('Errore') ? t.red : t.green), textAlign: TextAlign.center),
                ),
              ElevatedButton(
                onPressed: _isChecking ? null : _checkVerification,
                style: ElevatedButton.styleFrom(
                  backgroundColor: t.accent,
                  foregroundColor: t.accentFg,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isChecking
                    ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: t.accentFg))
                    : const Text('HO VERIFICATO', style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _resendVerification,
                child: Text('Reinvia email di verifica', style: TextStyle(color: t.accent)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}