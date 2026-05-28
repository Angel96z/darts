/// FILE: features/consigli/admin/consigli_admin_screen.dart
/// TARGET: Schermata admin per gestire le frasi motivazionali
/// LOGIC GOAL: CRUD completo su collezione 'consigli'
/// REACTION: Lista frasi, modifica, elimina, aggiungi
/// ERROR STRATEGY: Mostra errori e feedback all'utente
/// ANTI-REGRESSION: Solo il tuo UID può accedere

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app_theme.dart';

// UID autorizzato (TUO)
const String AUTHORIZED_UID = 'P6nsNSF0F5djBCJJR9kyTzYuO3f2';

// Provider per il check admin
final isAdminProvider = FutureProvider<bool>((ref) async {
  final user = FirebaseAuth.instance.currentUser;
  return user?.uid == AUTHORIZED_UID;
});

class ConsigliAdminScreen extends ConsumerStatefulWidget {
  const ConsigliAdminScreen({super.key});

  @override
  ConsumerState<ConsigliAdminScreen> createState() => _ConsigliAdminScreenState();
}

class _ConsigliAdminScreenState extends ConsumerState<ConsigliAdminScreen> {
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _autoreController = TextEditingController();
  String _selectedCategoria = 'motivazionale';
  bool _isLoading = false;
  String? _editingId;

  final List<String> _categorie = ['motivazionale', 'strategia', 'consiglio'];

  @override
  void dispose() {
    _textController.dispose();
    _autoreController.dispose();
    super.dispose();
  }

  void _resetForm() {
    _textController.clear();
    _autoreController.clear();
    _selectedCategoria = 'motivazionale';
    setState(() => _editingId = null);
  }

  Future<void> _saveConsiglio() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inserisci il testo della frase')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final db = FirebaseFirestore.instance;
      final data = {
        'text': text,
        'autore': _autoreController.text.trim().isEmpty ? null : _autoreController.text.trim(),
        'categoria': _selectedCategoria,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_editingId == null) {
        // CREATE
        await db.collection('consigli').add({
          ...data,
          'createdAt': FieldValue.serverTimestamp(),
          'attivo': true,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Frase aggiunta con successo!')),
          );
        }
      } else {
        // UPDATE
        await db.collection('consigli').doc(_editingId).update(data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Frase aggiornata con successo!')),
          );
        }
      }

      _resetForm();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Errore: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteConsiglio(String id, String text) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elimina frase'),
        content: Text('Vuoi eliminare: "$text"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ANNULLA'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('ELIMINA'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance.collection('consigli').doc(id).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Frase eliminata!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Errore: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _editConsiglio(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    _textController.text = data['text'] ?? '';
    _autoreController.text = data['autore'] ?? '';
    _selectedCategoria = data['categoria'] ?? 'motivazionale';
    setState(() => _editingId = doc.id);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final tt = Theme.of(context).textTheme;
    final isAdminAsync = ref.watch(isAdminProvider);

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        title: const Text('Admin Consigli'),
        centerTitle: true,
        actions: [
          if (_editingId != null)
            TextButton(
              onPressed: _resetForm,
              child: const Text('NUOVO'),
            ),
        ],
      ),
      body: isAdminAsync.when(
        data: (isAdmin) {
          if (!isAdmin) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock, size: 64, color: t.textMuted),
                  const SizedBox(height: 16),
                  Text(
                    'Accesso non autorizzato',
                    style: tt.titleMedium?.copyWith(color: t.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Solo l\'amministratore può gestire le frasi',
                    style: tt.bodySmall?.copyWith(color: t.textMuted),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // FORM per aggiungere/modificare
              _buildForm(t),
              const Divider(height: 32),
              // LISTA frasi esistenti
              Expanded(
                child: _buildConsigliList(t),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Text(
            'Errore di autenticazione',
            style: tt.bodySmall?.copyWith(color: t.red),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(AppTokens t) {
    final tt = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: AppTokens.r12,
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_editingId != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: t.accent.withOpacity(0.1),
                borderRadius: AppTokens.r8,
              ),
              child: Text(
                '✏️ MODIFICA IN CORSO',
                style: tt.labelSmall?.copyWith(color: t.accent),
              ),
            ),
          const SizedBox(height: 12),
          // Campo testo frase
          TextField(
            controller: _textController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Frase *',
              hintText: 'Inserisci la frase motivazionale...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          // Campo autore
          TextField(
            controller: _autoreController,
            decoration: const InputDecoration(
              labelText: 'Autore (opzionale)',
              hintText: 'es. Phil Taylor',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          // Select categoria
          DropdownButtonFormField<String>(
            value: _selectedCategoria,
            decoration: const InputDecoration(
              labelText: 'Categoria',
              border: OutlineInputBorder(),
            ),
            items: _categorie.map((cat) {
              return DropdownMenuItem(
                value: cat,
                child: Row(
                  children: [
                    _categoriaIcon(cat, t),
                    const SizedBox(width: 8),
                    Text(_categoriaLabel(cat)),
                  ],
                ),
              );
            }).toList(),
            onChanged: (value) => setState(() => _selectedCategoria = value!),
          ),
          const SizedBox(height: 16),
          // Bottoni
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveConsiglio,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: t.accent,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: _isLoading
                      ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: t.accentFg),
                  )
                      : Text(_editingId != null ? 'AGGIORNA' : 'AGGIUNGI'),
                ),
              ),
              if (_editingId != null)
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: OutlinedButton(
                    onPressed: _resetForm,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child: const Text('ANNULLA'),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConsigliList(AppTokens t) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('consigli')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Errore: ${snapshot.error}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.red),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.auto_awesome, size: 48, color: t.textMuted),
                const SizedBox(height: 12),
                Text(
                  'Nessuna frase nel database',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: t.textSecondary),
                ),
                const SizedBox(height: 8),
                Text(
                  'Usa il form qui sopra per aggiungerne una!',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.textMuted),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final text = data['text'] ?? '';
            final autore = data['autore'];
            final categoria = data['categoria'] ?? 'motivazionale';
            final attivo = data['attivo'] ?? true;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 0,
              color: attivo ? t.surface : t.surface.withOpacity(0.5),
              shape: RoundedRectangleBorder(
                borderRadius: AppTokens.r10,
                side: BorderSide(color: t.border, width: 0.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _categoriaIcon(categoria, t),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: t.accent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _categoriaLabel(categoria),
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: t.accent),
                          ),
                        ),
                        const Spacer(),
                        if (!attivo)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: t.grey.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'DISATTIVO',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: t.grey),
                            ),
                          ),
                        IconButton(
                          icon: Icon(Icons.edit, size: 18, color: t.textSecondary),
                          onPressed: () => _editConsiglio(doc),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete, size: 18, color: t.red),
                          onPressed: () => _deleteConsiglio(doc.id, text),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      text,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: attivo ? t.textPrimary : t.textSecondary,
                      ),
                    ),
                    if (autore != null && autore.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '— $autore',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.textMuted),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _categoriaIcon(String categoria, AppTokens t) {
    switch (categoria) {
      case 'strategia':
        return Icon(Icons.psychology, size: 16, color: t.accent);
      case 'consiglio':
        return Icon(Icons.lightbulb, size: 16, color: t.accent);
      default:
        return Icon(Icons.auto_awesome, size: 16, color: t.accent);
    }
  }

  String _categoriaLabel(String categoria) {
    switch (categoria) {
      case 'strategia':
        return '🎯 STRATEGIA';
      case 'consiglio':
        return '💡 CONSIGLIO';
      default:
        return '✨ MOTIVAZIONE';
    }
  }
}
