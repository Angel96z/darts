# 🏛️ AI MASTER ARCHITECT: PROTOCOLLO DEFINITIVO DI SVILUPPO E PATCHING

Questo documento è il framework assiomatico per ogni operazione di scrittura codice. L'IA deve trattare queste istruzioni come vincoli tecnici invalicabili. Qualsiasi violazione del protocollo compromette l'integrità del progetto.

---

## I. ARCHITETTURA RIGOROSA (Gold Standard Layered Pattern)

Il progetto è diviso in 4 strati isolati. È tassativamente vietato saltare i layer o creare dipendenze circolari.

### 1. DOMAIN LAYER (Le Fondamenta)
- **Modelli**: Solo classi `@immutable` con metodo `copyWith`.
- **Business Logic**: Calcoli e manipolazioni dati risiedono qui (es. getter per conteggi, filtri, formattazioni).
- **Validazione**: Ogni entità DEVE avere un getter `String? get validationError` (null se valida) e un booleano `bool get isValid`.
- **Sincronizzazione**: Ogni entità deve includere un campo `DateTime updatedAt`.

### 2. DATA LAYER (Repository Pattern)
- **Isolamento**: Solo i Repository parlano con Firestore o API esterne.
- **Result Pattern**: Ogni operazione asincrona restituisce `Result<T>` (Sealed class: `Success` o `Failure`).
- **Nessuna Eccezione**: I Repository catturano gli errori e restituiscono `Failure(AppFailure)`. Mai fare "throw" verso l'alto.
- **Mappatura**: Contiene i metodi `fromFirestore` (o `fromMap`) e `toMap`.

### 3. APPLICATION LAYER (State Management)
- **Controller**: Utilizzo esclusivo di **Riverpod Generator** (`@riverpod`).
- **Responsabilità**: Orchestrazione tra UI e Repository. Non contiene logica di business (che sta nel Domain).
- **Reattività**: Gestione dello stato tramite `AsyncValue`. Uso di `StreamSubscription` per ascolti real-time.

### 4. PRESENTATION LAYER (UI reattiva)
- **Widget**: Solo `ConsumerWidget` o `ConsumerStatefulWidget`.
- **Stato Locale**: `TextEditingController` e `StatefulWidget` sono ammessi solo per gestire l'input temporaneo prima del salvataggio.
- **Feedback**: Gli errori (`AsyncError`) devono essere intercettati dalla UI e mostrati all'utente.

---

## II. CODING STANDARDS MANDATORI (Safety & Clean Code)

1. **Naming Convention**:
  - Logica UI/Stato -> `[Nome]Controller` (es. `StringController`).
  - Gestione Dati -> `[Nome]Repository` (es. `StringRepository`).
  - Modelli -> `[Nome]Entity` (es. `StringEntity`).
2. **Type Safety**: Mai usare il cast forzato `!`. Gestire sempre la nullabilità.
3. **Pattern Matching**: Sfruttare Dart 3+ per gestire i risultati (es. `switch (result) { Success() => ..., Failure() => ... }`).
4. **Regola delle 15 Righe**: Se una funzione nel Controller supera le 15 righe, deve essere rifattorizzata o spostata nel Domain.
5. **Offline Ready**: I Repository devono essere snelli, presupponendo che Firestore gestisca autonomamente la persistenza della cache.

---

## III. FLUSSO DI SALVATAGGIO "NON-LIVE" (Logic Step-by-Step)

Per ogni operazione di inserimento o modifica, l'IA deve implementare questo flusso:
1. **Input Locale**: L'utente scrive in un `TextField` gestito da un controller locale (UI).
2. **Validazione Real-time**: La UI mostra errori di validazione basandosi sull'entità mentre l'utente digita.
3. **Azione di Invio**: L'utente preme "Salva" (o `onSubmitted`).
4. **Intervento del Controller**: Il Notifier riceve il valore, crea un'istanza dell'Entità e chiama `isValid`.
5. **Esecuzione**: Se valida, chiama il Repository. Se invalida, emette un `AsyncError` con il messaggio di validazione senza toccare il DB.
6. **Gestione Fallimento**: Se il Repository restituisce `Failure`, il Controller espone l'errore per la visualizzazione nella UI.

---

## IV. PROTOCOLLO DI PATCHING CHIRURGICO (Cerca & Sostituisci)

L'utente applica il codice esclusivamente tramite "Cerca e Sostituisci". L'IA deve garantire l'univocità.

### 1. Requisiti della Patch
- **Univocità**: La stringa in **🔍 CERCA** deve essere unica nel file. Includere 5+ righe di contesto se necessario.
- **Integrità dei Blocchi**: Non patchare singole parole. Sostituire l'intero blocco logico (intera funzione, intero widget, intero blocco `if/else`).
- **Regola dei File Brevi**: Se il file è inferiore a 80 righe, l'IA **DEVE** fornire l'intero file riscritto.

### 2. Formato Obbligatorio della Risposta
### 📁 FILE: `percorso/completo/del/file.dart`
**🔍 CERCA (Blocco Univoco):**
```dart
// Codice originale per identificare il punto esatto
🛠️ AZIONE: [SOSTITUISCI / AGGIUNGI SOPRA / AGGIUNGI SOTTO]
💻 CODICE DA INCOLLARE:

Dart
// Nuovo codice completo e formattato
V. PROCEDURA OPERATIVA (Roadmap)
Per ogni richiesta, l'IA deve rispondere seguendo questi passaggi:

Analisi: Verificare l'impatto della richiesta sui file esistenti.

Roadmap Numerata: Proporre un piano (Patch #1, Patch #2, ecc.).

Esecuzione Indipendente: Se l'utente chiede la Patch #3, l'IA la fornisce come se le patch precedenti fossero già state applicate perfettamente, garantendo coerenza di nomi e import.

Auto-Verifica: Prima di inviare, l'IA controlla se la patch viola uno dei Coding Standards al punto II.