import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app_theme.dart';
import '../application/string_notifier.dart';

class StringTestPage extends ConsumerWidget {
  const StringTestPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppTokens.of(context);
    final tt = Theme.of(context).textTheme;
    final state = ref.watch(stringControllerProvider);
    final controller = ref.read(stringControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Architecture Gold Standard')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            state.when(
              data: (entity) => entity == null
                  ? const Text("Nessun dato")
                  : // lib/features/string_test/presentation/string_test_page.dart

// ... all'interno del metodo build, nel widget Card ...
              Card(
                child: ListTile(
                  title: Text(
                    entity.value,
                    style: tt.titleMedium?.copyWith(color: t.textPrimary),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("ID: ${entity.id}"),
                      const Divider(),
                      // Visualizzazione delle nuove funzioni
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Parole: ${entity.wordCount}"),
                          Text("Caratteri: ${entity.charCount}"),
                        ],
                      ),
                      if (entity.containsNumbers)
                        Text(
                          "⚠️ Contiene numeri",
                          style: tt.bodySmall?.copyWith(color: t.orange),
                        ),
                    ],
                  ),
                ),
              ),
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text(
                "Errore: $e",
                style: tt.bodySmall?.copyWith(color: t.red),
              ),
            ),
            const Spacer(),
            if (state.value == null)
              ElevatedButton(
                onPressed: () => controller.create("Nuova Stringa"),
                child: const Text("CREA DOCUMENTO"),
              )
            else ...[
              TextField(
                onChanged: (v) => controller.updateValue(v),
                decoration: InputDecoration(
                  labelText: "Modifica valore",
                  // Se l'entità ha un errore, lo mostriamo qui dinamicamente!
                  errorText: state.value?.validationError,
                ),
              ),
              TextButton(
                onPressed: () => controller.delete(),
                child: Text(
                  "ELIMINA",
                  style: tt.titleSmall?.copyWith(color: t.red),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
