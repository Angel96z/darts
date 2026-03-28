/// File: profile_screen.dart. Contiene logica di presentazione (UI, widget o controller) per questa parte dell'app.

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileScreen extends StatelessWidget {
  /// Funzione: descrive in modo semplice questo blocco di logica.
  const ProfileScreen({super.key});

  /// Funzione: descrive in modo semplice questo blocco di logica.
  Future<void> _sendPasswordReset(BuildContext context, String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Email per cambio password inviata")),
      );
    } on FirebaseAuthException catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? "Errore reset password")),
      );
    } catch (_) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Errore reset password")),
      );
    }
  }

  /// Funzione: descrive in modo semplice questo blocco di logica.
  Future<void> _deleteAccount(BuildContext context) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      await user?.delete();

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Account eliminato")),
      );

      Navigator.of(context).popUntil((route) => route.isFirst);
    } on FirebaseAuthException catch (e) {
      if (!context.mounted) return;

      String message = e.message ?? "Errore eliminazione account";

      if (e.code == 'requires-recent-login') {
        message = "Per eliminare l'account devi rifare il login.";
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (_) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Errore eliminazione account")),
      );
    }
  }

  /// Funzione: descrive in modo semplice questo blocco di logica.
  Future<void> _confirmDelete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        /// Funzione: descrive in modo semplice questo blocco di logica.
        return AlertDialog(
          title: const Text("Elimina account"),
          content: const Text(
            "Vuoi eliminare definitivamente il tuo account?",
          ),
          actions: [
            /// Funzione: descrive in modo semplice questo blocco di logica.
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Annulla"),
            ),
            /// Funzione: descrive in modo semplice questo blocco di logica.
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Elimina"),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await _deleteAccount(context);
    }
  }

  @override
  /// Funzione: descrive in modo semplice questo blocco di logica.
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? "Nessuna email";
    final uid = user?.uid ?? "";

    return Scaffold(
      appBar: AppBar(
        title: const Text("Profilo"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 12),
          const Center(
            child: Icon(Icons.account_circle, size: 96),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              email,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              "UID: $uid",
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          /// Funzione: descrive in modo semplice questo blocco di logica.
          Card(
            child: Column(
              children: [
                /// Funzione: descrive in modo semplice questo blocco di logica.
                ListTile(
                  leading: const Icon(Icons.email),
                  title: const Text("Email"),
                  subtitle: Text(email),
                ),
                /// Funzione: descrive in modo semplice questo blocco di logica.
                const Divider(height: 1),
                /// Funzione: descrive in modo semplice questo blocco di logica.
                ListTile(
                  leading: const Icon(Icons.lock_reset),
                  title: const Text("Cambia password"),
                  onTap: () {
                    if (user?.email != null) {
                      _sendPasswordReset(context, user!.email!);
                    }
                  },
                ),
                /// Funzione: descrive in modo semplice questo blocco di logica.
                const Divider(height: 1),
                /// Funzione: descrive in modo semplice questo blocco di logica.
                ListTile(
                  leading: const Icon(Icons.delete_forever),
                  title: const Text("Elimina account"),
                  onTap: () => _confirmDelete(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
