import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {

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

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context, true);
      }

    } on FirebaseAuthException catch (e) {

      String message;

      switch (e.code) {

        case "user-not-found":
          message = "Utente non trovato";
          break;

        case "wrong-password":
          message = "Password errata";
          break;

        case "invalid-email":
          message = "Email non valida";
          break;

        case "user-disabled":
          message = "Account disabilitato";
          break;

        case "too-many-requests":
          message = "Troppi tentativi. Riprova più tardi";
          break;

        default:
          message = e.message ?? "Errore login";
      }

      setState(() {
        error = message;
      });

    } catch (e) {

      setState(() {
        error = "Errore inatteso";
      });

    } finally {

      if (mounted) {
        setState(() {
          loading = false;
        });
      }

    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text("Login"),
      ),

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

                  const Text(
                    "Accedi",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
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

                      if (value == null || value.isEmpty) {
                        return "Inserisci email";
                      }

                      if (!value.contains("@")) {
                        return "Email non valida";
                      }

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
                        icon: Icon(
                          showPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),

                        onPressed: () {
                          setState(() {
                            showPassword = !showPassword;
                          });
                        },
                      ),
                    ),

                    validator: (value) {

                      if (value == null || value.isEmpty) {
                        return "Inserisci password";
                      }

                      if (value.length < 6) {
                        return "Password troppo corta";
                      }

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
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : const Text("Login"),
                    ),
                  ),

                  const SizedBox(height: 16),

                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RegisterScreen(),
                        ),
                      );
                    },
                    child: const Text("Non hai un account? Registrati"),
                  ),

                  if (error.isNotEmpty) ...[
                    const SizedBox(height: 20),

                    Text(
                      error,
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
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
