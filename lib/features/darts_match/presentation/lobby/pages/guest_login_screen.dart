/// File: guest_login_screen.dart. Contiene logica di presentazione (UI, widget o controller) per questa parte dell'app.

import 'package:flutter/material.dart';

import '../../../data/datasources/auth/guest_auth_service.dart';

class GuestLoginScreen extends StatefulWidget {
  /// Funzione: descrive in modo semplice questo blocco di logica.
  const GuestLoginScreen({super.key});

  @override
  /// Funzione: descrive in modo semplice questo blocco di logica.
  State<GuestLoginScreen> createState() => _GuestLoginScreenState();
}

class _GuestLoginScreenState extends State<GuestLoginScreen> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();

  bool loading = false;
  String? error;

  final service = GuestAuthService();

  @override
  /// Funzione: descrive in modo semplice questo blocco di logica.
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login guest')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            /// Funzione: descrive in modo semplice questo blocco di logica.
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            /// Funzione: descrive in modo semplice questo blocco di logica.
            const SizedBox(height: 16),
            if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
            /// Funzione: descrive in modo semplice questo blocco di logica.
            const SizedBox(height: 8),
            /// Funzione: descrive in modo semplice questo blocco di logica.
            ElevatedButton(
              onPressed: loading
                  ? null
                  : () async {
                /// Funzione: descrive in modo semplice questo blocco di logica.
                setState(() {
                  loading = true;
                  error = null;
                });

                try {
                  final result = await service.signIn(
                    email: emailCtrl.text.trim(),
                    password: passCtrl.text.trim(),
                  );

                  if (context.mounted) {
                    Navigator.pop(context, result);
                  }
                } catch (e) {
                  /// Funzione: descrive in modo semplice questo blocco di logica.
                  setState(() {
                    error = e.toString();
                    loading = false;
                  });
                }
              },
              child: loading
                  ? const CircularProgressIndicator()
                  : const Text('Accedi'),
            ),
          ],
        ),
      ),
    );
  }
}
