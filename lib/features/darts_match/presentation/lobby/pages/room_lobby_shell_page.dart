import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart' hide OverlayState;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../../../app/router/home_shell_screen.dart';
import '../../../../../core/widgets/blocking_overlay.dart';
import '../../../domain/entities/match.dart';
import '../../../domain/entities/room.dart';
import '../../match/pages/match_shell_page.dart';
import '../../shared/view_models/connection_badge_vm.dart';
import '../../shared/widgets/connection_badge.dart';
import '../controllers/lobby_controller.dart';
import '../controllers/player_order_controller.dart';

class RoomLobbyShellPage extends ConsumerStatefulWidget {
  const RoomLobbyShellPage({super.key});

  @override
  ConsumerState<RoomLobbyShellPage> createState() => _RoomLobbyShellPageState();
}

class _RoomLobbyShellPageState extends ConsumerState<RoomLobbyShellPage> {
  final TextEditingController _localGuestNameCtrl = TextEditingController();
  final TextEditingController _firebaseGuestEmailCtrl = TextEditingController();
  final TextEditingController _firebaseGuestPasswordCtrl = TextEditingController();

  bool _openingMatch = false;
  bool _bootstrapped = false;
  bool _authLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _bootstrapTestLobby();
    });
  }

  @override
  void dispose() {
    _localGuestNameCtrl.dispose();
    _firebaseGuestEmailCtrl.dispose();
    _firebaseGuestPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrapTestLobby() async {
    if (_bootstrapped || !mounted) return;
    _bootstrapped = true;

    final ctrl = ref.read(lobbyControllerProvider.notifier);

    await ctrl.initAsHost();
    final players = ref.read(lobbyControllerProvider).players;

    ref.read(playerOrderControllerProvider.notifier)
        .syncFromLobby(players);
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

  bool _isCurrentAuthHost() {
    final authUid = _currentAuthUid();
    final hostId = _hostId();
    return authUid != null && authUid == hostId;
  }

  bool _isCurrentAuthAlreadyPlayer(LobbyViewModel vm) {
    final authUid = _currentAuthUid();
    if (authUid == null) return false;

    return vm.players.any((p) =>
    p.ownerUid == authUid || // 🔥 vero identificatore
        p.id == authUid ||       // utente reale
        p.id == 'guest_ext_$authUid' // fallback vecchio
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
    final name = _localGuestNameCtrl.text.trim();
    if (name.isEmpty) {
      _showMessage('Inserisci un nome guest');
      return;
    }

    await ctrl.addLocalGuest(name);
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
      final localId = authData['localId'] as String?;
      final resolvedEmail = authData['email'] as String? ?? email;

      if (localId == null || localId.isEmpty) {
        _showMessage('Firebase non ha restituito un ID valido');
        return;
      }

      await ctrl.addGuestFromExternalAuth(
        externalId: localId,
        name: _buildGuestNameFromEmail(resolvedEmail),
        email: resolvedEmail,
      );

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
    if (!mounted || match == null) return;

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

  Future<void> _removePlayer(LobbyPlayerVm player) async {
    final ctrl = ref.read(lobbyControllerProvider.notifier);
    await ctrl.removePlayer(player.id);
  }

  Future<void> _closeRoomAndGoHome() async {
    final ctrl = ref.read(lobbyControllerProvider.notifier);

    if (_isCurrentAuthHost()) {
      await ctrl.closeRoom();
    } else {
      await ctrl.leaveRoom();
    }

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const HomeScreen(
          initialSection: AppSection.gioca,
        ),
      ),
          (route) => false,
    );
  }

  Future<void> _openLiveMatchIfNeeded(
      LobbyViewModel next,
      bool canPlayCurrentMatch,
      ) async {
    if (!mounted || _openingMatch) return;
    if (next.roomState != RoomState.inMatch) return;

    _openingMatch = true;
    final liveMatch = await ref.read(lobbyControllerProvider.notifier).loadCurrentMatch();

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
    final authUid = _currentAuthUid();
    final authEmail = _currentAuthEmail();
    final authName = _currentAuthName();
    final hostId = _hostId();
    final isHost = _isCurrentAuthHost();
    final isPlayer = _isCurrentAuthAlreadyPlayer(vm);
    final canPlayCurrentMatch = isPlayer && !ctrl.isSpectator;
    ref.listen<LobbyViewModel>(lobbyControllerProvider, (prev, next) {
      if (next.roomId != null) {
        ref.read(playerOrderControllerProvider.notifier)
            .syncFromLobby(next.players);
      }

      _openLiveMatchIfNeeded(next, canPlayCurrentMatch);
    });

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
                        _InfoRow(label: 'Auth è admin', value: isHost ? 'si' : 'no'),
                        _InfoRow(label: 'Room state', value: vm.roomState.name),
                        _InfoRow(label: 'Online', value: vm.isOnline ? 'online' : 'offline'),
                        _InfoRow(label: 'Modalità test', value: '501'),
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
                          onPressed: authUid == null || isPlayer ? null : _participate,
                          icon: const Icon(Icons.login),
                          label: const Text('Partecipa'),
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
                          onPressed: vm.canStart && isHost ? () => _startMatch(vm) : null,
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Inizia'),
                        ),
                      ],
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
                            onPressed: isPlayer ? _addLocalGuest : null,
                            icon: const Icon(Icons.person_add),
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
                              onPressed: isPlayer && !_authLoading
                                  ? () => _addFirebaseGuest(createAccount: false)
                                  : null,
                              child: const Text('Login e aggiungi'),
                            ),
                            OutlinedButton(
                              onPressed: isPlayer && !_authLoading
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
                                  value: orderState.teamSize,
                                  items: options.map((size) {
                                    final label = size == 1 ? "Singolo" : "${size}v${size}";
                                    return DropdownMenuItem(
                                      value: size,
                                      child: Text(label),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    if (value == null) return;
                                    orderCtrl.setTeamMode(value);
                                  },
                                ),
                              ],
                            ),
                            ReorderableListView(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              onReorder: (oldIndex, newIndex) async {
                                final orderCtrl = ref.read(playerOrderControllerProvider.notifier);
                                final lobby = ref.read(lobbyControllerProvider);

                                orderCtrl.reorderLocal(oldIndex, newIndex);

                                if (lobby.roomId != null) {
                                  await orderCtrl.commitOrder();
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
                  onPrimaryAction: vm.loading == OverlayState.error ? _closeRoomAndGoHome : null,
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

class _PlayerTile extends StatelessWidget {
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

  @override
  Widget build(BuildContext context) {
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
          onPressed: canRemove ? () => onRemove() : null,
        ),
      ),
    );
  }
}