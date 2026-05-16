/// File: profile_panel.dart
/// Drawer profilo con nome utente reali e verifica email

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

  Future<void> _sendVerificationEmail(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await user.sendEmailVerification();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email di verifica inviata! Controlla la tua casella'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _refreshVerificationStatus(BuildContext context, WidgetRef ref) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await user.reload();
      final isVerified = user.emailVerified ?? false;

      if (context.mounted) {
        if (isVerified) {
          // Ricarica il profilo per aggiornare lo stato
          await ref.read(userProvider.notifier).loadProfile();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Email verificata!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Email non ancora verificata. Controlla la tua casella.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userState = ref.watch(userProvider);
    final user = FirebaseAuth.instance.currentUser;
    final isLogged = user != null;
    final profile = userState.profile;
    final isEmailVerified = user?.emailVerified ?? false;

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

            // 🔥 BADGE VERIFICA EMAIL
            if (isLogged) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: isEmailVerified ? Colors.green.shade100 : Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isEmailVerified ? Icons.verified : Icons.warning_amber,
                      size: 14,
                      color: isEmailVerified ? Colors.green.shade700 : Colors.orange.shade700,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isEmailVerified ? "Email verificata" : "Email non verificata",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isEmailVerified ? Colors.green.shade700 : Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],

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

            // 🔥 SEZIONE VERIFICA EMAIL (solo se non verificata)
            if (isLogged && !isEmailVerified) ...[
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "VERIFICA EMAIL",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Verifica il tuo indirizzo email per accedere a tutte le funzionalità",
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _sendVerificationEmail(context),
                            icon: const Icon(Icons.email, size: 16),
                            label: const Text("Invia verifica"),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.orange.shade700,
                              side: BorderSide(color: Colors.orange.shade300),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              textStyle: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => _refreshVerificationStatus(context, ref),
                          icon: const Icon(Icons.refresh, size: 20),
                          tooltip: "Verifica stato",
                          color: Colors.blue.shade600,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

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