import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/enums.dart';
import '../../core/models/plan.dart';
import '../../core/state/app_state.dart';
import '../../core/state/score_providers.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_widgets.dart';
import 'pet_stage.dart';

Future<void> showFeedEffectSheet(
  BuildContext context, {
  required PlanMeal meal,
  int coins = 3,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => FeedEffectSheet(meal: meal, coins: coins),
  );
}

class FeedEffectSheet extends ConsumerWidget {
  final PlanMeal meal;
  final int coins;

  const FeedEffectSheet({super.key, required this.meal, this.coins = 3});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final data = ref.watch(dataProvider);
    final pet = data?.activePet;
    final state = ref.watch(petStateProvider);
    final kcal = meal.nutrients['energy_kcal'] ?? 0;
    final protein = meal.nutrients['protein_g'] ?? 0;
    final sodium = meal.nutrients['sodium_mg'] ?? 0;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: AppCard(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: t.hairline,
                  borderRadius: BorderRadius.circular(t.pillRadius),
                ),
              ),
              if (pet != null)
                PetStage(
                  species: pet.species,
                  signal: PetSignal.hungry,
                  axes: state.axes,
                  height: 168,
                  animated: true,
                ),
              Text(
                pet == null ? '已投喂' : '已投喂 ${pet.name}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                '它把「${meal.title}」吃完了。',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  for (final reason in meal.reasons.take(4))
                    Pill(reason, color: t.good, filled: true),
                  Pill('${kcal.round()} kcal', color: t.inkSecondary),
                  if (protein > 0)
                    Pill('蛋白质 ${protein.toStringAsFixed(1)} g', color: t.inkSecondary),
                  if (sodium > 0)
                    Pill('钠 ${sodium.round()} mg', color: sodium > 800 ? t.high : t.inkSecondary),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: t.surfaceAlt,
                  borderRadius: BorderRadius.circular(t.radiusMd),
                ),
                child: Row(
                  children: [
                    Icon(Icons.pets_rounded, color: t.accent, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '+$coins 爪印 · 已记入 ${meal.localDate} ${meal.slot.label}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '这不是额外的食物；只是把你刚吃的那餐映射给它，让状态和记录保持一致。',
                style: Theme.of(context).textTheme.labelSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('继续'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
