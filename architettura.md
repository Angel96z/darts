# Flutter Architecture Rules: Gold Standard Pattern

Questo documento definisce le regole architettoniche obbligatorie per lo sviluppo di questo progetto Flutter. Ogni scrittura di codice deve aderire rigorosamente a questi standard.

## 1. Visione Generale (Layered Architecture)
Il progetto è diviso in 4 strati isolati. Non è ammesso saltare gli strati.

- **DOMAIN (Entità)**: Pura logica di business, modelli immutabili, validazione dei dati.
- **DATA (Repository)**: Integrazione con Firebase/Firestore. Gestione dei Result (Success/Failure).
- **APPLICATION (Notifier/Controller)**: Gestione dello stato con Riverpod (Generator). Orchestrazione tra Data e UI.
- **PRESENTATION (UI)**: Widget reattivi (ConsumerWidget). Nessuna logica di business qui.

---

## 2. Layer DOMAIN (Le Fondamenta)
- **Immutabilità**: Usa `@immutable` e il metodo `copyWith`.
- **Validazione**: Le entità devono avere un getter `String? get validationError` che restituisce il messaggio d'errore o `null`.
- **Logica Computata**: Calcoli (es. conteggio caratteri, filtri) vanno messi come getter nell'entità.
- **Stato**: Deve sempre contenere un `DateTime updatedAt` per la gestione della sincronizzazione.

## 3. Layer DATA (Repository Pattern)
- **Result Pattern**: Ogni operazione asincrona deve restituire un `Result<T>` (sealed class con `Success` o `Failure`).
- **Nessuna Eccezione**: I Repository non devono mai "lanciare" (throw) eccezioni alla UI, ma catturarle e trasformarle in `Failure`.
- **Firestore**: Usa `toMap()` e `fromFirestore()` definiti nell'entità.

## 4. Layer APPLICATION (Riverpod Notifiers)
- **Generazione**: Usa `@riverpod` e `riverpod_generator`.
- **State Management**: Usa `AsyncValue` per gestire gli stati di loading/error/data.
- **Validazione Pre-Salvataggio**: Prima di chiamare il repository, il controller DEVE validare l'entità tramite `validationError`. Se non è valida, emetti `AsyncError`.
- **Reattività**: Usa `StreamSubscription` all'interno del notifier per ascoltare i cambiamenti live da Firestore tramite il Repository.

## 5. Layer PRESENTATION (UI Rules)
- **Stato Locale vs Globale**:
   - Usa `TextEditingController` e `StatefulWidget` (o `StateProvider`) per input temporanei (scrittura "live").
   - Il salvataggio su Firebase avviene **SOLO** tramite un'azione esplicita (es. `onPressed` di un bottone) che chiama il Controller.
- **Feedback**: Gli errori emessi dal Controller (`AsyncError`) devono essere mostrati all'utente (es. `errorText` nel TextField o SnackBar).
- **Consumo**: Usa `ref.watch` per la UI reattiva e `ref.read` per le azioni (bottoni).

---

## 6. Coding Standards (MANDATORI)
1. **Naming**: Controller per la logica UI (`StringController`), Repository per i dati (`StringRepository`).
2. **Safety**: Mai forzare il cast con `!`. Usa il pattern matching di Dart 3 (`switch (result) { Success() => ..., Failure() => ... }`).
3. **Clean Code**: Se una funzione nel Controller supera le 15 righe, spezzala o sposta la logica di calcolo nell'Entità.
4. **Offline Ready**: Il codice deve presupporre che Firestore gestisca la cache, quindi i repository devono essere snelli.

---

### Esempio di flusso di salvataggio "Non-Live":
1. L'utente scrive nel `TextField` (gestito da un controller locale).
2. La UI mostra errori di validazione locali mentre l'utente scrive.
3. L'utente preme "Salva".
4. Il Notifier riceve il valore, crea un'istanza dell'Entità, verifica `isValid`.
5. Se valida, chiama `repository.update()`.
6. Se il repository fallisce, il Notifier espone l'errore che la UI visualizza.