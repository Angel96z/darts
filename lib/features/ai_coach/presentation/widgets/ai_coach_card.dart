import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app_theme.dart';
import '../../../stats/presentation/widgets/unified_stats_chart.dart';
import '../../application/ai_coach_controller.dart';
import '../../domain/ai_coach_models.dart';

class AiCoachCard extends ConsumerWidget {
  final AiCoachInput input;

  const AiCoachCard({
    super.key,
    required this.input,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppTokens.of(context);
    final tt = Theme.of(context).textTheme;
    final state = ref.watch(aiCoachControllerProvider(input.fingerprint));
    final controller = ref.read(aiCoachControllerProvider(input.fingerprint).notifier);

    final hasFreshAdvice = state.hasFreshAdviceFor(input);
    final isLoading = state.status == AiCoachStatus.loading;

    return UnifiedStatsCard(
      title: 'AI COACH',
      subtitle: 'Analisi dei dati.',
      info: const UnifiedStatsInfoData(
        title: 'Come funziona AI Coach',
        text:
        'Genera un consiglio analizzando le tue statistiche sul settore.',
        advice: [
          'Prendi spunto e approfondisci i consigli! Cercherà di darti un riscontro temporale, su potenziali pattern delle singole freccette, e sugli stati d\'animo.',
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!hasFreshAdvice && state.status != AiCoachStatus.error)
              Text(
                'Premi il bottone per generare un consiglio tecnico sui dati attuali.',
                style: tt.bodySmall?.copyWith(color: t.textMuted),
              ),
            if (state.status == AiCoachStatus.error) ...[
              Text(
                state.errorMessage ?? 'Errore sconosciuto',
                style: tt.bodySmall?.copyWith(color: t.red),
              ),
              const SizedBox(height: 10),
            ],
            if (hasFreshAdvice) ...[
              _AdviceBlock(advice: state.advice!, t: t),
              const SizedBox(height: 12),
            ],
            FilledButton.icon(
              onPressed: isLoading ? null : () => controller.generate(input),
              icon: isLoading
                  ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: t.accentFg,
                ),
              )
                  : const Icon(Icons.auto_awesome_rounded),
              label: Text(hasFreshAdvice ? 'Rigenera consiglio' : 'Chiedi consiglio AI Coach'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdviceBlock extends StatelessWidget {
  final AiCoachAdvice advice;
  final AppTokens t;

  const _AdviceBlock({
    required this.advice,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.surfaceHigh,
        borderRadius: AppTokens.r12,
        border: Border.all(color: t.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(advice.summary, style: tt.titleMedium?.copyWith(color: t.textPrimary)),
            const SizedBox(height: 8),
            Text(advice.mainIssue, style: tt.bodySmall?.copyWith(color: t.textSecondary)),
            const SizedBox(height: 10),
            for (final item in advice.technicalAdvice) ...[
              Text('• $item', style: tt.bodySmall?.copyWith(color: t.textPrimary)),
              const SizedBox(height: 6),
            ],
            const SizedBox(height: 6),
            Text(
              advice.nextDrill,
              style: tt.titleMedium?.copyWith(color: t.accent),
            ),
          ],
        ),
      ),
    );
  }
}
