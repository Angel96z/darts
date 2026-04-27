// TARGET: UI per testare la stringa su Firestore
// LOGIC GOAL: Solo UI stupida, nessuna logica
// REACTION: Mostra loading, errore, o la stringa
// ERROR STRATEGY: Messaggio rosso se errore
// ANTI-REGRESSION: UI puramente dichiarativa

import 'package:darts/features/string_test/application/string_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StringTestPage extends ConsumerStatefulWidget {
  const StringTestPage({super.key});

  @override
  ConsumerState<StringTestPage> createState() => _StringTestPageState();
}

class _StringTestPageState extends ConsumerState<StringTestPage> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _valueController = TextEditingController();

  @override
  void dispose() {
    _idController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(stringNotifierProvider);
    final notifier = ref.read(stringNotifierProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Stringa Firestore'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 🔥 STATO + ERRORE
            _StatusCard(state: state),
            const SizedBox(height: 20),

            // 🔥 SEZIONE CREA
            _CreateSection(notifier: notifier, isLoading: state.status == StringStatus.loading),
            const SizedBox(height: 16),

            // 🔥 SEZIONE CARICA
            _LoadSection(
              controller: _idController,
              notifier: notifier,
              isLoading: state.status == StringStatus.loading,
            ),
            const SizedBox(height: 16),

            // 🔥 SEZIONE MODIFICA (solo se documento caricato)
            if (state.entity != null)
              _UpdateSection(
                controller: _valueController,
                currentValue: state.entity!.value,
                notifier: notifier,
                isLoading: state.status == StringStatus.loading,
              ),
            const SizedBox(height: 16),

            // 🔥 SEZIONE ELIMINA (solo se documento caricato)
            if (state.currentId != null)
              _DeleteSection(
                notifier: notifier,
                isLoading: state.status == StringStatus.loading,
              ),
          ],
        ),
      ),
    );
  }
}

// 🔥 STATUS CARD (mostra la stringa o errore)
class _StatusCard extends StatelessWidget {
  final StringState state;

  const _StatusCard({required this.state});

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    String title;
    String content;

    switch (state.status) {
      case StringStatus.loading:
        bgColor = Colors.orange.shade100;
        title = 'CARICAMENTO...';
        content = 'Attendi';
        break;
      case StringStatus.error:
        bgColor = Colors.red.shade100;
        title = 'ERRORE';
        content = state.errorMessage ?? 'Errore sconosciuto';
        break;
      case StringStatus.success:
        bgColor = Colors.green.shade100;
        title = 'STRINGA CORRENTE';
        content = state.entity?.value ?? '(vuota)';
        break;
      default:
        bgColor = Colors.grey.shade100;
        title = 'IN ATTESA';
        content = 'Nessun documento caricato';
    }

    return Card(
      color: bgColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(content, style: const TextStyle(fontSize: 18)),
            if (state.entity != null)
              Text(
                'ID: ${state.entity!.id}',
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }
}

// 🔥 CREATE SECTION
class _CreateSection extends StatelessWidget {
  final StringNotifier notifier;
  final bool isLoading;

  const _CreateSection({required this.notifier, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: isLoading ? null : () => notifier.create('Stringa di test'),
      icon: const Icon(Icons.add),
      label: const Text('CREA NUOVA STRINGA'),
      style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
    );
  }
}

// 🔥 LOAD SECTION
class _LoadSection extends StatelessWidget {
  final TextEditingController controller;
  final StringNotifier notifier;
  final bool isLoading;

  const _LoadSection({
    required this.controller,
    required this.notifier,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'ID Documento',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: isLoading ? null : () => notifier.load(controller.text),
          child: const Text('CARICA'),
        ),
      ],
    );
  }
}

// 🔥 UPDATE SECTION
class _UpdateSection extends StatelessWidget {
  final TextEditingController controller;
  final String currentValue;
  final StringNotifier notifier;
  final bool isLoading;

  const _UpdateSection({
    required this.controller,
    required this.currentValue,
    required this.notifier,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    controller.text = currentValue;

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Nuovo valore',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: isLoading ? null : () => notifier.update(controller.text),
          child: const Text('AGGIORNA'),
        ),
      ],
    );
  }
}

// 🔥 DELETE SECTION
class _DeleteSection extends StatelessWidget {
  final StringNotifier notifier;
  final bool isLoading;

  const _DeleteSection({required this.notifier, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: isLoading ? null : () => notifier.delete(),
      icon: const Icon(Icons.delete),
      label: const Text('ELIMINA DOCUMENTO'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 50),
      ),
    );
  }
}