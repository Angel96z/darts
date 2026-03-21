import 'package:flutter/material.dart';

import '../../../data/datasources/auth/guest_auth_service.dart';

class GuestLoginScreen extends StatefulWidget {
  const GuestLoginScreen({super.key});

  @override
  State<GuestLoginScreen> createState() => _GuestLoginScreenState();
}

class _GuestLoginScreenState extends State<GuestLoginScreen> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();

  bool loading = false;
  String? error;

  final service = GuestAuthService();

  @override
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
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            const SizedBox(height: 16),
            if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: loading
                  ? null
                  : () async {
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