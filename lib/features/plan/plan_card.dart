import 'package:flutter/material.dart';

import '../../core/models/enums.dart';
import '../../core/models/food.dart';
import '../../core/models/nutrients.dart';
import '../../core/models/plan.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_widgets.dart';
import 'plan_widgets.dart';
import 'sodium_ledger.dart';

/// 单张补丁餐卡片。
/// 首屏只给「菜名 + 补什么 + 时间/成本/钠」，热量和步骤折叠。
class PlanMealCard extends StatefulWidget {
  const PlanMealCard({
    super.key,
    required this.meal,
    required this.recipe,
    this.foods = const {},
    this.busy = false,
    this.onEat,
    this.onSwap,
  });

  final PlanMeal meal;
  final Recipe? recipe;
  final Map<String, Food> foods;
  final bool busy;
  final VoidCallback? onEat;
  final VoidCallback? onSwap;

  @override
  State<PlanMealCard> createState() => _PlanMealCardState();
}

class _PlanMealCardState extends State<PlanMealCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final meal = widget.meal;
    final sodium = meal.nutrient(NutrientCode.sodium);
    final energy = meal.nutrient(NutrientCode.energy);
    final protein = meal.nutrient(NutrientCode.protein);
    final steps = meal.steps.isNotEmpty
        ? meal.steps
        : (widget.recipe?.steps ?? const <String>[]);
    final ingredients = widget.recipe?.ingredients ?? const <RecipeIngredient>[];

    final sodiumColor = sodium > 1200
        ? t.veryHigh
        : sodium > 800
            ? t.high
            : t.inkSecondary;

    return AppCard(
      color: meal.done ? t.surfaceAlt : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: BorderRadius.circular(t.radiusSm),
                  border: Border.all(color: t.hairline, width: t.borderWidth),
                ),
                child: Text(
                  meal.slot.label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: t.inkSecondary,
                      ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  meal.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (meal.done)
                Pill('已记录', color: t.good, icon: Icons.check_rounded, filled: true),
            ],
          ),
          if (meal.reasons.isNotEmpty) ...[
            const SizedBox(height: 9),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final reason in meal.reasons.take(3))
                  Pill(
                    reason,
                    color: reason.contains('钠') && reason.contains('偏高')
                        ? t.high
                        : t.good,
                    filled: true,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _MealMeta(icon: Icons.schedule_rounded, text: '${meal.minutes} 分钟'),
              _MealMeta(icon: Icons.payments_outlined, text: '¥${formatAmount(meal.cost)}'),
              _MealMeta(
                icon: Icons.water_drop_outlined,
                text: '钠 ${sodium.round()} mg',
                color: sodiumColor,
              ),
            ],
          ),
          if (_expanded) ...[
            const SizedBox(height: 10),
            Hairline(),
            const SizedBox(height: 10),
            Wrap(
              spacing: 14,
              runSpacing: 4,
              children: [
                _MealMeta(
                  icon: Icons.local_fire_department_outlined,
                  text: '${energy.round()} kcal',
                ),
                _MealMeta(
                  icon: Icons.egg_alt_outlined,
                  text: '蛋白质 ${protein.toStringAsFixed(1)} g',
                ),
                _MealMeta(
                  icon: Icons.scale_outlined,
                  text: '约 ${meal.grams.round()} g',
                ),
              ],
            ),
            if (ingredients.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                ingredients
                    .where((e) => e.note != '调味·估算')
                    .map((e) => '${_foodName(e)} ${e.grams.round()} g')
                    .join(' · '),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(height: 1.5),
              ),
              SodiumLedger(ingredients: ingredients, foods: widget.foods),
            ],
            const SizedBox(height: 8),
            if (steps.isEmpty)
              Text('没有分步说明，按常规做法即可。', style: Theme.of(context).textTheme.bodySmall)
            else
              for (var i = 0; i < steps.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${i + 1}.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: t.inkTertiary,
                            ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          steps[i],
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: t.ink,
                                height: 1.5,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: const Size(0, 34),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: t.inkSecondary,
                ),
                child: Text(_expanded ? '收起' : '步骤'),
              ),
              const Spacer(),
              OutlinedButton(
                onPressed: (widget.busy || meal.done) ? null : widget.onSwap,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  side: BorderSide(color: t.hairline, width: t.borderWidth),
                  foregroundColor: t.ink,
                  textStyle: Theme.of(context).textTheme.labelMedium,
                ),
                child: const Text('换一个'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: (widget.busy || meal.done) ? null : widget.onEat,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  textStyle: Theme.of(context).textTheme.labelMedium,
                ),
                child: Text(meal.done ? '已记录' : '吃掉它'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _foodName(RecipeIngredient ingredient) {
    final food = widget.foods[ingredient.foodId];
    if (food != null) return food.name;
    final note = ingredient.note;
    if (note != null && note.isNotEmpty) return note;
    return ingredient.foodId.replaceAll('_', ' ');
  }
}

class _MealMeta extends StatelessWidget {
  const _MealMeta({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = color ?? t.inkSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: c),
        const SizedBox(width: 4),
        Text(
          text,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(color: c),
        ),
      ],
    );
  }
}
