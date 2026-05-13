/// File: profile_screen.dart
/// Schermata profilo con modifica inline di nome, cognome, nickname

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app_theme.dart';
import '../../../stats/domain/services/stats_aggregator_service.dart';
import '../../../stats/shared/stats_repository.dart';
import '../../application/user_notifier.dart';
import '../../domain/user_profile.dart';
enum _ResetDataTarget {
  training,
  x01,
  cricket,
}
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _nicknameController;

  bool _isEditingFirstName = false;
  bool _isEditingLastName = false;
  bool _isEditingNickname = false;
  bool _isSaving = false;
  bool _isRefreshingStats = false;
  bool _isResettingGameData = false;

  String _originalFirstName = '';
  String _originalLastName = '';
  String _originalNickname = '';

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _nicknameController = TextEditingController();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  void _startEditFirstName(String value) {
    _originalFirstName = value;
    _firstNameController.text = value;
    setState(() => _isEditingFirstName = true);
  }

  void _cancelEditFirstName() {
    setState(() => _isEditingFirstName = false);
  }

  void _startEditLastName(String value) {
    _originalLastName = value;
    _lastNameController.text = value;
    setState(() => _isEditingLastName = true);
  }

  void _cancelEditLastName() {
    setState(() => _isEditingLastName = false);
  }

  void _startEditNickname(String value) {
    _originalNickname = value;
    _nicknameController.text = value;
    setState(() => _isEditingNickname = true);
  }

  void _cancelEditNickname() {
    setState(() => _isEditingNickname = false);
  }

  Future<void> _saveFirstName() async {
    final newValue = _firstNameController.text.trim();
    if (newValue.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Il nome non può essere vuoto'), backgroundColor: Colors.red));
      return;
    }
    if (newValue == _originalFirstName) {
      _cancelEditFirstName();
      return;
    }

    setState(() => _isSaving = true);
    try {
      final notifier = ref.read(userProvider.notifier);
      final profile = ref.read(userProvider).profile;
      if (profile != null) {
        await notifier.updateProfileInfo(
          firstName: newValue,
          lastName: profile.lastName,
          nickname: profile.nickname,
        );
      }
      setState(() => _isEditingFirstName = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nome aggiornato'), backgroundColor: Colors.green));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveLastName() async {
    final newValue = _lastNameController.text.trim();
    if (newValue.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Il cognome non può essere vuoto'), backgroundColor: Colors.red));
      return;
    }
    if (newValue == _originalLastName) {
      _cancelEditLastName();
      return;
    }

    setState(() => _isSaving = true);
    try {
      final notifier = ref.read(userProvider.notifier);
      final profile = ref.read(userProvider).profile;
      if (profile != null) {
        await notifier.updateProfileInfo(
          firstName: profile.firstName,
          lastName: newValue,
          nickname: profile.nickname,
        );
      }
      setState(() => _isEditingLastName = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cognome aggiornato'), backgroundColor: Colors.green));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveNickname() async {
    final newValue = _nicknameController.text.trim();
    if (newValue.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Il nickname non può essere vuoto'), backgroundColor: Colors.red));
      return;
    }
    if (newValue == _originalNickname) {
      _cancelEditNickname();
      return;
    }

    setState(() => _isSaving = true);
    try {
      final notifier = ref.read(userProvider.notifier);
      final profile = ref.read(userProvider).profile;
      if (profile != null) {
        await notifier.updateProfileInfo(
          firstName: profile.firstName,
          lastName: profile.lastName,
          nickname: newValue,
        );
      }
      setState(() => _isEditingNickname = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nickname aggiornato'), backgroundColor: Colors.green));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _sendPasswordReset(BuildContext context, String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Email per cambio password inviata")));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Errore: $e")));
    }
  }

  Future<void> _refreshStats() async {
    setState(() => _isRefreshingStats = true);
    try {
      // 🔥 NON forceFullRecalc! Lascia che sia incrementale
      await StatsAggregatorService.instance.updateUserStats(forceFullRecalc: false);
      ref.invalidate(userProvider);
      // Ricarica il profilo per sicurezza
      await ref.read(userProvider.notifier).loadProfile();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Statistiche aggiornate'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isRefreshingStats = false);
    }
  }


  Future<void> _showResetGameDataOverlay() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Devi essere autenticato per resettare i dati'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final selected = <_ResetDataTarget>{};

    final confirmedTargets = await showDialog<Set<_ResetDataTarget>>(
      context: context,
      barrierDismissible: !_isResettingGameData,
      builder: (ctx) {
        final t = AppTokens.of(ctx);

        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final canConfirm = selected.isNotEmpty;

            return AlertDialog(
              backgroundColor: t.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: t.border),
              ),
              titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              title: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: t.red.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.restart_alt_rounded, color: t.red),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Reset dati giochi',
                      style: TextStyle(
                        color: t.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                      child: Text(
                        'Seleziona quali dati eliminare dal tuo profilo. L’azione è definitiva.',
                        style: TextStyle(
                          color: t.textSecondary,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ),
                    _buildResetTargetTile(
                      t: t,
                      target: _ResetDataTarget.training,
                      selected: selected.contains(_ResetDataTarget.training),
                      onChanged: (value) {
                        setDialogState(() {
                          value == true
                              ? selected.add(_ResetDataTarget.training)
                              : selected.remove(_ResetDataTarget.training);
                        });
                      },
                    ),
                    _buildResetTargetTile(
                      t: t,
                      target: _ResetDataTarget.x01,
                      selected: selected.contains(_ResetDataTarget.x01),
                      onChanged: (value) {
                        setDialogState(() {
                          value == true
                              ? selected.add(_ResetDataTarget.x01)
                              : selected.remove(_ResetDataTarget.x01);
                        });
                      },
                    ),
                    _buildResetTargetTile(
                      t: t,
                      target: _ResetDataTarget.cricket,
                      selected: selected.contains(_ResetDataTarget.cricket),
                      onChanged: (value) {
                        setDialogState(() {
                          value == true
                              ? selected.add(_ResetDataTarget.cricket)
                              : selected.remove(_ResetDataTarget.cricket);
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Annulla', style: TextStyle(color: t.textSecondary)),
                ),
                ElevatedButton.icon(
                  onPressed: canConfirm
                      ? () => Navigator.pop(ctx, Set<_ResetDataTarget>.from(selected))
                      : null,
                  icon: const Icon(Icons.delete_forever_rounded, size: 18),
                  label: const Text('Conferma reset'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: t.red,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: t.surfaceHigh,
                    disabledForegroundColor: t.textMuted,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmedTargets == null || confirmedTargets.isEmpty) return;

    setState(() => _isResettingGameData = true);

    try {
      final deletedCount = await StatsRepository.instance.resetGameData(
        resetTraining: confirmedTargets.contains(_ResetDataTarget.training),
        resetX01: confirmedTargets.contains(_ResetDataTarget.x01),
        resetCricket: confirmedTargets.contains(_ResetDataTarget.cricket),
      );

      ref.invalidate(userProvider);
      await ref.read(userProvider.notifier).loadProfile();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reset completato. Elementi eliminati: $deletedCount'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore reset dati: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isResettingGameData = false);
    }
  }


  Future<int> _deleteCollection(CollectionReference<Map<String, dynamic>> collection) async {
    var deletedCount = 0;

    while (true) {
      final snapshot = await collection.limit(400).get();
      if (snapshot.docs.isEmpty) break;

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      deletedCount += snapshot.docs.length;

      if (snapshot.docs.length < 400) break;
    }

    return deletedCount;
  }

  List<String> _collectionNamesForResetTarget(_ResetDataTarget target) {
    switch (target) {
      case _ResetDataTarget.training:
        return const ['training_sessions'];
      case _ResetDataTarget.x01:
        return const ['x01_matches'];
      case _ResetDataTarget.cricket:
        return const ['cricket_matches'];
    }
  }


  Widget _buildResetTargetTile({
    required AppTokens t,
    required _ResetDataTarget target,
    required bool selected,
    required ValueChanged<bool?> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: selected ? t.red.withOpacity(0.08) : t.surfaceHigh.withOpacity(0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: selected ? t.red.withOpacity(0.45) : t.border),
      ),
      child: CheckboxListTile(
        value: selected,
        onChanged: onChanged,
        activeColor: t.red,
        checkColor: Colors.white,
        controlAffinity: ListTileControlAffinity.trailing,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        secondary: Icon(_resetTargetIcon(target), color: selected ? t.red : t.textMuted),
        title: Text(
          _resetTargetLabel(target),
          style: TextStyle(
            color: selected ? t.red : t.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(
          _resetTargetSubtitle(target),
          style: TextStyle(
            color: t.textSecondary,
            fontSize: 12,
            height: 1.25,
          ),
        ),
      ),
    );
  }

  String _resetTargetLabel(_ResetDataTarget target) {
    switch (target) {
      case _ResetDataTarget.training:
        return 'Training';
      case _ResetDataTarget.x01:
        return 'X01';
      case _ResetDataTarget.cricket:
        return 'Cricket';
    }
  }

  String _resetTargetSubtitle(_ResetDataTarget target) {
    switch (target) {
      case _ResetDataTarget.training:
        return 'Elimina sessioni, tiri e dati statistici training.';
      case _ResetDataTarget.x01:
        return 'Elimina match, leg, turni e statistiche X01.';
      case _ResetDataTarget.cricket:
        return 'Elimina match, turni, marks e statistiche Cricket.';
    }
  }

  IconData _resetTargetIcon(_ResetDataTarget target) {
    switch (target) {
      case _ResetDataTarget.training:
        return Icons.track_changes_rounded;
      case _ResetDataTarget.x01:
        return Icons.sports_score_rounded;
      case _ResetDataTarget.cricket:
        return Icons.grid_view_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final userState = ref.watch(userProvider);
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? "Nessuna email";
    final profile = userState.profile;

    if (userState.isLoading && profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Profilo"), backgroundColor: t.surface, elevation: 0),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final firstName = profile?.firstName ?? '';
    final lastName = profile?.lastName ?? '';
    final nickname = profile?.nickname ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text("Profilo"), backgroundColor: t.surface, elevation: 0),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SizedBox(height: 12),
              Center(
                child: CircleAvatar(
                  radius: 48,
                  backgroundColor: t.accent.withOpacity(0.1),
                  child: Text(profile?.initials ?? '?', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: t.accent)),
                ),
              ),
              const SizedBox(height: 12),
              Center(child: Text(profile?.displayName ?? email.split('@').first, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: t.textPrimary))),
              const SizedBox(height: 8),
              Center(child: Text(email, style: TextStyle(fontSize: 14, color: t.textSecondary))),
              const SizedBox(height: 24),

              // Card dati personali
              Card(
                color: t.surface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: t.border)),
                child: Column(
                  children: [
                    _buildEditableTile(
                      t: t,
                      icon: Icons.person_outline,
                      label: 'Nome',
                      value: firstName,
                      isEditing: _isEditingFirstName,
                      controller: _firstNameController,
                      onEdit: () => _startEditFirstName(firstName),
                      onCancel: _cancelEditFirstName,
                      onSave: _saveFirstName,
                      placeholder: 'Inserisci il tuo nome',
                    ),
                    Divider(color: t.divider, height: 1, indent: 56),
                    _buildEditableTile(
                      t: t,
                      icon: Icons.person_outline,
                      label: 'Cognome',
                      value: lastName,
                      isEditing: _isEditingLastName,
                      controller: _lastNameController,
                      onEdit: () => _startEditLastName(lastName),
                      onCancel: _cancelEditLastName,
                      onSave: _saveLastName,
                      placeholder: 'Inserisci il tuo cognome',
                    ),
                    Divider(color: t.divider, height: 1, indent: 56),
                    _buildEditableTile(
                      t: t,
                      icon: Icons.tag,
                      label: 'Nickname',
                      value: nickname,
                      isEditing: _isEditingNickname,
                      controller: _nicknameController,
                      onEdit: () => _startEditNickname(nickname),
                      onCancel: _cancelEditNickname,
                      onSave: _saveNickname,
                      placeholder: 'Inserisci il tuo nickname',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Card statistiche carriera
              if (profile?.stats != null)
                Card(
                  color: t.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: t.border)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Statistiche carriera',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: t.textPrimary),
                              ),
                            ),
                            if (!_isRefreshingStats)
                              IconButton(
                                icon: Icon(Icons.refresh, color: t.accent, size: 20),
                                onPressed: _refreshStats,
                                tooltip: 'Ricalcola statistiche',
                              )
                            else
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: t.accent),
                              ),
                          ],
                        ),
                      ),
                      Divider(color: t.divider, height: 1),
                      _buildStatTile(t, 'Partite giocate', '${profile!.stats.totalMatches}'),
                      _buildStatTile(t, 'Partite vinte', '${profile.stats.totalMatchesWon} (${profile.stats.winRate.toStringAsFixed(0)}%)'),
                      _buildStatTile(t, 'Sessioni training', '${profile.stats.totalTrainingSessions}'),
                      _buildStatTile(t, 'Tiri training', '${profile.stats.totalTrainingThrows}'),
                      _buildStatTile(t, 'Miglior leg (dardi)', profile.stats.bestLegDarts == 999 ? '-' : '${profile.stats.bestLegDarts}'),
                      _buildStatTile(t, 'Media X01 migliore', profile.stats.bestX01Average.toStringAsFixed(1)),
                      _buildStatTile(t, 'MPR Cricket migliore', profile.stats.bestCricketMPR.toStringAsFixed(2)),
                      _buildStatTile(t, '180', '${profile.stats.total180s}'),
                      _buildStatTile(t, '140+', '${profile.stats.total140s}'),
                      _buildStatTile(t, '100+', '${profile.stats.total100s}'),
                      _buildStatTile(t, 'Checkout totali', '${profile.stats.totalCheckouts}'),
                      _buildStatTile(t, 'Miglior checkout', '${profile.stats.bestCheckout}'),
                    ],
                  ),
                ),

              const SizedBox(height: 24),
              // Card reset dati giochi
              Card(
                color: t.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: t.orange.withOpacity(0.35)),
                ),
                child: ListTile(
                  leading: Icon(Icons.restart_alt_rounded, color: t.orange),
                  title: Text(
                    'Reset dati giochi',
                    style: TextStyle(
                      color: t.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    'Elimina dati Training, X01 e Cricket dal profilo',
                    style: TextStyle(color: t.textSecondary),
                  ),
                  trailing: Icon(Icons.chevron_right, color: t.orange),
                  onTap: _isResettingGameData ? null : _showResetGameDataOverlay,
                ),
              ),

              const SizedBox(height: 24),
              // Card sicurezza
              Card(
                color: t.surface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: t.border)),
                child: ListTile(
                  leading: Icon(Icons.lock_reset, color: t.accent),
                  title: Text('Reset password', style: TextStyle(color: t.textPrimary)),
                  trailing: Icon(Icons.chevron_right, color: t.textMuted),
                  onTap: () => _sendPasswordReset(context, email),
                ),
              ),

              const SizedBox(height: 24),

              // Card eliminazione
              Card(
                color: t.surface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: t.red.withOpacity(0.3))),
                child: ListTile(
                  leading: Icon(Icons.delete_forever, color: t.red),
                  title: Text('Elimina account', style: TextStyle(color: t.red)),
                  trailing: Icon(Icons.chevron_right, color: t.red),
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text("Elimina account"),
                        content: const Text("Vuoi eliminare definitivamente il tuo account? Tutti i dati andranno persi."),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Annulla")),
                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Elimina", style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await user?.delete();
                      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
                    }
                  },
                ),
              ),
            ],
          ),
          if (_isSaving || _isResettingGameData)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildEditableTile({
    required AppTokens t,
    required IconData icon,
    required String label,
    required String value,
    required bool isEditing,
    required TextEditingController controller,
    required VoidCallback onEdit,
    required VoidCallback onCancel,
    required Future<void> Function() onSave,
    required String placeholder,
  }) {
    return ListTile(
      leading: Icon(icon, color: t.accent),
      title: Text(label, style: TextStyle(color: t.textSecondary, fontSize: 12)),
      subtitle: isEditing
          ? TextField(
        controller: controller,
        autofocus: true,
        style: TextStyle(color: t.textPrimary),
        decoration: InputDecoration(
          hintText: placeholder,
          hintStyle: TextStyle(color: t.textMuted),
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
      )
          : Text(value.isNotEmpty ? value : '—', style: TextStyle(color: value.isNotEmpty ? t.textPrimary : t.textMuted)),
      trailing: isEditing
          ? Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(icon: Icon(Icons.close, color: t.red, size: 20), onPressed: onCancel, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
          const SizedBox(width: 8),
          IconButton(icon: Icon(Icons.check, color: t.green, size: 20), onPressed: () async => onSave(), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
        ],
      )
          : IconButton(icon: Icon(Icons.edit, color: t.accent, size: 20), onPressed: onEdit, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
    );
  }
  Widget _buildStatTile(AppTokens t, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: t.textSecondary, fontSize: 14)),
          Text(value, style: TextStyle(color: t.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

