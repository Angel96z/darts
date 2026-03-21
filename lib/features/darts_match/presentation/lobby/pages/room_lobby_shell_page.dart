import 'package:flutter/material.dart' hide OverlayState;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/widgets/blocking_overlay.dart';
import '../../../domain/entities/match.dart';
import '../../match/pages/match_shell_page.dart';
import '../../../../players/presentation/pages/login_screen.dart';
import '../../shared/view_models/connection_badge_vm.dart';
import '../../shared/widgets/connection_badge.dart';
import '../controllers/lobby_controller.dart';
import 'guest_login_screen.dart';

class RoomLobbyShellPage extends ConsumerWidget {
  const RoomLobbyShellPage({super.key});

  Future<void> _showAddGuest(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aggiungi giocatore locale'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Nome')),
            const SizedBox(height: 12),
            const Row(
              children: [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('oppure'),
                ),
                Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () async {
                final result = await Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute(builder: (_) => const GuestLoginScreen()),
                );

                if (result != null) {
                  await ref.read(lobbyControllerProvider.notifier).addGuestFromExternalAuth(
                    externalId: result.uid,
                    name: result.name ?? '',
                    email: result.email,
                  );
                }

                if (context.mounted) Navigator.pop(context);

              },
              child: const Text('Accedi'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
          FilledButton(
            onPressed: () async {
              await ref.read(lobbyControllerProvider.notifier).addLocalGuest(ctrl.text);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Aggiungi'),
          ),
        ],
      ),
    );
  }

  Future<void> _showJoinOverlay(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    await showDialog<void>(
      barrierDismissible: false,
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Entra nella room'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: () async {
                final result = await Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute(builder: (_) => const GuestLoginScreen()),
                );

                if (result != null) {
                  await ref.read(lobbyControllerProvider.notifier).addGuestFromExternalAuth(
                    externalId: result.uid,
                    name: result.name ?? '',
                    email: result.email,
                  );
                }

                if (context.mounted) Navigator.pop(context);

              },
              child: const Text('Login / Registrazione'),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(lobbyControllerProvider.notifier);
    final vm = ref.watch(lobbyControllerProvider);
    final canInvite = vm.isOnline;
    return WillPopScope(
      onWillPop: () async {
        final ctrl = ref.watch(lobbyControllerProvider.notifier);
        final isHost = ctrl.hostId == ctrl.currentPlayerId;
        if (!isHost) return true;

        final confirm = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Chiudere la room?'),
            content: const Text('Tutti i giocatori verranno espulsi'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Si')),
            ],
          ),
        );

        if (confirm == true) {
          await ctrl.closeRoom();
          return true;
        }

        return false;

      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Room Lobby'),
          actions: [
            ConnectionBadge(
              vm: ConnectionBadgeVm(isOnline: vm.isOnline),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Stack(
          children: [
            SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text('Config match', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'X01', label: Text('X01')),
                      ButtonSegment(value: 'Cricket', label: Text('Cricket')),
                      ButtonSegment(value: 'High Score', label: Text('High Score')),
                    ],
                    selected: {vm.config.gameType},
                    onSelectionChanged: (v) {
                      ref.read(lobbyControllerProvider.notifier).updateConfig(gameType: v.first);
                    },
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<X01Variant>(
                    initialValue: vm.config.variant,
                    decoration: const InputDecoration(labelText: 'Variante X01'),
                    items: const [
                      DropdownMenuItem(value: X01Variant.x101, child: Text('101')),
                      DropdownMenuItem(value: X01Variant.x301, child: Text('301')),
                      DropdownMenuItem(value: X01Variant.x501, child: Text('501')),
                    ],
                    onChanged: (v) {
                      if (v != null) ref.read(lobbyControllerProvider.notifier).updateConfig(variant: v);
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<InMode>(
                          initialValue: vm.config.inMode,
                          decoration: const InputDecoration(labelText: 'In'),
                          items: const [
                            DropdownMenuItem(value: InMode.straightIn, child: Text('Straight In')),
                            DropdownMenuItem(value: InMode.doubleIn, child: Text('Double In')),
                          ],
                          onChanged: (v) {
                            if (v != null) ref.read(lobbyControllerProvider.notifier).updateConfig(inMode: v);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<OutMode>(
                          initialValue: vm.config.outMode,
                          decoration: const InputDecoration(labelText: 'Out'),
                          items: const [
                            DropdownMenuItem(value: OutMode.singleOut, child: Text('Single Out')),
                            DropdownMenuItem(value: OutMode.doubleOut, child: Text('Double Out')),
                            DropdownMenuItem(value: OutMode.masterOut, child: Text('Master Out')),
                          ],
                          onChanged: (v) {
                            if (v != null) ref.read(lobbyControllerProvider.notifier).updateConfig(outMode: v);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: vm.config.legs,
                          decoration: const InputDecoration(labelText: 'Legs'),
                          items: List.generate(5, (i) => i + 1)
                              .map((v) => DropdownMenuItem(value: v, child: Text('$v')))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) ref.read(lobbyControllerProvider.notifier).updateConfig(legs: v);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: vm.config.sets,
                          decoration: const InputDecoration(labelText: 'Sets'),
                          items: List.generate(5, (i) => i + 1)
                              .map((v) => DropdownMenuItem(value: v, child: Text('$v')))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) ref.read(lobbyControllerProvider.notifier).updateConfig(sets: v);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text('Giocatori', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  ...vm.players.map(
                        (p) => Card(
                      child: ListTile(
                        title: Text(p.name),
                        subtitle: Text('${p.isGuest ? 'guest' : 'registered'} • ${p.connection.name}'),
                        trailing: p.id == ctrl.hostId
                            ? null
                            : IconButton(
                          icon: const Icon(Icons.close),
                            onPressed: () async {
                              final isSelf = p.id == ctrl.currentPlayerId;

                              if (isSelf) {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Text('Uscire dalla room?'),
                                    content: const Text('Sicuro di voler uscire?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
                                      FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Si')),
                                    ],
                                  ),
                                );

                                if (confirm == true) {
                                  await ref.read(lobbyControllerProvider.notifier).leaveRoom();
                                  if (context.mounted) Navigator.pop(context);
                                }
                              } else {
                                await ref.read(lobbyControllerProvider.notifier).removePlayer(p.id);
                              }
                            }
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _showAddGuest(context, ref),
                        icon: const Icon(Icons.person_add),
                        label: const Text('Aggiungi giocatore locale'),
                      ),
                      FilledButton.icon(
                        onPressed: canInvite
                            ? () async {
                          await ref.read(lobbyControllerProvider.notifier).invite();
                          final link = ref.read(lobbyControllerProvider).inviteLink;
                          if (context.mounted && link != null) {
                            await Clipboard.setData(ClipboardData(text: link));
                          }
                        }
                            : null,
                        icon: const Icon(Icons.share),
                        label: const Text('Invita'),
                      ),
                      FilledButton.icon(
                        onPressed: vm.canStart && ctrl.currentPlayerId == ctrl.hostId
                            ? () async {
                          final match = await ctrl.startMatch();
                          if (context.mounted && match != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MatchShellPage(
                                  match: match,
                                  isOnline: vm.isOnline,
                                ),
                              ),
                            );
                          }
                        }
                            : null,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Start match'),
                      ),
                    ],
                  ),
                  if (vm.inviteLink != null) ...[
                    const SizedBox(height: 10),
                    SelectableText('Link: ${vm.inviteLink!}'),
                  ],
                ],
              ),
            ),
            if (vm.loading != null)
              Positioned.fill(
                child: BlockingOverlay(
                  state: OverlayState.loading,
                  message: 'Caricamento...',
                ),
              ),
          ],
        ),
      ),
    );
  }
}
