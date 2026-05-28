import 'dart:convert'; // 1. AGGIUNGI QUESTO IMPORT
import 'package:google_generative_ai/google_generative_ai.dart'; // 2. AGGIUNGI QUESTO IMPORT
import '../domain/ai_coach_models.dart';

sealed class AiCoachResult<T> {
  const AiCoachResult();
}

class AiCoachSuccess<T> extends AiCoachResult<T> {
  final T value;
  const AiCoachSuccess(this.value);
}

class AiCoachFailure<T> extends AiCoachResult<T> {
  final String message;
  const AiCoachFailure(this.message);
}

abstract class AiCoachRepository {
  Future<AiCoachResult<AiCoachAdvice>> generateAdvice(AiCoachInput input);
}

// Manteniamo questa nel caso ti servisse per i test offline
class LocalAiCoachRepository implements AiCoachRepository {
  const LocalAiCoachRepository();

  @override
  Future<AiCoachResult<AiCoachAdvice>> generateAdvice(AiCoachInput input) async {
    final error = input.validationError;
    if (error != null) return AiCoachFailure(error);

    final ordered = [...input.signals]
      ..sort((a, b) => a.normalizedScore.compareTo(b.normalizedScore));

    final weakest = ordered.first;
    final strongest = ordered.last;

    return AiCoachSuccess(
      AiCoachAdvice(
        summary: _summary(input, strongest, weakest),
        mainIssue: _mainIssue(weakest),
        technicalAdvice: _technicalAdvice(input, weakest),
        nextDrill: _nextDrill(input, weakest),
        confidence: _confidence(input.signals),
        sourceFingerprint: input.fingerprint,
        generatedAt: DateTime.now(),
      ),
    );
  }

  String _summary(AiCoachInput input, AiCoachSignal strong, AiCoachSignal weak) {
    return 'Analisi ${input.title}: punto forte "${strong.label}", priorità tecnica "${weak.label}".';
  }

  String _mainIssue(AiCoachSignal weak) {
    return 'La metrica più fragile è ${weak.label}: ${weak.value.toStringAsFixed(1)}${weak.unit}.';
  }

  List<String> _technicalAdvice(AiCoachInput input, AiCoachSignal weak) {
    switch (input.mode) {
      case AiCoachMode.training:
        return [
          'Lavora prima sulla ripetibilità del gesto, non sulla forza del tiro.',
          'Usa un reset breve tra una freccia e l’altra se il calo riguarda Dart 2 o Dart 3.',
          'Mantieni stesso setup, stesso ritmo e stesso punto di mira per almeno 3 turni consecutivi.',
          'Priorità attuale: ${weak.category}.',
        ];
      case AiCoachMode.x01:
        return [
          'Se la fase fragile è scoring, riduci il risco e costruisci più turni solidi.',
          'Se la fase fragile è checkout, entra in chiusura con numeri più comodi e routine più lenta.',
          'Confronta punti/turno e turni necessari: devono migliorare insieme.',
          'Priorità attuale: ${weak.category}.',
        ];
      case AiCoachMode.cricket:
        return [
          'Dai priorità ai settori che chiudi lentamente o dove generi pochi marker.',
          'Non inseguire subito i punti: prima stabilizza chiusura e pressione sui numeri aperti.',
          'Se perdi leg con buoni marker, il problema può essere timing dei punti o target selection.',
          'Priorità attuale: ${weak.category}.',
        ];
    }
  }

  String _nextDrill(AiCoachInput input, AiCoachSignal weak) {
    switch (input.mode) {
      case AiCoachMode.training:
        return 'Drill: 5 turni su target fisso. Obiettivo minimo: migliorare ${weak.label} senza cambiare ritmo.';
      case AiCoachMode.x01:
        return 'Drill: 10 leg simulati. Obiettivo: entrare in checkout con un turno in meno o chiudere con meno visite.';
      case AiCoachMode.cricket:
        return 'Drill: 7 turni Cricket sui settori deboli. Obiettivo: almeno 2 marker utili per turno.';
    }
  }

  double _confidence(List<AiCoachSignal> signals) {
    if (signals.length >= 6) return 0.86;
    if (signals.length >= 4) return 0.74;
    return 0.62;
  }
}

// ==========================================
// 3. NUOVA IMPLEMENTAZIONE CON GEMINI AI
// ==========================================
class RemoteGeminiAiCoachRepository implements AiCoachRepository {
  final String _apiKey = 'AIzaSyAaLpbvshIG90HpbHjgdcETxghPEzjt2XE';

  const RemoteGeminiAiCoachRepository();

  @override
  Future<AiCoachResult<AiCoachAdvice>> generateAdvice(AiCoachInput input) async {
    final error = input.validationError;
    if (error != null) return AiCoachFailure(error);

    if (_apiKey.isEmpty) {
      return const AiCoachFailure('Configurazione fallita: Chiave API Gemini non trovata nell\'ambiente d\'esecuzione.');
    }

    try {
      // Inizializziamo il modello di Gemini chiedendo esplicitamente una risposta JSON strutturata
// ✅ COME DEVI MODIFICARLO:
      final model = GenerativeModel(
        model: 'gemini-2.5-flash', // <--- Sostituito con la versione funzionante
        apiKey: _apiKey,
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
        ),
      );

      // Mappiamo i segnali per l'AI mantenendo la scala originale.
      // I feedback sessione restano su 10: 7/10 deve arrivare come 7 su 10,
      // non come 70%.
      final signalsData = input.signals.map((s) {
        return {
          'label': s.label,
          'value': s.value,
          'unit': s.unit,
          'higherIsBetter': s.higherIsBetter,
          'category': s.category,
        };
      }).toList();

      final sessionsData = input.sessionSnapshots
          .map((session) => session.toJson())
          .toList(growable: false);

      final prompt = '''
Sei un Mental Coach e Data Analyst professionista specializzato in freccette(darts).

ANALISI DATI:
- Modalità: ${input.mode.name.toUpperCase()}
- Sessione: ${input.title}
- Contesto: ${input.subtitle}
- Metriche aggregate: ${jsonEncode(signalsData)}
- Top/Worst sessioni reali: ${jsonEncode(sessionsData)}

REGOLE DI VERITÀ DATI:
- Le metriche aggregate descrivono il periodo, ma NON dimostrano correlazioni.
- Puoi collegare feedback mentale e prestazione SOLO usando "Top/Worst sessioni reali".
- Ogni collegamento deve usare dati della stessa sessione.
- NON dire "quando sei stressato..." se non emerge chiaramente dal confronto top/worst.
- NON inventare andamento temporale, cali o momenti critici se non sono presenti nei dati.
- Se una relazione non è dimostrabile, scrivi: "dai dati disponibili non è possibile collegare direttamente..."
- Il feedback mentale è su scala 1-10, non percentuale.

ANALISI RICHIESTA:
1. Analizza le metriche aggregate.
2. Confronta Dart 1, Dart 2, Dart 3 se presenti.
3. Confronta top 5 e worst 5 sessioni reali.
4. Collega feedback e prestazione solo se il confronto top/worst lo supporta.

TONO: Professionale, motivante, diretto, ma prudente. Mai inventare cause.
FORMATO JSON OBBLIGATORIO:
{
  "summary": "Quadro generale: pattern emersi e trend (2-3 frasi)",
  "mainIssue": "Analisi approfondita del problema principale: collegamento tra pattern freccette, momenti di calo e stati mentali (4-5 frasi)",
  "technicalAdvice": [
    "ASPETTO TECNICO: consiglio sul gesto/rilascio/bersaglio - Perché: spiegazione",
    "ASPETTO FISICO: consiglio su respirazione/postura/tensione - Come: esecuzione",
    "ASPETTO MENTALE: consiglio su routine/focus/gestione ansia - Esercizio pratico"
  ],
  "nextDrill": "Drill completo che unisce tecnica, fisico e mente. Durata: 10 minuti. Passo passo.",
  "confidence": 0.85
}
''';

      final response = await model.generateContent([Content.text(prompt)]);
      final responseText = response.text;

      if (responseText == null) {
        return const AiCoachFailure('Nessuna risposta ricevuta dal motore di intelligenza artificiale.');
      }

      // Decodifichiamo il JSON di Gemini
      final Map<String, dynamic> data = jsonDecode(responseText);

      return AiCoachSuccess(
        AiCoachAdvice(
          summary: data['summary'] ?? '',
          mainIssue: data['mainIssue'] ?? '',
          technicalAdvice: List<String>.from(data['technicalAdvice'] ?? []),
          nextDrill: data['nextDrill'] ?? '',
          confidence: (data['confidence'] as num?)?.toDouble() ?? 0.80,
          sourceFingerprint: input.fingerprint,
          generatedAt: DateTime.now(),
        ),
      );
    } catch (e) {
      return AiCoachFailure('Errore durante l\'elaborazione dell\'AI Coach: $e');
    }
  }
}