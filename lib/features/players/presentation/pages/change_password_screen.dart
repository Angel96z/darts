/// FILE: change_password_screen.dart
/// TARGET: Cambio password da profilo (richiede vecchia password)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app_theme.dart';
import '../../application/user_notifier.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final notifier = ref.read(userProvider.notifier);
    notifier.clearError();

    await notifier.changePassword(
      currentPassword: _currentPasswordController.text,
      newPassword: _newPasswordController.text,
    );

    await Future.delayed(const Duration(milliseconds: 100));
    final state = ref.read(userProvider);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (state.hasError) {
          _errorMessage = state.failure?.message ?? 'Errore cambio password';
        } else if (state.status == AppStatus.success) {
          _successMessage = 'Password cambiata con successo!';
          _currentPasswordController.clear();
          _newPasswordController.clear();
          _confirmPasswordController.clear();
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) Navigator.pop(context);
          });
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
        title: const Text('Cambia password'),
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
              const SizedBox(height: 20),
              _buildPasswordField(
                controller: _currentPasswordController,
                label: 'Password attuale',
                obscure: _obscureCurrent,
                onToggle: () => setState(() => _obscureCurrent = !_obscureCurrent),
                t: t,
              ),
              const SizedBox(height: 16),
              _buildPasswordField(
                controller: _newPasswordController,
                label: 'Nuova password',
                obscure: _obscureNew,
                onToggle: () => setState(() => _obscureNew = !_obscureNew),
                t: t,
              ),
              const SizedBox(height: 16),
              _buildPasswordField(
                controller: _confirmPasswordController,
                label: 'Conferma nuova password',
                obscure: _obscureConfirm,
                onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
                t: t,
                validator: (value) {
                  if (value != _newPasswordController.text) {
                    return 'Le password non coincidono';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              if (_errorMessage != null)
                Text(
                  _errorMessage!,
                  style: tt.bodySmall?.copyWith(color: t.red),
                  textAlign: TextAlign.center,
                ),
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
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _changePassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: t.accent,
                  foregroundColor: t.accentFg,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: t.accentFg))
                    : Text(
                        'CAMBIA PASSWORD',
                        style: tt.titleSmall?.copyWith(color: t.accentFg),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
    required AppTokens t,
    String? Function(String?)? validator,
  }) {
    final tt = Theme.of(context).textTheme;
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      style: tt.bodyMedium?.copyWith(color: t.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(Icons.lock_outline, color: t.accent),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, color: t.textSecondary),
          onPressed: onToggle,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: t.surface,
      ),
      validator: validator ?? (value) {
        if (value == null || value.isEmpty) return 'Inserisci $label';
        if (label.contains('nuova') && value.length < 6) return 'Minimo 6 caratteri';
        return null;
      },
    );
  }
}
