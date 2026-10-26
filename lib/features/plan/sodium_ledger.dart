import 'package:flutter/material.dart';

import '../../core/models/food.dart';
import '../../core/models/nutrients.dart';
import '../../core/models/plan.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_widgets.dart';

/// 钠账本：把一道菜的钠拆到每种原料，尤其是盐/生抽/老抽/味精/蚝油。
///
/// 中式烹饪的钠大头往往不是「咸」，而是复配调味：生抽 + 老抽 + 蚝油 + 鸡精
/// 叠加后很容易超过 2000 mg。这里只做估算，区间 ±15%。
class SodiumLedger extends StatelessWidget {
  const SodiumLedger({
    super.key,
    required this.ingredients,
    required this.foods,
  });

  final List<RecipeIngredient> ingredients;
  final Map<String, Food> foods;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final rows = <_SodiumRow>[];
    for (final ingredient in ingredients) {
      final food = foods[ingredient.foodId];
      if (food == null) continue;
      final mg = food.nutrient(NutrientCode.sodium) * ingredient.grams / 100.0;
      if (mg < 1) continue;
      rows.add(_SodiumRow(
        name: food.name,
        mg: mg,
        grams: ingredient.grams,
        tags: food.tags,
      ));
    }
    rows.sort((a, b) => b.mg.compareTo(a.mg));
    final total = rows.fold<double>(0, (sum, row) => sum + row.mg);
    if (total < 1) return const SizedBox.shrink();

    final top = rows.take(4).toList();
    final rest = total - top.fold<double>(0, (sum, row) => sum + row.mg);
    final hasIodized = rows.any((e) => e.tags.contains('iodized'));
    final hasSoy = rows.any((e) => e.name.contains('生抽') || e.name.contains('老抽'));
    final hasMsg = rows.any((e) => e.name.contains('味精') || e.name.contains('鸡精'));

    final notes = <String>[
      if (hasIodized) '加碘盐按 25 mg/kg 估：1 g 盐 ≈ 25 μg 碘',
      if (hasSoy) '生抽 6.6 g 钠/100 g、老抽 7.0 g 钠/100 g，颜色深不等于更咸',
      if (hasMsg) '味精 1 g ≈ 123 mg 钠，鸡精还要再加盐',
      if (!hasSoy && !hasIodized && !hasMsg) '未计入调味：实际钠可能更高',
    ];

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: t.surfaceAlt.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(t.radiusMd),
        border: Border.all(color: t.hairline, width: t.borderWidth),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.water_drop_outlined, size: 14, color: t.inkSecondary),
              const SizedBox(width: 5),
              Text('钠账本', style: Theme.of(context).textTheme.labelLarge),
              const Spacer(),
              Text(
                '${total.round()} mg · 盐 ${(total / 393.7).toStringAsFixed(1)} g',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: total > 800 ? t.high : t.inkSecondary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final row in top) ...[
            _Bar(row: row, total: total),
            const SizedBox(height: 5),
          ],
          if (rest > 1)
            Text(
              '其余 ${rest.round()} mg',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: t.inkTertiary),
            ),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 6),
            Hairline(),
            const SizedBox(height: 6),
            for (final note in notes)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  note,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(height: 1.5),
                ),
              ),
          ],
          const SizedBox(height: 4),
          Text(
            '区间 ${(total * 0.85).round()}–${(total * 1.15).round()} mg；按家常用量估算。',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: t.inkTertiary),
          ),
        ],
      ),
    );
  }
}

class _SodiumRow {
  final String name;
  final double mg;
  final double grams;
  final List<String> tags;

  const _SodiumRow({
    required this.name,
    required this.mg,
    required this.grams,
    required this.tags,
  });
}

class _Bar extends StatelessWidget {
  const _Bar({required this.row, required this.total});

  final _SodiumRow row;
  final double total;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final ratio = (row.mg / total).clamp(0.0, 1.0);
    return Row(
      children: [
        SizedBox(
          width: 86,
          child: Text(
            row.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 4,
              backgroundColor: t.hairline,
              valueColor: AlwaysStoppedAnimation(
                ratio > 0.5 ? t.high : t.inkSecondary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 54,
          child: Text(
            '${row.mg.round()} mg',
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
      ],
    );
  }
}
