import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

/// MODEL PLAYER
class RoomPlayer {
  final String id;
  final String name;
  final bool isGuest;

  const RoomPlayer({required this.id, required this.name, required this.isGuest});

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'isGuest': isGuest};
}

/// ISTANZA ISOLATA PER LOGIN SENZA LOGOUT
Future<FirebaseAuth> _getSecondaryAuth() async {
  const String name = 'secondary';
  FirebaseApp app;
  try {
    app = Firebase.app(name);
  } catch (_) {
    app = await Firebase.initializeApp(name: name, options: Firebase.app().options);
  }
  return FirebaseAuth.instanceFor(app: app);
}

class RoomPlayersView extends StatelessWidget {
  final List<Map<String, dynamic>> players;
  final Function(RoomPlayer) onAddPlayer;

  const RoomPlayersView({super.key, required this.players, required this.onAddPlayer});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('GIOCATORI', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...players.map((p) => ListTile(
          leading: Icon(p['isGuest'] ? Icons.person_outline : Icons.verified),
          title: Text(p['name']),
          subtitle: Text(p['id'], style: const TextStyle(fontSize: 10)),
        )),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: () => _showAddDialog(context),
          icon: const Icon(Icons.person_add),
          label: const Text('Aggiungi giocatore'),
        ),
      ],
    );
  }

  void _showAddDialog(BuildContext context) async {
    final player = await showDialog<RoomPlayer>(
      context: context,
      builder: (_) => const _AddPlayerOverlay(),
    );
    if (player != null) onAddPlayer(player);
  }
}

class _AddPlayerOverlay extends StatefulWidget {
  const _AddPlayerOverlay();
  @override
  State<_AddPlayerOverlay> createState() => _AddPlayerOverlayState();
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
    // Recuperiamo l'utente attualmente loggato nell'app principale
    final currentUser = FirebaseAuth.instance.currentUser;

    return AlertDialog(
      title: const Text('Aggiungi player'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.red, fontSize: 13)),

            /// 1. MODALITÀ: PARTECIPA COME UTENTE ATTUALE
            if (currentUser != null && !isLoginMode) ...[
              const SizedBox(height: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade50),
                onPressed: () {
                  final p = RoomPlayer(
                    id: currentUser.uid,
                    name: currentUser.email ?? currentUser.uid,
                    isGuest: false,
                  );
                  Navigator.pop(context, p);
                },
                child: Text('Partecipa come ${currentUser.email ?? "me"}'),
              ),
              const SizedBox(height: 16),
            ],

            /// SWITCH PER ALTRO ACCOUNT
            TextButton(
              onPressed: () => setState(() {
                isLoginMode = !isLoginMode;
                error = null;
              }),
              child: Text(isLoginMode ? "Torna indietro" : "Accedi con altro account"),
            ),

            /// 2. MODALITÀ: LOGIN ISOLATO (SECONDARY AUTH)
            if (isLoginMode) ...[
              TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email')),
              TextField(controller: _pass, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: loading ? null : _handleSecondaryLogin,
                child: loading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Verifica login'),
              ),
            ],

            const Divider(height: 32),

            /// 3. MODALITÀ: GUEST
            const Text("Oppure aggiungi un ospite", style: TextStyle(fontSize: 12, color: Colors.grey)),
            TextField(
              controller: _guest,
              decoration: const InputDecoration(labelText: 'Nome guest'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                final name = _guest.text.trim();
                if (name.isEmpty) {
                  setState(() => error = "Inserisci un nome per il guest");
                  return;
                }
                Navigator.pop(context, RoomPlayer(
                  id: 'guest_${DateTime.now().millisecondsSinceEpoch}',
                  name: name,
                  isGuest: true,
                ));
              },
              child: const Text('Aggiungi Guest'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Chiudi')),
      ],
    );
  }

  Future<void> _handleSecondaryLogin() async {
    if (_email.text.isEmpty || _pass.text.isEmpty) {
      setState(() => error = "Inserisci credenziali");
      return;
    }

    setState(() { loading = true; error = null; });
    try {
      final auth = await _getSecondaryAuth();
      final cred = await auth.signInWithEmailAndPassword(
          email: _email.text.trim(),
          password: _pass.text.trim()
      );

      if (cred.user != null) {
        final p = RoomPlayer(
            id: cred.user!.uid,
            name: cred.user!.email!,
            isGuest: false
        );
        // Fondamentale: slogghiamo l'istanza secondaria subito
        await auth.signOut();
        if (mounted) Navigator.pop(context, p);
      }
    } catch (e) {
      setState(() {
        error = "Credenziali non valide";
        loading = false;
      });
    }
  }
}