/// FILE: login_screen.dart
/// TARGET: Schermata login SENZA verifica email obbligatoria

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app_theme.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool loading = false;
  bool showPassword = false;
  String error = "";

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      loading = true;
      error = "";
    });

    try {
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      // 🔥 NESSUN CONTROLLO EMAIL VERIFICATA - LOGIN SEMPRE CONSENTITO

      if (mounted) {
        setState(() => loading = false);
      }

      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context, true);
      }

    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message;
      switch (e.code) {
        case "user-not-found": message = "Utente non trovato"; break;
        case "wrong-password": message = "Password errata"; break;
        case "invalid-email": message = "Email non valida"; break;
        case "user-disabled": message = "Account disabilitato"; break;
        case "too-many-requests": message = "Troppi tentativi. Riprova più tardi"; break;
        default: message = e.message ?? "Errore login";
      }
      setState(() {
        error = message;
        loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          error = "Errore inatteso";
          loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text("Accedi a My Darts roses trainer")),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 10),
                  Text(
                    "Accedi",
                    style: tt.titleMedium?.copyWith(color: t.textPrimary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: "Email",
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return "Inserisci email";
                      if (!value.contains("@")) return "Email non valida";
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: passwordController,
                    obscureText: !showPassword,
                    decoration: InputDecoration(
                      labelText: "Password",
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(showPassword ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => showPassword = !showPassword),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return "Inserisci password";
                      if (value.length < 6) return "Password troppo corta";
                      return null;
                    },
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: loading ? null : login,
                      child: loading
                          ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                          : const Text("Login"),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                      );
                    },
                    child: Text(
                      "Password dimenticata?",
                      style: tt.bodySmall?.copyWith(color: t.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RegisterScreen()),
                      );
                    },
                    child: const Text("Non hai un account? Registrati"),
                  ),
                  if (error.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(
                      error,
                      style: tt.bodySmall?.copyWith(color: t.red),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
