import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart' hide OverlayState;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../../../app/link/app_link_state.dart';
import '../../../../../app/router/home_shell_screen.dart';
import '../../../../../core/widgets/blocking_overlay.dart';
import '../../../domain/entities/match.dart';
import '../../../domain/entities/room.dart';
import '../../match/controllers/match_controller.dart';
import '../../match/pages/match_shell_page.dart';
import '../../result/pages/result_shell_page.dart';
import '../../shared/view_models/connection_badge_vm.dart';
import '../../shared/widgets/connection_badge.dart';
import '../controllers/lobby_controller.dart';
import '../controllers/player_order_controller.dart';

class RoomLobbyShellPage extends ConsumerStatefulWidget {
  const RoomLobbyShellPage({
    super.key,
    this.forceNewRoom = false,
  });

  final bool forceNewRoom;

  @override
  ConsumerState<RoomLobbyShellPage> createState() => _RoomLobbyShellPageState();
}

class _RoomLobbyShellPageState extends ConsumerState<RoomLobbyShellPage> {
  final TextEditingController _localGuestNameCtrl = TextEditingController();
  final TextEditingController _firebaseGuestEmailCtrl = TextEditingController();
  final TextEditingController _firebaseGuestPasswordCtrl = TextEditingController();

  bool _openingMatch = false;
  bool _openingResult = false;
  bool _isLeavingLobby = false;
  bool _bootstrapped = false;
  bool _authLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _bootstrapEntryPoint();
    });
  }

  @override
  void dispose() {
    _localGuestNameCtrl.dispose();
    _firebaseGuestEmailCtrl.dispose();
    _firebaseGuestPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrapEntryPoint() async {
    if (_bootstrapped || !mounted) return;
    _bootstrapped = true;

    final ctrl = ref.read(lobbyControllerProvider.notifier);

    // 1. DEEP LINK (priorità assoluta)
    final linkCoordinator = ref.read(appLinkCoordinatorProvider.notifier);
    final pendingWatchRoomId = await linkCoordinator.consumeWatchRoomId();
    final pendingRoomId = await linkCoordinator.consumeRoomId();

    if (pendingWatchRoomId != null && pendingWatchRoomId.isNotEmpty) {
      await ctrl.joinAsSpectator(pendingWatchRoomId);
    } else if (pendingRoomId != null && pendingRoomId.isNotEmpty) {
      await ctrl.joinFromLink(pendingRoomId);
    } else if (widget.forceNewRoom) {
      // 2. NUOVA ROOM FORZATA
      await ctrl.resetForNewRoom();
      await ctrl.initAsHost();
    } else {
      // 3. REJOIN (solo se NON nuova room)
      await ctrl.autoRejoinRoomIfNeeded();

      final currentRoomId = ref.read(lobbyControllerProvider).roomId;

      if (currentRoomId != null && currentRoomId.isNotEmpty) {
        await ctrl.joinFromLink(currentRoomId);
      } else {
        // 4. fallback
        await ctrl.initAsHost();
      }
    }

    final players = ref.read(lobbyControllerProvider).players;
    ref.read(playerOrderControllerProvider.notifier).syncFromLobby(players);

    final currentVm = ref.read(lobbyControllerProvider);
    final canPlayCurrentMatch =
        _isCurrentAuthAlreadyPlayer(currentVm) && !ctrl.isSpectator;

    await _openLiveMatchIfNeeded(currentVm, canPlayCurrentMatch);
    await _openResultIfNeeded(currentVm);
    await _exitIfRoomClosed(currentVm);
  }


  String? _currentAuthUid() {
    return FirebaseAuth.instance.currentUser?.uid;
  }

  String? _currentAuthEmail() {
    return FirebaseAuth.instance.currentUser?.email;
  }

  String? _currentAuthName() {
    return FirebaseAuth.instance.currentUser?.displayName;
  }

  String _hostId() {
    final hostId = ref.read(lobbyControllerProvider.notifier).hostId;
    return hostId ?? '';
  }

  bool _canControlAsAdmin(LobbyViewModel vm) {
    final authUid = _currentAuthUid();
    if (authUid == null) return false;

    if (vm.players.isEmpty) return false;

    final hostId = _hostId();

    return vm.players.any((p) =>
    (p.id == authUid || p.id == 'guest_ext_$authUid') &&
        (p.id == hostId || p.ownerUid == hostId));
  }

  String _adminControlLabel(LobbyViewModel vm) {
    final authUid = _currentAuthUid();
    if (authUid == null) return 'nessun accesso';

    if (vm.players.isEmpty) return 'nessun accesso';

    final hostId = _hostId();

    final me = vm.players.where((p) =>
    p.id == authUid || p.id == 'guest_ext_$authUid');

    if (me.isEmpty) return 'nessun accesso';

    final player = me.first;

    if (player.id == hostId) return 'admin';

    if (player.ownerUid == hostId) return 'proxy admin';

    return 'nessun accesso';
  }

  bool _isCurrentAuthAlreadyPlayer(LobbyViewModel vm) {
    final authUid = _currentAuthUid();
    if (authUid == null) return false;

    // 🔥 stesso utente se:
    // - è player diretto (id == authUid)
    // - è guest_ext collegato a lui
    return vm.players.any((p) =>
    p.id == authUid ||
        p.id == 'guest_ext_$authUid'
    );
  }
  String _playerTypeLabel(LobbyPlayerVm player, String hostId) {
    if (player.id == hostId) {
      return 'admin room';
    }
    if (player.isGuest && player.id.startsWith('guest_ext_')) {
      return 'guest con Firebase ID';
    }
    if (player.isGuest) {
      return 'guest locale senza ID';
    }
    return 'utente registrato';
  }

  Future<void> _participate() async {
    final ctrl = ref.read(lobbyControllerProvider.notifier);
    await ctrl.participateInRoom();
  }

  Future<void> _addLocalGuest() async {
    final ctrl = ref.read(lobbyControllerProvider.notifier);
    final orderCtrl = ref.read(playerOrderControllerProvider.notifier);

    final name = _localGuestNameCtrl.text.trim();
    if (name.isEmpty) {
      _showMessage('Inserisci un nome guest');
      return;
    }

    final player = await ctrl.buildLocalGuestVm(name);

    await orderCtrl.addPlayer(player);

    _localGuestNameCtrl.clear();
  }

  Future<void> _addFirebaseGuest({required bool createAccount}) async {
    final email = _firebaseGuestEmailCtrl.text.trim();
    final password = _firebaseGuestPasswordCtrl.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showMessage('Inserisci email e password');
      return;
    }

    setState(() {
      _authLoading = true;
    });

    try {
      final authData = await _authenticateWithRest(
        email: email,
        password: password,
        createAccount: createAccount,
      );

      final ctrl = ref.read(lobbyControllerProvider.notifier);
      final orderCtrl = ref.read(playerOrderControllerProvider.notifier);

      final localId = authData['localId'] as String?;
      final resolvedEmail = authData['email'] as String? ?? email;

      if (localId == null || localId.isEmpty) {
        _showMessage('Firebase non ha restituito un ID valido');
        return;
      }

      final player = await ctrl.buildExternalGuestVm(
        externalId: localId,
        email: resolvedEmail,
      );

      await orderCtrl.addPlayer(player);

      _firebaseGuestEmailCtrl.clear();
      _firebaseGuestPasswordCtrl.clear();
    } catch (e) {
      _showMessage(_mapFirebaseRestError('$e'));
    } finally {
      if (mounted) {
        setState(() {
          _authLoading = false;
        });
      }
    }
  }


  Future<Map<String, dynamic>> _authenticateWithRest({
    required String email,
    required String password,
    required bool createAccount,
  }) async {
    final apiKey = Firebase.app().options.apiKey;
    final endpoint = createAccount
        ? 'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$apiKey'
        : 'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$apiKey';

    final response = await http.post(
      Uri.parse(endpoint),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'returnSecureToken': true,
      }),
    );

    final json = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 400 || json['error'] != null) {
      final message = (json['error'] as Map<String, dynamic>?)?['message']?.toString() ?? 'AUTH_ERROR';
      throw Exception(message);
    }

    return json;
  }

  String _buildGuestNameFromEmail(String email) {
    final normalized = email.trim();
    if (normalized.isEmpty) return 'Utente registrato';
    final name = normalized.split('@').first.trim();
    if (name.isEmpty) return normalized;
    return name;
  }

  String _mapFirebaseRestError(String raw) {
    if (raw.contains('EMAIL_EXISTS')) return 'Email già registrata';
    if (raw.contains('EMAIL_NOT_FOUND')) return 'Email non trovata';
    if (raw.contains('INVALID_PASSWORD')) return 'Password non valida';
    if (raw.contains('INVALID_LOGIN_CREDENTIALS')) return 'Credenziali non valide';
    if (raw.contains('WEAK_PASSWORD')) return 'Password troppo debole';
    if (raw.contains('TOO_MANY_ATTEMPTS_TRY_LATER')) return 'Troppi tentativi. Riprova dopo';
    return 'Operazione Firebase fallita';
  }

  Future<void> _copyInviteLink() async {
    final ctrl = ref.read(lobbyControllerProvider.notifier);
    await ctrl.invite();
    final link = ref.read(lobbyControllerProvider).inviteLink;
    if (link == null || link.isEmpty) {
      _showMessage('Link invito non disponibile');
      return;
    }

    await Clipboard.setData(ClipboardData(text: link));
    _showMessage('Link invito copiato');
  }

  Future<void> _copyWatchLink() async {
    final ctrl = ref.read(lobbyControllerProvider.notifier);
    await ctrl.invite();
    final link = ref.read(lobbyControllerProvider).watchLink;
    if (link == null || link.isEmpty) {
      _showMessage('Link watch non disponibile');
      return;
    }

    await Clipboard.setData(ClipboardData(text: link));
    _showMessage('Link watch copiato');
  }

  Future<void> _startMatch(LobbyViewModel vm) async {
    final ctrl = ref.read(lobbyControllerProvider.notifier);
    final match = await ctrl.startMatch();

    if (match == null) {
      _showMessage('Impossibile avviare la partita');
      return;
    }

    if (!mounted) return;

    final isOnlineMatch = vm.roomId != null;

    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => MatchShellPage(
          match: match,
          isOnline: isOnlineMatch,
          canPlay: true,
        ),
      ),
    );
  }


  Future<void> _removePlayer(LobbyPlayerVm player) async {
    final lobbyCtrl = ref.read(lobbyControllerProvider.notifier);
    await lobbyCtrl.removePlayer(player.id);
  }

  Future<void> _closeRoomAndGoHome() async {
    if (_isLeavingLobby) return;
    _isLeavingLobby = true;

    final ctrl = ref.read(lobbyControllerProvider.notifier);
    final vm = ref.read(lobbyControllerProvider);

    if (_canControlAsAdmin(vm)) {
      await ctrl.closeRoom();
    } else {
      await ctrl.leaveRoom();
    }

    if (!mounted) return;
    _openingMatch = false;
    _openingResult = false;
    await Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const HomeScreen(
          initialSection: AppSection.gioca,
        ),
      ),
          (route) => false,
    );
  }


  Future<void> _openLiveMatchIfNeeded(LobbyViewModel next, bool canPlayCurrentMatch) async {
    if (!mounted || _openingMatch || _isLeavingLobby) return;
    if (next.roomState != RoomState.inMatch) return;
    if (next.loading == OverlayState.error) return;
    if (next.currentMatchId == null || next.currentMatchId!.isEmpty) return;

    _openingMatch = true;
    Match? match;

    if (next.roomId == null) {
      // locale → match già in memoria
      match = ref.read(matchControllerProvider)?.match;
    } else {
      match = await ref.read(lobbyControllerProvider.notifier).loadCurrentMatch();
    }

    if (!mounted) {
      _openingMatch = false;
      return;
    }

    if (match == null) {
      _showMessage('Partita non disponibile');
      _openingMatch = false;
      return;
    }

    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => MatchShellPage(
          match: match,
          isOnline: next.isOnline,
          canPlay: canPlayCurrentMatch,
        ),
      ),
    );

    _openingMatch = false;
  }

  Future<void> _openResultIfNeeded(LobbyViewModel next) async {
    if (!mounted || _openingResult) return;
    if (next.roomState != RoomState.finished) return;
    _openingResult = true;
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ResultShellPage()),
    );
    _openingResult = false;
  }

  Future<void> _exitIfRoomClosed(LobbyViewModel next) async {
    if (!mounted || _isLeavingLobby) return;
    if (next.roomState != RoomState.closed) return;

    _isLeavingLobby = true;

    if (!mounted) return;

    await Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const HomeScreen(
          initialSection: AppSection.gioca,
        ),
      ),
          (route) => false,
    );
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(lobbyControllerProvider);

    final ctrl = ref.read(lobbyControllerProvider.notifier);
    final orderState = ref.watch(playerOrderControllerProvider);
    final orderCtrl = ref.read(playerOrderControllerProvider.notifier);

    final options = orderCtrl.computeValidTeamSizes(orderState.ordered.length);
    final selectedTeamSize =
    options.contains(orderState.teamSize) ? orderState.teamSize : 1;

    if (!options.contains(orderState.teamSize)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(playerOrderControllerProvider.notifier).setTeamMode(1);
      });
    }    final authUid = _currentAuthUid();
    final authEmail = _currentAuthEmail();
    final authName = _currentAuthName();
    final hostId = _hostId();
    final hasAdminControl = ctrl.canCurrentAuthControlAsAdmin;
    final isPlayer = _isCurrentAuthAlreadyPlayer(vm);
    final isSpectator = ctrl.isSpectator;
    final isFull = vm.players.length >= 8;
    final canPlayCurrentMatch = isPlayer && !ctrl.isSpectator;
    ref.listen<LobbyViewModel>(lobbyControllerProvider, (prev, next) {
      _openLiveMatchIfNeeded(next, canPlayCurrentMatch);
      _openResultIfNeeded(next);
      _exitIfRoomClosed(next);
    });

    final canStartMatch = vm.canStart && hasAdminControl;

    return WillPopScope(
      onWillPop: () async {
        await _closeRoomAndGoHome();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Room Lobby Test'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _closeRoomAndGoHome,
          ),
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
                  _SectionCard(
                    title: 'Stato attuale',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _InfoRow(label: 'Auth UID app', value: authUid ?? 'nessun utente autenticato'),
                        _InfoRow(label: 'Auth email app', value: authEmail ?? '-'),
                        _InfoRow(label: 'Auth nome app', value: authName ?? '-'),
                        _InfoRow(label: 'Admin room', value: hostId.isEmpty ? '-' : hostId),
                        _InfoRow(label: 'Auth controlla admin', value: hasAdminControl ? 'si' : 'no'),
                        _InfoRow(label: 'Room state', value: vm.roomState.name),
                        _InfoRow(label: 'Online', value: vm.isOnline ? 'online' : 'offline'),
                        _InfoRow(label: 'Ruolo attuale', value: isSpectator ? 'Watcher (Sola lettura)' : (isPlayer ? 'Giocatore' : 'Visitatore')),
                        _InfoRow(label: 'Posti occupati', value: '${vm.players.length} / 8'),
                        _InfoRow(label: 'Modalità test', value: '501'),
                        _InfoRow(
                          label: 'Room ID',
                          value: vm.roomId ?? '-',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: 'Azioni room',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: (authUid != null && !isPlayer && !isFull)
                              ? _participate
                              : null,
                          icon: const Icon(Icons.login),
                          label: Text(isFull ? 'Stanza Piena' : 'Partecipa'),
                        ),
                        FilledButton.icon(
                          onPressed: _copyInviteLink,
                          icon: const Icon(Icons.share),
                          label: const Text('Invita'),
                        ),
                        FilledButton.icon(
                          onPressed: _copyWatchLink,
                          icon: const Icon(Icons.visibility),
                          label: const Text('Invita a guardare'),
                        ),
                        FilledButton.icon(
                          onPressed: canStartMatch ? () => _startMatch(vm) : null,
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Inizia'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: 'Admin Test',
                    child: Builder(
                      builder: (context) {
                        final canControl = _canControlAsAdmin(vm);
                        final label = _adminControlLabel(vm);

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FilledButton(
                              onPressed: canControl
                                  ? () {
                                _showMessage('BTN cliccato da: $label');
                              }
                                  : null,
                              child: const Text('Test Admin Action'),
                            ),
                            const SizedBox(height: 8),
                            Text('Stato: $label'),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: 'Aggiungi guest locale',
                    child: Column(
                      children: [
                        TextField(
                          controller: _localGuestNameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Nome guest locale',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: FilledButton.icon(
                            onPressed: isPlayer && !isFull ? _addLocalGuest : null,                            icon: const Icon(Icons.person_add),
                            label: const Text('Aggiungi'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: 'Aggiungi guest con Firebase ID',
                    child: Column(
                      children: [
                        TextField(
                          controller: _firebaseGuestEmailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _firebaseGuestPasswordCtrl,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton(
                              onPressed: isPlayer && !isFull && !_authLoading
                                  ? () => _addFirebaseGuest(createAccount: false)
                                  : null,
                              child: const Text('Login e aggiungi'),
                            ),
                            OutlinedButton(
                              onPressed: isPlayer && !isFull && !_authLoading
                                  ? () => _addFirebaseGuest(createAccount: true)
                                  : null,
                              child: const Text('Registra e aggiungi'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: 'Link room',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SelectableText('JOIN: ${vm.inviteLink ?? '-'}'),
                        const SizedBox(height: 8),
                        SelectableText('WATCH: ${vm.watchLink ?? '-'}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: 'Giocatori room',
                    child: Builder(
                      builder: (context) {
                        final flat = ref.watch(playerOrderControllerProvider).ordered;

                        return Column(
                          children: [
                            Row(
                              children: [
                                const Text("Gioca a team"),
                                const SizedBox(width: 12),
                                DropdownButton<int>(
                                  value: selectedTeamSize,
                                  items: options.map((size) {
                                    final label = size == 1
                                        ? "Singolo"
                                        : List.filled(orderState.ordered.length ~/ size, '$size').join('v');                                    return DropdownMenuItem(
                                      value: size,
                                      child: Text(label),
                                    );
                                  }).toList(),
                                  onChanged: (value) async {
                                    if (value == null) return;

                                    final vm = ref.read(lobbyControllerProvider);
                                    if (!_canControlAsAdmin(vm)) return;

                                    await orderCtrl.setTeamMode(value);
                                  },
                                ),
                              ],
                            ),
                            ReorderableListView(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              onReorder: (oldIndex, newIndex) async {
                                final vm = ref.read(lobbyControllerProvider);
                                if (!_canControlAsAdmin(vm)) return;

                                final orderCtrl = ref.read(playerOrderControllerProvider.notifier);

                                // Applichiamo il reorder
                                await orderCtrl.reorderLocal(oldIndex, newIndex);

                                // Se siamo offline, aggiorniamo manualmente il controller della lobby
                                if (vm.roomId == null) {
                                  ref.read(lobbyControllerProvider.notifier).updateConfig();
                                }
                              },
                              children: [
                                for (final player in flat)
                                  _PlayerTile(
                                    key: ValueKey(player.id),
                                    player: player,
                                    hostId: hostId,
                                    typeLabel: _playerTypeLabel(player, hostId),
                                    canRemove: player.id != hostId,
                                    onRemove: () => _removePlayer(player),
                                  ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ),
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
                  primaryActionLabel: vm.loading == OverlayState.error ? 'OK' : null,
                  onPrimaryAction: vm.loading == OverlayState.error ? _hardResetAndRestart : null,
                ),
              ),
            if (_authLoading)
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0x55000000),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
      ),
    );
  }
  Future<void> _hardResetAndRestart() async {
    if (_isLeavingLobby) return;
    _isLeavingLobby = true;

    final lobbyCtrl = ref.read(lobbyControllerProvider.notifier);
    final linkCtrl = ref.read(appLinkCoordinatorProvider.notifier);

    try {
      // 1. lascia qualsiasi room
      await lobbyCtrl.leaveRoom().catchError((_) {});

      // 2. reset stato lobby
      await lobbyCtrl.resetForNewRoom();

      // 3. pulisci deep link pendenti
      await linkCtrl.clearAll();

    } catch (_) {}

    if (!mounted) return;

    // 4. riparti pulito
    await Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const RoomLobbyShellPage(forceNewRoom: true),
      ),
          (route) => false,
    );
  }

}
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _PlayerTile extends ConsumerWidget {
  const _PlayerTile({
    Key? key,
    required this.player,
    required this.hostId,
    required this.typeLabel,
    required this.canRemove,
    required this.onRemove,
  }) : super(key: key);

  final LobbyPlayerVm player;
  final String hostId;
  final String typeLabel;
  final bool canRemove;
  final Future<void> Function() onRemove;

  bool _canControlAsAdminLocal(WidgetRef ref) {
    final vm = ref.read(lobbyControllerProvider);
    final authUid = FirebaseAuth.instance.currentUser?.uid;

    if (authUid == null) return false;
    if (vm.players.isEmpty) return false;

    final hostId = ref.read(lobbyControllerProvider.notifier).hostId ?? '';

    return vm.players.any((p) =>
    (p.id == authUid || p.id == 'guest_ext_$authUid') &&
        (p.id == hostId || p.ownerUid == hostId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = player.id == hostId;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(player.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ID: ${player.id}'),
            Text('Tipo: $typeLabel'),
            Text('Creatore: ${player.ownerUid ?? '-'}'),
            Text('Connessione: ${player.connection.name}'),
            Text('Team: ${player.teamId ?? "Solo"}'),
          ],
        ),
        trailing: isAdmin
            ? const Icon(Icons.shield, size: 20)
            : IconButton(
          icon: const Icon(Icons.close),
          onPressed: canRemove
              ? () async {
            final lobbyCtrl =
            ref.read(lobbyControllerProvider.notifier);

            final authUid = lobbyCtrl.authUid;

            final vm = ref.read(lobbyControllerProvider);

            final canRemovePlayer =
                _canControlAsAdminLocal(ref) ||
                    player.ownerUid == authUid ||
                    player.id == authUid ||
                    player.id == 'guest_ext_$authUid';

            if (!canRemovePlayer) return;
            await onRemove();
          }
              : null,
        ),
      ),
    );
  }
}
