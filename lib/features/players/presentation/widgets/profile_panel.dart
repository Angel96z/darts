import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
              leading: const Icon(Icons.logout),
              title: const Text("Logout"),
              onTap: () async {
                Navigator.pop(context);
                await _logout(context);
              },
            ),

            const SizedBox(height: 20),

          ],
        ),
      ),
    );
  }
}