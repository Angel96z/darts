/// FILE: forgot_password_screen.dart
/// TARGET: Schermata recupero password
/// LOGIC GOAL: Inviare email reset password
/// REACTION: Mostra loading e successo/errore

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app_theme.dart';
import '../../application/user_notifier.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _successMessage;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _successMessage = null;
      _errorMessage = null;
    });

    final email = _emailController.text.trim();
    final notifier = ref.read(userProvider.notifier);

    // Reset stato precedente
    notifier.clearError();

    await notifier.resetPassword(email);

    // Attendi stato
    await Future.delayed(const Duration(milliseconds: 100));

    final state = ref.read(userProvider);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (state.hasError) {
          _errorMessage = state.failure?.message ?? 'Errore invio email';
        } else if (state.status == AppStatus.success) {
          _successMessage = 'Email di reset inviata! Controlla la tua casella.';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        title: const Text('Recupera password'),
        backgroundColor: t.surface,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              Icon(Icons.lock_reset, size: 64, color: t.accent),
              const SizedBox(height: 24),
              Text(
                'Inserisci la tua email',
                style: tt.titleMedium?.copyWith(color: t.textPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Ti invieremo un link per reimpostare la password',
                style: tt.bodySmall?.copyWith(color: t.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: tt.bodyMedium?.copyWith(color: t.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined, color: t.accent),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: t.surface,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Inserisci l\'email';
                  }
                  if (!value.contains('@')) {
                    return 'Email non valida';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              if (_successMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: t.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _successMessage!,
                    style: tt.bodySmall?.copyWith(color: t.green),
                    textAlign: TextAlign.center,
                  ),
                ),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _errorMessage!,
                    style: tt.bodySmall?.copyWith(color: t.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _sendResetEmail,
                style: ElevatedButton.styleFrom(
                  backgroundColor: t.accent,
                  foregroundColor: t.accentFg,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: t.accentFg))
                    : Text(
                        'INVIA LINK',
                        style: tt.titleSmall?.copyWith(color: t.accentFg),
                      ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Torna al login',
                  style: tt.titleSmall?.copyWith(color: t.accent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
