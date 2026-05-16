/// FILE: avatar_selector_screen.dart
/// TARGET: Selezione avatar da asset interni

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app_theme.dart';
import '../../domain/user_profile.dart';
import '../../application/user_notifier.dart';

class AvatarSelectorScreen extends ConsumerStatefulWidget {
  const AvatarSelectorScreen({super.key});

  @override
  ConsumerState<AvatarSelectorScreen> createState() => _AvatarSelectorScreenState();
}

class _AvatarSelectorScreenState extends ConsumerState<AvatarSelectorScreen> {
  int? _selectedAvatarId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(userProvider).profile;
    _selectedAvatarId = profile?.avatarId;
  }

  Future<void> _saveAvatar() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    final notifier = ref.read(userProvider.notifier);
    await notifier.updateAvatarId(_selectedAvatarId);

    if (mounted) {
      setState(() => _isSaving = false);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        title: const Text('Scegli avatar'),
        backgroundColor: t.surface,
        elevation: 0,
        actions: [
          if (_isSaving)
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: t.accent)),
            )
          else
            TextButton(
              onPressed: _saveAvatar,
              child: Text('Salva', style: TextStyle(color: t.accent, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 1,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: AvatarId.all.length,
        itemBuilder: (ctx, index) {
          final avatar = AvatarId.all[index];
          final isSelected = _selectedAvatarId == avatar.id;

          return GestureDetector(
            onTap: () => setState(() => _selectedAvatarId = avatar.id),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? t.accent : Colors.transparent,
                  width: 4,
                ),
                boxShadow: isSelected ? [BoxShadow(color: t.accent.withOpacity(0.3), blurRadius: 8, spreadRadius: 2)] : null,
              ),
              child: CircleAvatar(
                radius: 50,
                backgroundColor: t.surfaceHigh,
                backgroundImage: AssetImage(avatar.assetPath),
              ),
            ),
          );
        },
      ),
    );
  }
}