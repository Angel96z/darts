import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart' hide OverlayState;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/router/home_shell_screen.dart';
import '../../../../../core/widgets/blocking_overlay.dart';
import '../../../domain/entities/match.dart';
import '../../../domain/entities/room.dart';
import '../../match/pages/match_shell_page.dart';
import '../../../../players/presentation/pages/login_screen.dart';
import '../../shared/view_models/connection_badge_vm.dart';
import '../../shared/widgets/connection_badge.dart';
import '../controllers/lobby_controller.dart';
import 'guest_login_screen.dart';

class RoomLobbyShellPage extends ConsumerStatefulWidget {
  const RoomLobbyShellPage({super.key});

  @override
  ConsumerState<RoomLobbyShellPage> createState() => _RoomLobbyShellPageState();
}

class _RoomLobbyShellPageState extends ConsumerState<RoomLobbyShellPage> {
  bool _openingMatch = false;

  @override
  void initState() {
    super.initState();
    _debugEntry();
    _checkResumeRoom();
  }
  Future<void> _checkResumeRoom() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('user_rooms')
        .doc(uid)
        .get();

    final roomId = doc.data()?['roomId'];
    if (roomId == null) return;

    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Riprendere partita?'),
        content: Text('Room trovata: $roomId'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Si')),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(lobbyControllerProvider.notifier).joinFromLink(roomId);
    }
  }
  void _debugEntry() {
    final now = DateTime.now().toIso8601String();

    const deviceId = 'UNKNOWN_DEVICE';

    final user = FirebaseAuth.instance.currentUser;

    // ignore: avoid_print
    print('========== ROOM ENTRY DEBUG ==========');
    // ignore: avoid_print
    print('timestamp: $now');

    // ignore: avoid_print
    print('--- DEVICE ---');
    // ignore: avoid_print
    print('deviceId: $deviceId');

    // ignore: avoid_print
    print('--- AUTH ---');
    // ignore: avoid_print
    print('uid: ${user?.uid}');
    // ignore: avoid_print
    print('displayName: ${user?.displayName}');
    // ignore: avoid_print
    print('isAnonymous: ${user?.isAnonymous}');

    // ignore: avoid_print
    print('=====================================');
  }

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

  Future<void> _openLiveMatchIfNeeded(
    LobbyViewModel next,
    bool canPlayCurrentMatch,
  ) async {
    if (!mounted || _openingMatch) return;
    if (next.roomState != RoomState.inMatch) return;
    _openingMatch = true;
    final liveMatch =
        await ref.read(lobbyControllerProvider.notifier).loadCurrentMatch();
    if (mounted && liveMatch != null) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MatchShellPage(
            match: liveMatch,
            isOnline: next.isOnline,
            canPlay: canPlayCurrentMatch,
          ),
        ),
      );
    }
    _openingMatch = false;
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = ref.read(lobbyControllerProvider.notifier);
    final vm = ref.watch(lobbyControllerProvider);
    final isHost = ctrl.isCurrentUserHost;
    final uid = ctrl.currentPlayerId;

    final isPlayer = vm.players.any(
          (p) => p.id == uid || p.id == 'guest_ext_$uid',
    );

    final isAuthenticated = FirebaseAuth.instance.currentUser != null;
    final isSpectator = ctrl.isSpectator;
    final canPlayCurrentMatch = isPlayer && !isSpectator;

    ref.listen<LobbyViewModel>(lobbyControllerProvider, (prev, next) {
      _openLiveMatchIfNeeded(next, canPlayCurrentMatch);
    });

    final _debugOnceKey = 'room_vm_dump';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vm = ref.read(lobbyControllerProvider);
      final ctrl = ref.read(lobbyControllerProvider.notifier);
      final user = FirebaseAuth.instance.currentUser;
      final uid = ctrl.currentPlayerId;
      final now = DateTime.now().toIso8601String();

      // ignore: avoid_print
      print('========== ROOM VM DEBUG ==========');
      // ignore: avoid_print
      print('timestamp: $now');

      // ignore: avoid_print
      print('--- AUTH ---');
      // ignore: avoid_print
      print('uid: ${user?.uid}');
      // ignore: avoid_print
      print('isAnonymous: ${user?.isAnonymous}');

      // ignore: avoid_print
      print('--- ROOM ---');
      // ignore: avoid_print
      print('isOnline: ${vm.isOnline}');
      // ignore: avoid_print
      print('playersCount: ${vm.players.length}');
      // ignore: avoid_print
      print('canStart: ${vm.canStart}');
      // ignore: avoid_print
      print('inviteLink: ${vm.inviteLink}');
      // ignore: avoid_print
      print('watchLink: ${vm.watchLink}');

      // ignore: avoid_print
      print('--- CONFIG ---');
      // ignore: avoid_print
      print('gameType: ${vm.config.gameType}');
      // ignore: avoid_print
      print('variant: ${vm.config.variant}');
      // ignore: avoid_print
      print('inMode: ${vm.config.inMode}');
      // ignore: avoid_print
      print('outMode: ${vm.config.outMode}');
      // ignore: avoid_print
      print('legs: ${vm.config.legs}');
      // ignore: avoid_print
      print('sets: ${vm.config.sets}');

      // ignore: avoid_print
      print('--- PLAYERS ---');
      for (final p in vm.players) {
        final isHost = p.id == ctrl.hostId;
        final isSelf = p.id == ctrl.currentPlayerId;

        // ignore: avoid_print
        print(
          '${p.id} | ${p.name} | guest=${p.isGuest} | '
              'connection=${p.connection.name} | '
              'host=$isHost | self=$isSelf',
        );
      }

      // ignore: avoid_print
      print('=====================================');
    });
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
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Uscire dalla lobby?'),
                  content: const Text('Verranno rimossi anche i tuoi giocatori'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
                    FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Si')),
                  ],
                ),
              );

              if (confirm == true) {
                final ctrl = ref.read(lobbyControllerProvider.notifier);

                if (ctrl.isCurrentUserHost) {
                  await ctrl.closeRoom();
                } else {
                  await ctrl.leaveRoom();
                }

                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) => const HomeScreen(
                      initialSection: AppSection.gioca,
                    ),
                  ),
                      (route) => false,
                );
              }
            },
          ),
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
                  const Text(
                    'Config match',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),

                  if (isHost && !isSpectator) ...[
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'X01', label: Text('X01')),
                        ButtonSegment(value: 'Cricket', label: Text('Cricket')),
                        ButtonSegment(value: 'High Score', label: Text('High Score')),
                      ],
                      selected: {vm.config.gameType},
                      onSelectionChanged: (v) {
                        ref.read(lobbyControllerProvider.notifier)
                            .updateConfig(gameType: v.first);
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
                        if (v != null) {
                          ref.read(lobbyControllerProvider.notifier).updateConfig(variant: v);
                        }
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
                              if (v != null) {
                                ref.read(lobbyControllerProvider.notifier).updateConfig(inMode: v);
                              }
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
                              if (v != null) {
                                ref.read(lobbyControllerProvider.notifier).updateConfig(outMode: v);
                              }
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
                              if (v != null) {
                                ref.read(lobbyControllerProvider.notifier).updateConfig(legs: v);
                              }
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
                              if (v != null) {
                                ref.read(lobbyControllerProvider.notifier).updateConfig(sets: v);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Configurazione scelta dall’host',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _ConfigChip(label: 'Gioco', value: vm.config.gameType),
                                _ConfigChip(
                                  label: 'Variante',
                                  value: vm.config.variant == X01Variant.x101
                                      ? '101'
                                      : vm.config.variant == X01Variant.x301
                                      ? '301'
                                      : '501',
                                ),
                                _ConfigChip(
                                  label: 'In',
                                  value: vm.config.inMode == InMode.doubleIn
                                      ? 'Double In'
                                      : 'Straight In',
                                ),
                                _ConfigChip(
                                  label: 'Out',
                                  value: vm.config.outMode == OutMode.singleOut
                                      ? 'Single Out'
                                      : vm.config.outMode == OutMode.masterOut
                                      ? 'Master Out'
                                      : 'Double Out',
                                ),
                                _ConfigChip(label: 'Legs', value: '${vm.config.legs}'),
                                _ConfigChip(label: 'Sets', value: '${vm.config.sets}'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (!isSpectator && isAuthenticated && !isPlayer) ...[
                    FilledButton.icon(
                      onPressed: () async {
                        await ref.read(lobbyControllerProvider.notifier).participateInRoom();
                      },
                      icon: const Icon(Icons.login),
                      label: const Text('Partecipa'),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 20),
                  const Text('Giocatori', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  ...vm.players.map(
                        (p) => Card(
                      child: ListTile(
                        title: Text(p.name),
                        subtitle: Text('${p.isGuest ? 'guest' : 'registered'} • ${p.connection.name}'),
                        trailing: (p.id == ctrl.hostId)
                            ? null
                            : (!isSpectator && (ctrl.currentPlayerId == ctrl.hostId || p.ownerUid == uid))
                            ? IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () async {
                              final uid = ctrl.currentPlayerId;
                              final isSelf = p.id == uid || p.id == 'guest_ext_$uid';
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
                            },
                        )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (!isSpectator)
                        OutlinedButton.icon(
                          onPressed: isPlayer
                              ? () => _showAddGuest(context, ref)
                              : null,
                          icon: const Icon(Icons.person_add),
                          label: const Text('Aggiungi giocatore locale'),
                        ),
                      FilledButton.icon(
                        onPressed: canInvite
                            ? () async {
                          if (isSpectator) {
                            final link = vm.watchLink;
                            if (link != null) {
                              await Clipboard.setData(ClipboardData(text: link));
                            }
                          } else {
                            await ref.read(lobbyControllerProvider.notifier).invite();
                            final link = ref.read(lobbyControllerProvider).inviteLink;
                            if (link != null) {
                              await Clipboard.setData(ClipboardData(text: link));
                            }
                          }
                        }
                            : null,
                        icon: const Icon(Icons.share),
                        label: Text(isSpectator ? 'Copia link spettatore' : 'Invita'),
                      ),
                      if (!isSpectator)
                        FilledButton.icon(
                          onPressed: (vm.canStart && ctrl.currentPlayerId == ctrl.hostId)
                              ? () async {
                            final match = await ctrl.startMatch();
                            if (context.mounted && match != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MatchShellPage(
                                    match: match,
                                    isOnline: vm.isOnline,
                                    canPlay: true,
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
                    SelectableText('JOIN: ${vm.inviteLink!}'),
                  ],
                  if (vm.watchLink != null) ...[
                    const SizedBox(height: 10),
                    SelectableText('WATCH: ${vm.watchLink!}'),
                  ],
                ],
              ),
            ),
            if (vm.loading != null)
              Positioned.fill(
                child: BlockingOverlay(
                  state: vm.loading!,
                  message: vm.loading == OverlayState.error
                      ? 'Room chiusa o non disponibile'
                      : 'Caricamento...',
                  primaryActionLabel: 'OK',
                  onPrimaryAction: vm.loading == OverlayState.error
                      ? () async {
                    await ref.read(lobbyControllerProvider.notifier).leaveRoom();

                    if (!context.mounted) return;

                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (_) => const HomeScreen(
                          initialSection: AppSection.gioca,
                        ),
                      ),
                          (route) => false,
                    );
                  }
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
class _ConfigChip extends StatelessWidget {
  const _ConfigChip({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: RichText(
        text: TextSpan(
          style: DefaultTextStyle.of(context).style,
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}
