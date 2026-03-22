import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../pages/login_screen.dart';
import '../pages/profile_screen.dart';
import '../pages/settings_screen.dart';

class ProfilePanel extends StatelessWidget {
  const ProfilePanel({super.key});

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
  }

  @override
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

            const SizedBox(height: 30),

            ListTile(
              leading: const Icon(Icons.person),
              title: const Text("Profilo"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ProfileScreen(),
                  ),
                );              },
            ),

            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text("Impostazioni"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SettingsScreen(),
                  ),
                );              },
            ),

            const Spacer(),

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