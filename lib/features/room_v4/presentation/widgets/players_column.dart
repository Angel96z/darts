import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/room_notifier.dart';
import 'player_list.dart';
import 'team_selector.dart';

class PlayersColumn extends ConsumerWidget {
  final WidgetRef ref;

  const PlayersColumn({required this.ref, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(roomNotifierProvider);
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        /// HEADER SEZIONE
        Row(
          children: [
            Icon(Icons.people_outline, size: 17, color: cs.primary),
            const SizedBox(width: 8),
            Text(
              'Giocatori',
              style: text.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(width: 8),
            _CountBadge(value: state.players.length),
            const Spacer(),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 116),
              child: TeamSelector(ref: ref),
            ),
            const SizedBox(width: 8),
            _AddPlayerButton(ref: ref),
          ],
        ),

        const SizedBox(height: 12),

        /// LISTA
        if (state.players.isNotEmpty)
          PlayerList(
            players: state.players,
            isTeamMode: state.teamSize > 1,
            teamSize: state.teamSize,
          )
        else
          const _EmptyState(),
      ],
    );
  }
}

/// ─────────────────────────────────────────────
/// BADGE COUNT
/// ─────────────────────────────────────────────

class _CountBadge extends StatelessWidget {
  final int value;

  const _CountBadge({required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: cs.primary.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.primary.withOpacity(0.25)),
      ),
      child: Text(
        '$value',
        style: TextStyle(
          fontSize: 12,
          height: 1,
          fontWeight: FontWeight.w900,
          color: cs.primary,
        ),
      ),
    );
  }
}

/// ─────────────────────────────────────────────
/// EMPTY STATE
/// ─────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.45)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.person_add_alt_1_outlined,
            size: 34,
            color: cs.onSurfaceVariant.withOpacity(0.55),
          ),
          const SizedBox(height: 8),
          Text(
            'Nessun giocatore',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Aggiungi un giocatore o un guest',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: cs.onSurfaceVariant.withOpacity(0.65),
            ),
          ),
        ],
      ),
    );
  }
}

/// ─────────────────────────────────────────────
/// ADD BUTTON
/// ─────────────────────────────────────────────

class _AddPlayerButton extends ConsumerWidget {
  final WidgetRef ref;

  const _AddPlayerButton({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      height: 34,
      child: FilledButton.icon(
        onPressed: () => _onAddPlayer(context, ref),
        icon: const Icon(Icons.add, size: 16),
        label: const Text('Aggiungi'),
        style: FilledButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9),
          ),
          textStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  void _onAddPlayer(BuildContext context, WidgetRef ref) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? 'local';

    final player = await _showAddPlayerDialog(context, currentUserId);

    if (player != null && context.mounted) {
      ref.read(roomNotifierProvider.notifier).addPlayer(
        player.$1,
        player.$2,
        player.$3,
      );
    }
  }

  Future<(String, String, bool)?> _showAddPlayerDialog(
      BuildContext context,
      String currentUserId,
      ) async {
    final container = ProviderScope.containerOf(context);
    final state = container.read(roomNotifierProvider);

    bool isLoading = false;
    String? error;

    final currentUser = FirebaseAuth.instance.currentUser;
    final alreadyInList = currentUser != null &&
        state.players.any((p) => p.id == currentUser.uid);
    final canUseCurrentUser = currentUser != null && !alreadyInList;
    _AddPlayerMode mode = canUseCurrentUser ? _AddPlayerMode.current : _AddPlayerMode.guest;

    final result = await showDialog<(String, String, bool)>(
      context: context,
      barrierDismissible: !isLoading,
      useSafeArea: false,
      builder: (context) {
        // Controller creati DENTRO il builder
        final emailController = TextEditingController();
        final passwordController = TextEditingController();
        final guestController = TextEditingController();

        return StatefulBuilder(
          builder: (context, setState) {
            final cs = Theme.of(context).colorScheme;
            final mq = MediaQuery.of(context);
            final bottomInset = mq.viewInsets.bottom > 0 ? mq.viewInsets.bottom + 12 : 16.0;

            return AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.fromLTRB(14, 16, 14, bottomInset),
              child: Center(
                child: Material(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(18),
                  clipBehavior: Clip.antiAlias,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: 440,
                      maxHeight: mq.size.height - mq.viewInsets.bottom - 32,
                    ),
                    child: SingleChildScrollView(
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _DialogHeader(
                            onClose: isLoading ? null : () => Navigator.pop(context),
                          ),
                          const SizedBox(height: 14),
                          _ModeTabs(
                            value: mode,
                            showCurrentUser: canUseCurrentUser,
                            onChanged: (v) {
                              setState(() {
                                mode = v;
                                error = null;
                              });
                            },
                          ),
                          if (error != null) ...[
                            const SizedBox(height: 12),
                            _ErrorBox(text: error!),
                          ],
                          const SizedBox(height: 14),
                          if (mode == _AddPlayerMode.current && canUseCurrentUser)
                            _CurrentUserPane(
                              currentUser: currentUser,
                              onConfirm: () {
                                Navigator.pop(context, (
                                currentUser.uid,
                                currentUser.email ?? currentUser.displayName ?? currentUser.uid,
                                false,
                                ));
                              },
                            ),
                          if (mode == _AddPlayerMode.guest)
                            _GuestPane(
                              controller: guestController,
                              onSubmit: () {
                                final name = guestController.text.trim();
                                if (name.isEmpty) {
                                  setState(() => error = 'Inserisci un nome');
                                  return;
                                }
                                Navigator.pop(context, (
                                'guest_${DateTime.now().millisecondsSinceEpoch}',
                                name,
                                true,
                                ));
                              },
                            ),
                          if (mode == _AddPlayerMode.login)
                            _LoginPane(
                              emailController: emailController,
                              passwordController: passwordController,
                              isLoading: isLoading,
                              onLogin: () async {
                                setState(() {
                                  isLoading = true;
                                  error = null;
                                });
                                try {
                                  const name = 'secondary';
                                  FirebaseApp app;
                                  try {
                                    app = await Firebase.initializeApp(
                                      name: name,
                                      options: Firebase.app().options,
                                    );
                                  } catch (_) {
                                    app = Firebase.app(name);
                                  }
                                  final auth = FirebaseAuth.instanceFor(app: app);
                                  final cred = await auth.signInWithEmailAndPassword(
                                    email: emailController.text.trim(),
                                    password: passwordController.text.trim(),
                                  );
                                  if (cred.user != null && context.mounted) {
                                    await auth.signOut();
                                    Navigator.pop(context, (
                                    cred.user!.uid,
                                    cred.user!.email ?? cred.user!.displayName ?? cred.user!.uid,
                                    false,
                                    ));
                                  }
                                } catch (_) {
                                  setState(() {
                                    error = 'Credenziali non valide';
                                    isLoading = false;
                                  });
                                }
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    return result;
  }
}

/// ─────────────────────────────────────────────
/// DIALOG UI
/// ─────────────────────────────────────────────

enum _AddPlayerMode {
  current,
  guest,
  login,
}

class _DialogHeader extends StatelessWidget {
  final VoidCallback? onClose;

  const _DialogHeader({required this.onClose});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: cs.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.person_add_alt_1_outlined,
            size: 18,
            color: cs.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Aggiungi giocatore',
            style: TextStyle(
              fontSize: 17,
              height: 1,
              fontWeight: FontWeight.w900,
              color: cs.onSurface,
            ),
          ),
        ),
        IconButton(
          onPressed: onClose,
          icon: Icon(
            Icons.close,
            size: 18,
            color: cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ModeTabs extends StatelessWidget {
  final _AddPlayerMode value;
  final bool showCurrentUser;
  final ValueChanged<_AddPlayerMode> onChanged;

  const _ModeTabs({
    required this.value,
    required this.showCurrentUser,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final items = <_TabData>[
      if (showCurrentUser)
        const _TabData(
          mode: _AddPlayerMode.current,
          label: 'Account',
          icon: Icons.verified_user_outlined,
        ),
      const _TabData(
        mode: _AddPlayerMode.guest,
        label: 'Guest',
        icon: Icons.person_outline,
      ),
      const _TabData(
        mode: _AddPlayerMode.login,
        label: 'Login',
        icon: Icons.login,
      ),
    ];

    return Row(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          Expanded(
            child: _ModeTab(
              data: items[i],
              selected: value == items[i].mode,
              onTap: () => onChanged(items[i].mode),
            ),
          ),
          if (i != items.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _TabData {
  final _AddPlayerMode mode;
  final String label;
  final IconData icon;

  const _TabData({
    required this.mode,
    required this.label,
    required this.icon,
  });
}

class _ModeTab extends StatelessWidget {
  final _TabData data;
  final bool selected;
  final VoidCallback onTap;

  const _ModeTab({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        constraints: const BoxConstraints(minHeight: 38),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? cs.primary.withOpacity(0.13)
              : cs.surfaceContainerHighest.withOpacity(0.26),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? cs.primary.withOpacity(0.75) : cs.outlineVariant,
            width: selected ? 1.2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              data.icon,
              size: 15,
              color: selected ? cs.primary : cs.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                data.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  height: 1,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                  color: selected ? cs.primary : cs.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String text;

  const _ErrorBox({required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: cs.error.withOpacity(0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.error.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 16, color: cs.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: cs.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrentUserPane extends StatelessWidget {
  final User currentUser;
  final VoidCallback onConfirm;

  const _CurrentUserPane({
    required this.currentUser,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final label = currentUser.displayName ??
        currentUser.email ??
        currentUser.uid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _InfoLine(
          icon: Icons.account_circle_outlined,
          title: 'Partecipa con account attuale',
          subtitle: label,
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: onConfirm,
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 42),
            backgroundColor: cs.primary,
            foregroundColor: cs.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text(
            'Partecipa',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}

class _GuestPane extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSubmit;

  const _GuestPane({
    required this.controller,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _InfoLine(
          icon: Icons.person_outline,
          title: 'Guest locale',
          subtitle: 'Inserisci solo il nome. Nessun login richiesto.',
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onSubmit(),
          decoration: const InputDecoration(
            hintText: 'Nome giocatore',
            prefixIcon: Icon(Icons.badge_outlined),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 42,
          width: double.infinity,
          child: OutlinedButton(
            onPressed: onSubmit,
            child: const Text(
              'Aggiungi Guest',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ],
    );
  }
}

class _LoginPane extends StatelessWidget {
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool isLoading;
  final VoidCallback onLogin;

  const _LoginPane({
    required this.emailController,
    required this.passwordController,
    required this.isLoading,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _InfoLine(
          icon: Icons.login,
          title: 'Altro account',
          subtitle: 'Accedi senza cambiare l’utente principale della app.',
        ),
        const SizedBox(height: 12),
        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            hintText: 'Email',
            prefixIcon: Icon(Icons.email_outlined),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: passwordController,
          obscureText: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) {
            if (!isLoading) onLogin();
          },
          decoration: const InputDecoration(
            hintText: 'Password',
            prefixIcon: Icon(Icons.lock_outline),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 42,
          width: double.infinity,
          child: FilledButton(
            onPressed: isLoading ? null : onLogin,
            style: FilledButton.styleFrom(
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: isLoading
                ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: cs.onPrimary,
              ),
            )
                : const Text(
              'Accedi e aggiungi',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _InfoLine({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: cs.onSurfaceVariant),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.25,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}