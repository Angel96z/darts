/// FILE: features/consigli/consigli_feature.dart
/// TARGET: Area frasi motivazionali/consigli/strategie da db globale
/// LOGIC GOAL: Legge da Firestore collezione 'consigli', stream in tempo reale,
///             itera frasi casualmente con scorrimento automatico
/// REACTION: Mostra frase corrente, cambia ogni X secondi con animazione
/// ERROR STRATEGY: Mostra messaggio di errore se db non disponibile
/// ANTI-REGRESSION: UI reattiva ai token di tema, stream live, caching locale

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../app_theme.dart';

// ============================================================================
// DOMAIN LAYER (modello immutabile - come StringEntity)
// ============================================================================

@immutable
class ConsiglioEntity {
  final String? id;
  final String text;
  final String? autore;
  final String categoria;
  final DateTime createdAt;
  final bool attivo;

  const ConsiglioEntity({
    this.id,
    required this.text,
    this.autore,
    required this.categoria,
    required this.createdAt,
    this.attivo = true,
  });

  factory ConsiglioEntity.create({
    required String text,
    String? autore,
    String categoria = 'motivazionale',
  }) {
    return ConsiglioEntity(
      text: text,
      autore: autore,
      categoria: categoria,
      createdAt: DateTime.now(),
      attivo: true,
    );
  }

  factory ConsiglioEntity.fromFirestore(String id, Map<String, dynamic> map) {
    return ConsiglioEntity(
      id: id,
      text: map['text'] as String? ?? '',
      autore: map['autore'] as String?,
      categoria: map['categoria'] as String? ?? 'motivazionale',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      attivo: map['attivo'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'autore': autore,
      'categoria': categoria,
      'createdAt': Timestamp.fromDate(createdAt),
      'attivo': attivo,
    };
  }

  ConsiglioEntity copyWith({
    String? id,
    String? text,
    String? autore,
    String? categoria,
    DateTime? createdAt,
    bool? attivo,
  }) {
    return ConsiglioEntity(
      id: id ?? this.id,
      text: text ?? this.text,
      autore: autore ?? this.autore,
      categoria: categoria ?? this.categoria,
      createdAt: createdAt ?? this.createdAt,
      attivo: attivo ?? this.attivo,
    );
  }
}

// ============================================================================
// FAILURE (come StringFailure)
// ============================================================================

abstract class ConsiglioFailure {
  final String message;
  const ConsiglioFailure(this.message);
}

class ConsiglioNetworkFailure extends ConsiglioFailure {
  const ConsiglioNetworkFailure() : super('Errore di connessione');
}

class ConsiglioNotFoundFailure extends ConsiglioFailure {
  const ConsiglioNotFoundFailure() : super('Nessun consiglio trovato');
}

// ============================================================================
// DATA LAYER (Repository - come StringRepository)
// ============================================================================

sealed class ConsigliResult<T, E> {
  const ConsigliResult();
  factory ConsigliResult.success(T value) = ConsigliSuccess<T, E>;
  factory ConsigliResult.failure(E error) = ConsigliFailureResult<T, E>;

  bool get isSuccess => this is ConsigliSuccess<T, E>;
  bool get isFailure => this is ConsigliFailureResult<T, E>;
}

class ConsigliSuccess<T, E> extends ConsigliResult<T, E> {
  final T value;
  const ConsigliSuccess(this.value);
}

class ConsigliFailureResult<T, E> extends ConsigliResult<T, E> {
  final E error;
  const ConsigliFailureResult(this.error);
}

class ConsigliRepository {
  final FirebaseFirestore _db;
  static const String _collection = 'consigli';

  ConsigliRepository(this._db);

  /// STREAM di TUTTI i consigli attivi (come watch() in StringRepository)
  Stream<List<ConsiglioEntity>> watchAll() {
    return _db
        .collection(_collection)
        .where('attivo', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ConsiglioEntity.fromFirestore(doc.id, doc.data()))
          .toList();
    });
  }
}

final consigliRepositoryProvider = Provider<ConsigliRepository>((ref) {
  return ConsigliRepository(FirebaseFirestore.instance);
});

// ============================================================================
// APPLICATION LAYER (Notifier - COME StringNotifier)
// ============================================================================

enum ConsigliStatus { initial, loading, success, error }

@immutable
class ConsigliState {
  final List<ConsiglioEntity> consigli;
  final ConsigliStatus status;
  final String? errorMessage;
  final ConsiglioEntity? current; // frase corrente (simile a entity in StringState)

  const ConsigliState({
    this.consigli = const [],
    this.status = ConsigliStatus.initial,
    this.errorMessage,
    this.current,
  });

  ConsigliState copyWith({
    List<ConsiglioEntity>? consigli,
    ConsigliStatus? status,
    String? errorMessage,
    ConsiglioEntity? current,
  }) {
    return ConsigliState(
      consigli: consigli ?? this.consigli,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      current: current ?? this.current,
    );
  }
}

class ConsigliNotifier extends StateNotifier<ConsigliState> {
  final ConsigliRepository _repository;
  StreamSubscription<List<ConsiglioEntity>>? _subscription;
  Timer? _rotationTimer;
  final Random _random = Random();
  int _currentIndex = 0;
  static const int rotationIntervalSeconds = 80;

  ConsigliNotifier(this._repository) : super(const ConsigliState()) {
    _listenToConsigli(); // COME StringNotifier fa _listenToDocument
  }

  // 🔥 COME _listenToDocument in StringNotifier
  void _listenToConsigli() {
    _subscription?.cancel();
    _subscription = _repository.watchAll().listen(
          (consigli) {
        if (consigli.isNotEmpty) {
          // Scegli una frase random iniziale
          final randomIndex = _random.nextInt(consigli.length);
          state = state.copyWith(
            consigli: consigli,
            current: consigli[randomIndex],
            status: ConsigliStatus.success,
            errorMessage: null,
          );
          _startRotationTimer(consigli);
        } else {
          state = state.copyWith(
            consigli: consigli,
            status: ConsigliStatus.error,
            errorMessage: 'Nessun consiglio trovato nel database',
          );
        }
      },
      onError: (e) {
        state = state.copyWith(
          status: ConsigliStatus.error,
          errorMessage: 'Errore stream: $e',
        );
      },
    );
  }

  void _startRotationTimer(List<ConsiglioEntity> consigli) {
    _rotationTimer?.cancel();
    if (consigli.length <= 1) return;

    _rotationTimer = Timer.periodic(
      Duration(seconds: rotationIntervalSeconds),
          (_) => _nextConsiglio(),
    );
  }

  void _nextConsiglio() {
    final consigli = state.consigli;
    if (consigli.isEmpty) return;

    if (consigli.length == 1) {
      state = state.copyWith(current: consigli.first);
      return;
    }

    final currentId = state.current?.id;
    var next = consigli[_random.nextInt(consigli.length)];

    var guard = 0;
    while (next.id == currentId && guard < 8) {
      next = consigli[_random.nextInt(consigli.length)];
      guard++;
    }

    state = state.copyWith(current: next);
  }

  void skipToNext() {
    _nextConsiglio();
    // Reset timer
    _rotationTimer?.cancel();
    _startRotationTimer(state.consigli);
  }

  @override
  void dispose() {
    _rotationTimer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}

final consigliProvider = StateNotifierProvider<ConsigliNotifier, ConsigliState>((ref) {
  final repo = ref.watch(consigliRepositoryProvider);
  return ConsigliNotifier(repo);
});

// ============================================================================
// PRESENTATION LAYER (UI - COME StringTestPage)
// ============================================================================

class ConsigliCarouselWidget extends ConsumerWidget {
  const ConsigliCarouselWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppTokens.of(context);
    final tt = Theme.of(context).textTheme;
    final state = ref.watch(consigliProvider);
    final notifier = ref.read(consigliProvider.notifier);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
      child: _buildContent(tt, t, state, notifier),
    );
  }

  Widget _buildContent(
    TextTheme tt,
    AppTokens t,
    ConsigliState state,
    ConsigliNotifier notifier,
  ) {
    // Loading (come StringTestPage)
    if (state.status == ConsigliStatus.loading || state.status == ConsigliStatus.initial) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppTokens.r12,
          side: BorderSide(color: t.border, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: t.accent,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Caricamento consigli...',
                style: tt.bodySmall?.copyWith(color: t.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    // Errore (come StringTestPage)
    if (state.status == ConsigliStatus.error) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppTokens.r12,
          side: BorderSide(color: t.red.withOpacity(0.3), width: 1),
        ),
        color: t.red.withOpacity(0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Row(
            children: [
              Icon(Icons.error_outline, color: t.red, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  state.errorMessage ?? 'Impossibile caricare i consigli',
                  style: tt.bodySmall?.copyWith(color: t.textSecondary),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Nessun consiglio (come StringTestPage quando entity == null)
    if (state.consigli.isEmpty || state.current == null) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppTokens.r12,
          side: BorderSide(color: t.border, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lightbulb_outline, color: t.textMuted, size: 22),
              const SizedBox(width: 12),
              Text(
                '💡 Aggiungi il primo consiglio sul database!',
                style: tt.bodySmall?.copyWith(color: t.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    // Mostra la frase corrente (come StringTestPage mostra entity.value)
    final consiglio = state.current!;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.topCenter,
          children: <Widget>[
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      transitionBuilder: (child, animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: InkWell(
        key: ValueKey(consiglio.id),
        onTap: () => notifier.skipToNext(),
        borderRadius: AppTokens.r12,
        child: Container(
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: AppTokens.r12,
            border: Border.all(color: t.accent.withOpacity(0.3), width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icona + categoria (badge)
                Row(
                  children: [
                    _categoriaIcon(consiglio.categoria, t),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: t.accent.withOpacity(0.12),
                        borderRadius: AppTokens.r8,
                      ),
                      child: Text(
                        _categoriaLabel(consiglio.categoria),
                        style: tt.labelSmall?.copyWith(color: t.accent),
                      ),
                    ),
                    const Spacer(),
                    // Hint "tocca per saltare"
                    // Azione rapida: prossimo consiglio
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () => notifier.skipToNext(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 18,
                                color: t.accent,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // La frase (con virgolette decorative)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '„',
                      style: AppTokens.scoreSmallStyle.copyWith(
                        color: t.accent.withOpacity(0.5),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        consiglio.text,
                        style: tt.bodyMedium?.copyWith(color: t.textPrimary),
                      ),
                    ),
                    Text(
                      '“',
                      style: AppTokens.scoreSmallStyle.copyWith(
                        color: t.accent.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),

                // Autore (se presente)
                if (consiglio.autore != null && consiglio.autore!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12, left: 28),
                    child: Text(
                      '— ${consiglio.autore}',
                      style: tt.bodySmall?.copyWith(color: t.textSecondary),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
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
