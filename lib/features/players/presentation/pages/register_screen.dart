/// File: register_screen.dart
/// TARGET: Schermata registrazione con campi estesi (nome, cognome, nickname)
/// LOGIC GOAL: Creare utente Firebase Auth + salvare profilo in Firestore
/// REACTION: Mostra loading durante registrazione, errore in caso di fallimento
/// ERROR STRATEGY: Messaggi specifici per ogni tipo di errore Firebase
/// ANTI-REGRESSION: Mantenere comportamento originale, aggiungere campi obbligatori

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app_theme.dart';
import '../../data/user_repository.dart';
import '../../domain/user_profile.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _nicknameController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Crea utente in Firebase Auth
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final user = userCredential.user!;
      final email = _emailController.text.trim();

      // 2. Crea profilo in Firestore
      final profile = UserProfile(
        uid: user.uid,
        email: email,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        nickname: _nicknameController.text.trim(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final repository = UserRepository();
      await repository.upsertProfile(profile);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registrazione completata! Benvenuto!')),
      );

      // La navigazione avverrà automaticamente tramite authStateChanges
      Navigator.pop(context);

    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'email-already-in-use':
          message = 'Email già registrata';
          break;
        case 'weak-password':
          message = 'Password troppo debole (minimo 6 caratteri)';
          break;
        case 'invalid-email':
          message = 'Email non valida';
          break;
        case 'operation-not-allowed':
          message = 'Registrazione temporaneamente disabilitata';
          break;
        default:
          message = e.message ?? 'Errore durante la registrazione';
      }
      setState(() => _errorMessage = message);
    } catch (e) {
      setState(() => _errorMessage = 'Errore inaspettato. Riprova più tardi.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        title: const Text('Registrazione'),
        backgroundColor: t.surface,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.person_add, size: 64, color: t.accent),
                const SizedBox(height: 16),
                Text(
                  'Crea il tuo account',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: t.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Nome
                TextFormField(
                  controller: _firstNameController,
                  style: TextStyle(color: t.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Nome *',
                    hintText: 'Il tuo nome',
                    prefixIcon: Icon(Icons.person_outline, color: t.accent),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: t.surface,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Inserisci il nome';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Cognome
                TextFormField(
                  controller: _lastNameController,
                  style: TextStyle(color: t.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Cognome *',
                    hintText: 'Il tuo cognome',
                    prefixIcon: Icon(Icons.person_outline, color: t.accent),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: t.surface,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Inserisci il cognome';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Nickname
                TextFormField(
                  controller: _nicknameController,
                  style: TextStyle(color: t.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Nickname *',
                    hintText: 'Come vuoi essere chiamato nel gioco',
                    prefixIcon: Icon(Icons.tag, color: t.accent),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: t.surface,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Inserisci un nickname';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Email
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(color: t.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Email *',
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

                // Password
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: TextStyle(color: t.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Password *',
                    prefixIcon: Icon(Icons.lock_outline, color: t.accent),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        color: t.textSecondary,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: t.surface,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Inserisci la password';
                    }
                    if (value.length < 6) {
                      return 'Minimo 6 caratteri';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Conferma password
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  style: TextStyle(color: t.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Conferma password *',
                    prefixIcon: Icon(Icons.lock_outline, color: t.accent),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                        color: t.textSecondary,
                      ),
                      onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: t.surface,
                  ),
                  validator: (value) {
                    if (value != _passwordController.text) {
                      return 'Le password non coincidono';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Error message
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: t.red, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),

                // Bottone registra
                ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: t.accent,
                    foregroundColor: t.accentFg,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: t.accentFg),
                  )
                      : const Text('REGISTRATI', style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(height: 16),

                // Link per tornare al login
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Hai già un account? Accedi',
                    style: TextStyle(color: t.accent),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}