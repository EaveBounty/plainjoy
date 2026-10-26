import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/models/entry.dart';
import '../../../core/models/enums.dart';
import '../../../core/models/food.dart';
import '../../../core/models/nutrients.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_widgets.dart';

const foodCategoryLabels = <String, String>{
  'staple': '主食',
  'vegetable': '蔬菜',
  'fruit': '水果',
  'meat': '肉类',
  'fish': '水产',
  'egg': '蛋类',
  'dairy': '奶类',
  'bean': '豆类',
  'nut': '坚果',
  'soup': '汤',
  'dish': '菜肴',
  'drink': '饮品',
  'condiment': '调味',
  'snack': '零食',
  'supplement': '补剂',
  'other': '其他',
};

String categoryLabel(String category) => foodCategoryLabels[category] ?? '其他';

typedef NutrientRange = ({double p10, double p50, double p90});

/// 千分位，避免引入额外的本地化初始化。
String groupDigits(num value) {
  final rounded = value.round().abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < rounded.length; i++) {
    if (i > 0 && (rounded.length - i) % 3 == 0) buffer.write(',');
    buffer.write(rounded[i]);
  }
  return value < 0 ? '-$buffer' : buffer.toString();
}

String formatGrams(double grams) {
  if (grams >= 1000) return '${(grams / 1000).toStringAsFixed(1)} kg';
  return '${grams.round()} g';
}

String formatGramRange(NutrientRange range) =>
    '${range.p10.round()}–${range.p90.round()} g';

String formatKcal(double kcal) => groupDigits(kcal);

String formatKcalRange(NutrientRange range) =>
    '${formatKcal(range.p10)}–${formatKcal(range.p90)} kcal';

String timeLabel(int ms) =>
    DateFormat('HH:mm').format(DateTime.fromMillisecondsSinceEpoch(ms));

String inputModeLabel(InputMode mode) => switch (mode) {
  InputMode.manual => '手动',
  InputMode.text => '文字',
  InputMode.photo => '照片',
  InputMode.plan => '计划',
  InputMode.quick => '常吃',
};

IconData inputModeIcon(InputMode mode) => switch (mode) {
  InputMode.manual => Icons.edit_outlined,
  InputMode.text => Icons.notes_rounded,
  InputMode.photo => Icons.photo_camera_outlined,
  InputMode.plan => Icons.event_note_outlined,
  InputMode.quick => Icons.bolt_outlined,
};

String confidenceLabel(double confidence) {
  if (confidence >= 0.75) return '高';
  if (confidence >= 0.5) return '中';
  return '低';
}

Color confidenceColor(AppTokens t, double confidence) {
  if (confidence >= 0.75) return t.good;
  if (confidence >= 0.5) return t.inkSecondary;
  return t.unknown;
}

NutrientRange foodKcalRange(
  Food food, {
  required double p10,
  required double p50,
  required double p90,
}) {
  final per100 = food.nutrient(NutrientCode.energy);
  return (
    p10: per100 * p10 / 100,
    p50: per100 * p50 / 100,
    p90: per100 * p90 / 100,
  );
}

NutrientRange itemNutrientRange(EntryItem item, String code) {
  if (item.gramsP50 <= 0) return (p10: 0.0, p50: 0.0, p90: 0.0);
  final density = item.nutrient(code) / item.gramsP50;
  return (
    p10: density * item.gramsP10,
    p50: density * item.gramsP50,
    p90: density * item.gramsP90,
  );
}

NutrientRange entriesNutrientRange(Iterable<FoodEntry> entries, String code) {
  var p10 = 0.0;
  var p50 = 0.0;
  var p90 = 0.0;
  for (final entry in entries) {
    for (final item in entry.items) {
      final range = itemNutrientRange(item, code);
      p10 += range.p10;
      p50 += range.p50;
      p90 += range.p90;
    }
  }
  return (p10: p10, p50: p50, p90: p90);
}

/// 用旧条目的营养快照反推一个临时 Food，供「原食物已丢失」时继续用份量弹层。
Food foodSnapshotFromItem(EntryItem item) {
  final factor = item.gramsP50 > 0 ? 100 / item.gramsP50 : 0.0;
  return Food(
    id: item.foodId ?? 'snapshot:${item.id}',
    name: item.foodName,
    category: 'other',
    source: 'snapshot',
    nutrientsPer100g: {
      for (final e in item.nutrientSnapshot.entries) e.key: e.value * factor,
    },
    groupsPer100g: {
      for (final e in item.groupSnapshot.entries) e.key: e.value * factor,
    },
    defaultServingGrams: item.gramsP50 > 0 ? item.gramsP50 : null,
    createdAt: 0,
    updatedAt: 0,
  );
}

/// 按新份量重建条目；food 为空时按原快照线性缩放。
EntryItem rebuildItem({
  required EntryItem base,
  required double p10,
  required double p50,
  required double p90,
  required EstimateMethod method,
  double? confidence,
  String? containerId,
  String? referenceObjectId,
  Food? food,
}) {
  final source = food ?? foodSnapshotFromItem(base);
  final factor = p50 / 100;
  return EntryItem(
    id: base.id,
    foodId: food?.id ?? base.foodId,
    foodName: food?.name ?? base.foodName,
    gramsP10: p10,
    gramsP50: p50,
    gramsP90: p90,
    method: method,
    confidence: confidence ?? base.confidence,
    containerId: containerId,
    referenceObjectId: referenceObjectId,
    nutrientSnapshot: {
      for (final e in source.nutrientsPer100g.entries) e.key: e.value * factor,
    },
    groupSnapshot: {
      for (final e in source.groupsPer100g.entries) e.key: e.value * factor,
    },
    position: base.position,
  );
}

List<Food> recentFoods(
  Iterable<FoodEntry> entries,
  Map<String, Food> byId, {
  int limit = 8,
}) {
  final seen = <String>{};
  final out = <Food>[];
  final sorted = entries.toList()
    ..sort((a, b) => b.eatenAtMs.compareTo(a.eatenAtMs));
  for (final entry in sorted) {
    for (final item in entry.items) {
      final id = item.foodId;
      if (id == null || !seen.add(id)) continue;
      final food = byId[id];
      if (food == null) continue;
      out.add(food);
      if (out.length >= limit) return out;
    }
  }
  return out;
}

List<Food> frequentFoods(
  Iterable<FoodEntry> entries,
  Map<String, Food> byId, {
  int limit = 8,
}) {
  final counts = <String, int>{};
  final lastSeen = <String, int>{};
  for (final entry in entries) {
    for (final item in entry.items) {
      final id = item.foodId;
      if (id == null || !byId.containsKey(id)) continue;
      counts[id] = (counts[id] ?? 0) + 1;
      final prev = lastSeen[id] ?? 0;
      if (entry.eatenAtMs > prev) lastSeen[id] = entry.eatenAtMs;
    }
  }
  final ids = counts.keys.toList()
    ..sort((a, b) {
      final byCount = counts[b]!.compareTo(counts[a]!);
      if (byCount != 0) return byCount;
      return lastSeen[b]!.compareTo(lastSeen[a]!);
    });
  return ids.take(limit).map((id) => byId[id]!).toList();
}

double? historyMedianGrams(Iterable<FoodEntry> entries, String foodId) {
  final values = <double>[];
  for (final entry in entries) {
    for (final item in entry.items) {
      if (item.foodId == foodId && item.gramsP50 > 0) values.add(item.gramsP50);
    }
  }
  if (values.isEmpty) return null;
  values.sort();
  final mid = values.length ~/ 2;
  if (values.length.isOdd) return values[mid];
  return (values[mid - 1] + values[mid]) / 2;
}

void showToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      duration: const Duration(milliseconds: 1400),
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
    ),
  );
}

/// 段选控件：少数派风格，选项由外部提供。
class SegmentedChoice<T> extends StatelessWidget {
  final List<T> values;
  final T selected;
  final String Function(T value) label;
  final ValueChanged<T> onChanged;
  final bool dense;

  const SegmentedChoice({
    super.key,
    required this.values,
    required this.selected,
    required this.label,
    required this.onChanged,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: t.surfaceAlt,
        borderRadius: BorderRadius.circular(t.isQ ? t.pillRadius : t.radiusMd),
      ),
      child: Row(
        children: [
          for (final value in values)
            Expanded(
              child: Semantics(
                selected: value == selected,
                button: true,
                child: InkWell(
                  borderRadius: BorderRadius.circular(
                    t.isQ ? t.pillRadius : t.radiusSm,
                  ),
                  onTap: () => onChanged(value),
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: t.motionMs.round()),
                    curve: t.motionCurve,
                    padding: EdgeInsets.symmetric(vertical: dense ? 7 : 10),
                    decoration: BoxDecoration(
                      color: value == selected ? t.accent : Colors.transparent,
                      borderRadius: BorderRadius.circular(
                        t.isQ ? t.pillRadius : t.radiusSm,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      label(value),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: value == selected ? t.accentInk : t.inkSecondary,
                        fontWeight: value == selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 带说明的选项块，用于容器/参照物/剩饭比例。
class ChoicePill extends StatelessWidget {
  final String label;
  final String? hint;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool expand;

  const ChoicePill({
    super.key,
    required this.label,
    this.hint,
    this.selected = false,
    this.onTap,
    this.icon,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: selected ? t.accent.withValues(alpha: 0.08) : t.surface,
        borderRadius: BorderRadius.circular(t.isQ ? t.pillRadius : t.radiusMd),
        border: Border.all(
          color: selected ? t.accent : t.hairline,
          width: selected ? (t.isQ ? 2 : 1.5) : t.borderWidth,
        ),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: selected ? t.ink : t.inkSecondary),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: selected ? t.ink : t.inkSecondary,
                  ),
                ),
                if (hint != null)
                  Text(
                    hint!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return content;
    return InkWell(
      borderRadius: BorderRadius.circular(t.isQ ? t.pillRadius : t.radiusMd),
      onTap: onTap,
      child: content,
    );
  }
}

class MethodChip extends StatelessWidget {
  final EstimateMethod method;
  final String? suffix;

  const MethodChip(this.method, {super.key, this.suffix});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Pill(
      suffix == null ? method.label : '${method.label} · $suffix',
      color: t.inkSecondary,
      icon: switch (method) {
        EstimateMethod.weighed => Icons.scale_outlined,
        EstimateMethod.container => Icons.rice_bowl_outlined,
        EstimateMethod.reference => Icons.back_hand_outlined,
        EstimateMethod.visual => Icons.visibility_outlined,
        EstimateMethod.ai => Icons.auto_awesome_outlined,
        EstimateMethod.plan => Icons.event_note_outlined,
      },
    );
  }
}

class StatBlock extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final String? sub;
  final Color? valueColor;

  const StatBlock({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.sub,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: valueColor ?? t.ink,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            if (unit != null) ...[
              const SizedBox(width: 3),
              Text(
                unit!,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: valueColor ?? t.inkTertiary,
                ),
              ),
            ],
          ],
        ),
        if (sub != null) ...[
          const SizedBox(height: 3),
          Text(
            sub!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

/// 区间条：先给区间，再让人理解中位数在哪。
class RangeBar extends StatelessWidget {
  final NutrientRange range;
  final Color? color;
  final double height;

  const RangeBar({super.key, required this.range, this.color, this.height = 6});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = color ?? t.inkSecondary;
    final maxValue = range.p90 > 0 ? range.p90 * 1.12 : 1.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final left = (range.p10 / maxValue).clamp(0.0, 1.0) * width;
        final right = (range.p90 / maxValue).clamp(0.0, 1.0) * width;
        final tick = (range.p50 / maxValue).clamp(0.0, 1.0) * width;
        return SizedBox(
          height: height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: t.surfaceAlt,
                  borderRadius: BorderRadius.circular(t.pillRadius),
                ),
              ),
              Positioned(
                left: left,
                width: (right - left).clamp(2.0, width),
                top: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(t.pillRadius),
                  ),
                ),
              ),
              Positioned(
                left: (tick - (t.isQ ? 2 : 1)).clamp(0.0, width - 2),
                width: t.isQ ? 4 : 2,
                top: -2,
                bottom: -2,
                child: Container(color: c),
              ),
            ],
          ),
        );
      },
    );
  }
}
