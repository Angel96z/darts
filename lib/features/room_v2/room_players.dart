import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

/// MODEL PLAYER
class RoomPlayer {
  final String id;
  final String name;
  final bool isGuest;

  const RoomPlayer({
    required this.id,
    required this.name,
    required this.isGuest,
  });

  Map<String, dynamic> toMap() =>
      {'id': id, 'name': name, 'isGuest': isGuest};
}

/// CONTROLLER
class RoomPlayersController {
  final String currentUserId;
  final List<String> adminIds;

  RoomPlayersController({
    required this.currentUserId,
    required this.adminIds,
  });

  bool canRemove(Map<String, dynamic> player) {
    final isAdmin = adminIds.contains(currentUserId);

    // ADMIN → può rimuovere sempre
    if (isAdmin) return true;

    // NON ADMIN → solo se è il suo player
    final ownerId = player['ownerId'];
    final id = player['id'];

    return ownerId == currentUserId || id == currentUserId;
  }

  Future<RoomPlayer?> openAddDialog(BuildContext context) async {
    return await showDialog<RoomPlayer>(
      context: context,
      builder: (_) => const _AddPlayerOverlay(),
    );
  }
}

/// ISTANZA ISOLATA PER LOGIN SENZA LOGOUT
Future<FirebaseAuth> _getSecondaryAuth() async {
  const String name = 'secondary';
  FirebaseApp app;
  try {
    app = Firebase.app(name);
  } catch (_) {
    app = await Firebase.initializeApp(
      name: name,
      options: Firebase.app().options,
    );
  }
  return FirebaseAuth.instanceFor(app: app);
}

class _AddPlayerOverlay extends StatefulWidget {
  const _AddPlayerOverlay();

  @override
  State<_AddPlayerOverlay> createState() =>
      _AddPlayerOverlayState();
}

class _AddPlayerOverlayState extends State<_AddPlayerOverlay> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _guest = TextEditingController();

  bool isLoginMode = false;
  bool loading = false;
  String? error;

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Aggiungi giocatore',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),

              const SizedBox(height: 16),

              if (error != null)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.red.withOpacity(0.08),
                  ),
                  child: Text(
                    error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),

              // BLOCCO PRINCIPALE (solo se NON login mode)
              if (!isLoginMode) ...[
                if (currentUser != null) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        final p = RoomPlayer(
                          id: currentUser.uid,
                          name: currentUser.email ?? currentUser.uid,
                          isGuest: false,
                        );
                        Navigator.pop(context, p);
                      },
                      child: Text(
                          'Partecipa come ${currentUser.email ?? "me"}'),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                TextButton(
                  onPressed: () => setState(() {
                    isLoginMode = true;
                    error = null;
                  }),
                  child: const Text("Usa altro account"),
                ),

                const SizedBox(height: 16),
                const Divider(),

                const SizedBox(height: 12),

                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Guest',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),

                const SizedBox(height: 6),

                TextField(
                  controller: _guest,
                  decoration:
                  const InputDecoration(labelText: 'Nome'),
                ),

                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final name = _guest.text.trim();
                      if (name.isEmpty) {
                        setState(() =>
                        error = "Inserisci un nome per il guest");
                        return;
                      }
                      Navigator.pop(
                        context,
                        RoomPlayer(
                          id:
                          'guest_${DateTime.now().millisecondsSinceEpoch}',
                          name: name,
                          isGuest: true,
                        ),
                      );
                    },
                    child: const Text('Aggiungi Guest'),
                  ),
                ),
              ],

              // BLOCCO LOGIN (UI pulita)
              if (isLoginMode) ...[
                const SizedBox(height: 12),

                TextField(
                  controller: _email,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _pass,
                  obscureText: true,
                  decoration:
                  const InputDecoration(labelText: 'Password'),
                ),
                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: loading ? null : _handleSecondaryLogin,
                    child: loading
                        ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2),
                    )
                        : const Text('Accedi'),
                  ),
                ),

                const SizedBox(height: 8),

                TextButton(
                  onPressed: () => setState(() {
                    isLoginMode = false;
                    error = null;
                  }),
                  child: const Text('Annulla'),
                ),
              ],

              const SizedBox(height: 8),

              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Chiudi'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSecondaryLogin() async {
    if (_email.text.isEmpty || _pass.text.isEmpty) {
      setState(() => error = "Inserisci credenziali");
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final auth = await _getSecondaryAuth();
      final cred = await auth.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _pass.text.trim(),
      );

      if (cred.user != null) {
        final p = RoomPlayer(
          id: cred.user!.uid,
          name: cred.user!.email!,
          isGuest: false,
        );

        await auth.signOut();

        if (mounted) Navigator.pop(context, p);
      }
    } catch (_) {
      setState(() {
        error = "Credenziali non valide";
        loading = false;
      });
    }
  }
}