/// File: profile_panel.dart
/// Drawer profilo con nome utente reali

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../pages/login_screen.dart';
import '../pages/profile_screen.dart';
import '../pages/settings_screen.dart';
import '../../application/user_notifier.dart';

class ProfilePanel extends ConsumerWidget {
  const ProfilePanel({super.key});

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    await FirebaseAuth.instance.signOut();
    ref.read(userProvider.notifier).reset();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userState = ref.watch(userProvider);
    final user = FirebaseAuth.instance.currentUser;
    final isLogged = user != null;
    final profile = userState.profile;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),

            CircleAvatar(
              radius: 45,
              backgroundColor: Colors.blue.shade100,
              child: Text(
                userState.initials,
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.blue),
              ),
            ),

            const SizedBox(height: 10),

            Text(
              userState.displayName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 4),

            Text(
              profile?.email ?? user?.email ?? "Utente",
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),

            const SizedBox(height: 30),

            ListTile(
              leading: const Icon(Icons.person),
              title: const Text("Profilo"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
              },
            ),

            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text("Impostazioni"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
              },
            ),

            const Spacer(),

            ListTile(
              leading: Icon(isLogged ? Icons.logout : Icons.login),
              title: Text(isLogged ? "Logout" : "Login"),
              onTap: () async {
                Navigator.pop(context);
                if (isLogged) {
                  await _logout(context, ref);
                } else {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
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