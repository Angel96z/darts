/// File: profile_panel.dart. Contiene logica di presentazione (UI, widget o controller) per questa parte dell'app.

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../pages/login_screen.dart';
import '../pages/profile_screen.dart';
import '../pages/settings_screen.dart';

class ProfilePanel extends StatelessWidget {
  /// Funzione: descrive in modo semplice questo blocco di logica.
  const ProfilePanel({super.key});

  /// Funzione: descrive in modo semplice questo blocco di logica.
  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  /// Funzione: descrive in modo semplice questo blocco di logica.
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isLogged = user != null;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [

            const SizedBox(height: 20),

            const Icon(Icons.account_circle, size: 90),

            const SizedBox(height: 10),

            Text(
              user?.email ?? "Utente",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            /// Funzione: descrive in modo semplice questo blocco di logica.
            const SizedBox(height: 30),

            /// Funzione: descrive in modo semplice questo blocco di logica.
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text("Profilo"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  /// Funzione: descrive in modo semplice questo blocco di logica.
                  MaterialPageRoute(
                    builder: (_) => const ProfileScreen(),
                  ),
                );              },
            ),

            /// Funzione: descrive in modo semplice questo blocco di logica.
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text("Impostazioni"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  /// Funzione: descrive in modo semplice questo blocco di logica.
                  MaterialPageRoute(
                    builder: (_) => const SettingsScreen(),
                  ),
                );              },
            ),

            /// Funzione: descrive in modo semplice questo blocco di logica.
            const Spacer(),

            /// Funzione: descrive in modo semplice questo blocco di logica.
            ListTile(
              leading: Icon(isLogged ? Icons.logout : Icons.login),
              title: Text(isLogged ? "Logout" : "Login"),
              onTap: () async {
                Navigator.pop(context);

                if (isLogged) {
                  await _logout(context);
                } else {
                  Navigator.push(
                    context,
                    /// Funzione: descrive in modo semplice questo blocco di logica.
                    MaterialPageRoute(
                      builder: (_) => const LoginScreen(),
                    ),
                  );
                }
              },
            ),

            const SizedBox(height: 20),

          ],
        ),
      ),
    );
  }
}
