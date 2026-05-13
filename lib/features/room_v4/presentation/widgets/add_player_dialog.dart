import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app_theme.dart';
import '../../../players/data/user_repository.dart';
import '../../application/room_notifier.dart';
import '../../bot/bot_level.dart';
import 'package:flutter/material.dart' show Colors; // assicura Colors disponibile
import '../../domain/models/player_info.dart';

enum AddPlayerMode { guest, login, bot }

Future<String> getBestDisplayName({String? email, String? displayName, String? uid}) async {
  // 1. Prova a leggere dal profilo Firestore (dati reali)
  if (uid != null && uid.trim().isNotEmpty) {
    try {
      final userRepo = UserRepository();
      final profile = await userRepo.fetchProfile(uid);
      if (profile != null) {
        // nickname → firstName → email local part → fallback
        if (profile.nickname.trim().isNotEmpty) return profile.nickname.trim();
        if (profile.firstName.trim().isNotEmpty) return profile.firstName.trim();
        if (profile.email.trim().isNotEmpty && profile.email.contains('@')) {
          return profile.email.split('@').first;
        }
      }
    } catch (e) {
      print("⚠️ Errore recupero profilo per $uid: $e");
    }
  }

  // 2. Fallback a displayName di Firebase Auth
  if (displayName != null && displayName.trim().isNotEmpty) {
    return displayName.trim();
  }

  // 3. Fallback a parte prima della @ nell'email
  if (email != null && email.trim().isNotEmpty && email.contains('@')) {
    return email.split('@').first;
  }

  // 4. Fallback finale
  return 'Giocatore';
}
Future<(String, String, bool)?> showAddPlayerDialog(
    BuildContext context,
    String currentUserId,
    ) async {
  final container = ProviderScope.containerOf(context);
  final state = container.read(roomNotifierProvider);
  final currentUser = FirebaseAuth.instance.currentUser;

  final canUseCurrentUser = currentUser != null &&
      state.players.every((p) => p.id != currentUser.uid);

  if (canUseCurrentUser) {
    final confirmed = await _showCurrentUserDialog(context, currentUser);
    if (confirmed == true) {
      final displayName = await getBestDisplayName(
        email: currentUser.email,
        displayName: currentUser.displayName,
        uid: currentUser.uid,
      );
      return (
      currentUser.uid,
      displayName,
      false,
      );
    }
  }

  await Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      opaque: true,
      barrierColor: null,
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) => const _AddPlayerPage(),
      transitionsBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );

        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -1),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
    ),
  );

  return null;
}

Future<bool?> _showCurrentUserDialog(BuildContext context, User user) {
  final t = AppTokens.of(context);

  return showDialog<bool>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: t.overlay,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: AppTokens.r16),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: t.accent.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person_rounded,
                size: 32,
                color: t.accent,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Join with your account?',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: t.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              user.email ?? user.displayName ?? 'User',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: t.accent,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('No'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Sì'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _AddPlayerPage extends ConsumerStatefulWidget {
  const _AddPlayerPage();

  @override
  ConsumerState<_AddPlayerPage> createState() => _AddPlayerPageState();
}

class _AddPlayerPageState extends ConsumerState<_AddPlayerPage> {
  AddPlayerMode _mode = AddPlayerMode.guest;

  static const double _keyboardGap = 10;

  void _addPlayer((String, String, bool) player) {
    ref.read(roomNotifierProvider.notifier).addPlayer(
      player.$1,
      player.$2,
      player.$3,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final state = ref.watch(roomNotifierProvider);
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    final hasKeyboard = keyboardHeight > 0;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: t.bg,
      body: SafeArea(
        bottom: false,
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.only(
            bottom: hasKeyboard ? keyboardHeight + _keyboardGap : 0,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SizedBox(
                height: constraints.maxHeight,
                child: Column(
                  children: [
                    _Header(onClose: () => Navigator.pop(context)),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 460),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _ModeSelector(
                                  selectedMode: _mode,
                                  onModeChanged: (mode) {
                                    FocusScope.of(context).unfocus();
                                    setState(() => _mode = mode);
                                  },
                                ),
                                const SizedBox(height: 18),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 160),
                                  switchInCurve: Curves.easeOut,
                                  switchOutCurve: Curves.easeIn,
                                  child: _mode == AddPlayerMode.guest
                                      ? _GuestForm(
                                    key: const ValueKey('guest'),
                                    onAdd: _addPlayer,
                                  )
                                      : _mode == AddPlayerMode.login
                                      ? _LoginForm(
                                    key: const ValueKey('login'),
                                    onAdd: _addPlayer,
                                  )
                                      : _BotForm(
                                    key: const ValueKey('bot'),
                                    onAdd: _addPlayer,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                _AddedPlayersStrip(
                                  players: state.players,
                                  onRemove: (playerId) => ref
                                      .read(roomNotifierProvider.notifier)
                                      .removePlayer(playerId),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onClose;

  const _Header({required this.onClose});

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: onClose,
            icon: Icon(
              Icons.keyboard_arrow_up_rounded,
              color: t.textPrimary,
              size: 28,
            ),
            style: IconButton.styleFrom(
              backgroundColor: t.surface,
              shape: RoundedRectangleBorder(
                borderRadius: AppTokens.r12,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Add players',
              style: TextStyle(
                color: t.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeSelector extends StatelessWidget {
  final AddPlayerMode selectedMode;
  final ValueChanged<AddPlayerMode> onModeChanged;

  const _ModeSelector({
    required this.selectedMode,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ModeChip(
          selected: selectedMode == AddPlayerMode.guest,
          label: 'Guest',
          icon: Icons.person_outline_rounded,
          onTap: () => onModeChanged(AddPlayerMode.guest),
        ),
        const SizedBox(width: 10),
        _ModeChip(
          selected: selectedMode == AddPlayerMode.login,
          label: 'Login',
          icon: Icons.login_rounded,
          onTap: () => onModeChanged(AddPlayerMode.login),
        ),
        const SizedBox(width: 10),
        _ModeChip(
          selected: selectedMode == AddPlayerMode.bot,
          label: 'Bot',
          icon: Icons.smart_toy_rounded,
          onTap: () => onModeChanged(AddPlayerMode.bot),
        ),
      ],
    );
  }
}
class _ModeChip extends StatelessWidget {
  final bool selected;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _ModeChip({
    required this.selected,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 46,
          decoration: BoxDecoration(
            color: selected ? t.accent.withOpacity(0.14) : t.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? t.accent : t.border,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color: selected ? t.accent : t.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: selected ? t.accent : t.textSecondary,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuestForm extends StatefulWidget {
  final void Function((String, String, bool) player) onAdd;

  const _GuestForm({
    required this.onAdd,
    super.key,
  });

  @override
  State<_GuestForm> createState() => _GuestFormState();
}

class _GuestFormState extends State<_GuestForm> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _submit() {
    final name = _controller.text.trim();

    if (name.isEmpty) {
      setState(() => _error = 'Inserisci un nome');
      return;
    }

    widget.onAdd((
    'guest_${DateTime.now().millisecondsSinceEpoch}',
    name,
    true,
    ));

    _controller.clear();
    setState(() => _error = null);
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          textInputAction: TextInputAction.done,
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            hintText: 'Name',
            prefixIcon: Icon(
              Icons.badge_rounded,
              color: t.textSecondary,
            ),
            errorText: _error,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 52,
          child: FilledButton(
            onPressed: _submit,
            style: FilledButton.styleFrom(
              backgroundColor: t.accent,
              foregroundColor: t.accentFg,
              shape: RoundedRectangleBorder(
                borderRadius: AppTokens.r16,
              ),
            ),
            child: const Text(
              'Add player',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LoginForm extends StatefulWidget {
  final void Function((String, String, bool) player) onAdd;

  const _LoginForm({
    required this.onAdd,
    super.key,
  });

  @override
  State<_LoginForm> createState() => _LoginFormState();
}
class _BotForm extends StatefulWidget {
  final void Function((String, String, bool) player) onAdd;

  const _BotForm({
    required this.onAdd,
    super.key,
  });

  @override
  State<_BotForm> createState() => _BotFormState();
}

class _BotFormState extends State<_BotForm> {
  BotLevel _selectedLevel = BotLevel.intermediate;
  bool _botAdded = false;

  void _addBot() {
    widget.onAdd((
    'bot_${_selectedLevel.name}_${DateTime.now().millisecondsSinceEpoch}',
    '🤖 ${_selectedLevel.displayName}',
    true,
    ));

    setState(() => _botAdded = true);

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _botAdded = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: AppTokens.r12,
            border: Border.all(color: t.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Livello difficoltà',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: t.textMuted,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: BotLevel.values.map((level) {
                  final isSelected = _selectedLevel == level;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedLevel = level),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? t.accent.withOpacity(0.15) : t.surfaceHigh,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? t.accent : t.border,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _getBotIcon(level, isSelected ? t.accent : t.textSecondary),
                          const SizedBox(width: 6),
                          Text(
                            level.displayName,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? t.accent : t.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed: _botAdded ? null : _addBot,
            icon: _botAdded
                ? const Icon(Icons.check_rounded, color: Colors.white)
                : _getBotIcon(_selectedLevel, Colors.white),
            label: Text(
              _botAdded ? 'Bot aggiunto!' : 'Aggiungi bot ${_selectedLevel.displayName}',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: _botAdded ? Colors.green : t.accent,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.green,
              shape: RoundedRectangleBorder(
                borderRadius: AppTokens.r16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _getBotIcon(BotLevel level, Color color) {
    switch (level) {
      case BotLevel.beginner:
        return Icon(Icons.child_care, size: 18, color: color);
      case BotLevel.casual:
        return Icon(Icons.face_2, size: 18, color: color);
      case BotLevel.intermediate:
        return Icon(Icons.face, size: 18, color: color);
      case BotLevel.advanced:
        return Icon(Icons.psychology, size: 18, color: color);
      case BotLevel.expert:
        return Icon(Icons.smart_toy, size: 18, color: color);
    }
  }
}

class _LoginFormState extends State<_LoginForm> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocusNode = FocusNode();

  String? _error;
  bool _isLoading = false;
  bool _showPassword = false;
  bool _loginAdded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _emailFocusNode.requestFocus();
    });
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Inserisci email e password');
      return;
    }

    setState(() {
      _error = null;
      _isLoading = true;
      _loginAdded = false;
    });

    try {
      const name = 'temp_auth';

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
        email: email,
        password: password,
      );

      if (cred.user != null && mounted) {
        await auth.signOut();

        if (!mounted) return;

        final user = cred.user!;
        final String playerName = await getBestDisplayName(
          email: user.email,
          displayName: user.displayName,
          uid: user.uid,
        );

        widget.onAdd((
        user.uid,
        playerName,
        false,
        ));

        _emailController.clear();
        _passwordController.clear();

        setState(() {
          _error = null;
          _isLoading = false;
          _loginAdded = true;
        });

        await Future.delayed(const Duration(milliseconds: 900));

        if (!mounted) return;

        setState(() => _loginAdded = false);
        _emailFocusNode.requestFocus();
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = 'Email o password non validi';
        _isLoading = false;
        _loginAdded = false;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _emailController,
          focusNode: _emailFocusNode,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          decoration: InputDecoration(
            hintText: 'Email',
            prefixIcon: Icon(
              Icons.email_rounded,
              color: t.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passwordController,
          obscureText: !_showPassword,
          textInputAction: TextInputAction.done,
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          onSubmitted: (_) => _login(),
          decoration: InputDecoration(
            hintText: 'Password',
            prefixIcon: Icon(
              Icons.lock_rounded,
              color: t.textSecondary,
            ),
            suffixIcon: IconButton(
              onPressed: () => setState(() => _showPassword = !_showPassword),
              icon: Icon(
                _showPassword
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                color: t.textSecondary,
              ),
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: TextStyle(
              color: t.red,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed: _isLoading || _loginAdded ? null : _login,
            icon: _isLoading
                ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: t.accentFg,
              ),
            )
                : Icon(
              _loginAdded
                  ? Icons.check_rounded
                  : Icons.login_rounded,
            ),
            label: Text(
              _loginAdded ? 'Added' : 'Login',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: _loginAdded ? Colors.green : t.accent,
              foregroundColor: Colors.white,
              disabledBackgroundColor:
              _loginAdded ? Colors.green : t.surfaceHigh,
              disabledForegroundColor:
              _loginAdded ? Colors.white : t.textMuted,
              shape: RoundedRectangleBorder(
                borderRadius: AppTokens.r16,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
class _AddedPlayersStrip extends StatelessWidget {
  final List<PlayerInfo> players;
  final ValueChanged<String> onRemove;

  const _AddedPlayersStrip({
    required this.players,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final sorted = List<PlayerInfo>.from(players)
      ..sort((a, b) => a.order.compareTo(b.order));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        if (sorted.isEmpty)
          Container(
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: AppTokens.r16,
              border: Border.all(color: t.border),
            ),
            child: Text(
              'Nessun giocatore aggiunto',
              style: TextStyle(
                color: t.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          )
        else
          SizedBox(
            height: 68,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              itemCount: sorted.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, index) {
                final player = sorted[index];

                return _AddedPlayerMiniCard(
                  player: player,
                  onRemove: () => onRemove(player.id),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _AddedPlayerMiniCard extends StatelessWidget {
  final PlayerInfo player;
  final VoidCallback onRemove;

  const _AddedPlayerMiniCard({
    required this.player,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    return Container(
      width: 200,
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: AppTokens.r16,
        border: Border.all(color: t.border),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: t.accent.withOpacity(0.12),
              borderRadius: AppTokens.r12,
            ),
            child: Icon(
              player.isGuest ? Icons.person_outline_rounded : Icons.verified_user_rounded,
              color: t.accent,
              size: 18,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              player.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: t.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 4),
          InkResponse(
            onTap: onRemove,
            radius: 18,
            child: Icon(
              Icons.close_rounded,
              size: 17,
              color: t.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}