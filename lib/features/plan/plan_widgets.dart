import 'package:flutter/material.dart';

import '../../core/health/health_rules.dart';
import '../../core/models/enums.dart';
import '../../core/models/plan.dart';
import '../../core/models/profile.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/util/date_utils.dart';
import '../../core/widgets/app_widgets.dart';

/// 设备显示顺序（与条件面板一致）。
const equipmentOrder = <String>[
  'induction',
  'microwave',
  'riceCooker',
  'oven',
  'airFryer',
];

const equipmentLabels = <String, String>{
  'induction': '电磁炉',
  'microwave': '微波炉',
  'riceCooker': '电饭煲',
  'oven': '烤箱',
  'airFryer': '空气炸锅',
};

const tastePriorityLabels = <String, String>{
  'taste': '味道优先',
  'balanced': '均衡',
  'health': '健康优先',
};

const lazinessLabels = <String, String>{
  'noCook': '不想切菜',
  'canPrep': '可以洗切',
  'mealPrep': '愿意备餐',
};

/// 可选的口味/形态排除标签（与食谱 tasteTags 精确匹配）。
const exclusionTagOptions = <String>['辣', '咸', '油炸', '汤'];

String equipmentLabel(String id) => equipmentLabels[id] ?? id;

String equipmentSummary(Set<String> equipment) {
  if (equipment.isEmpty) return '不做饭';
  final known = equipmentOrder
      .where(equipment.contains)
      .map(equipmentLabel)
      .toList(growable: false);
  final extra = equipment
      .where((e) => !equipmentOrder.contains(e))
      .map(equipmentLabel)
      .toList(growable: false);
  return [...known, ...extra].join(' / ');
}

String constraintsSummary(PlanConstraints constraints) {
  final parts = <String>[
    equipmentSummary(constraints.equipment),
    '≤ ${constraints.maxMinutes} 分钟',
    '≤ ¥${constraints.maxCost.round()}/餐',
    tastePriorityLabels[constraints.tastePriority] ?? '均衡',
    lazinessLabels[constraints.laziness] ?? '可以洗切',
  ];
  return parts.join(' · ');
}

String planRangeLabel(MealPlan plan) {
  final days = dateRange(plan.startDate, plan.endDate).length;
  if (plan.startDate == plan.endDate) {
    return '${formatDateWithWeekday(plan.startDate)} · 单日';
  }
  return '${formatDate(plan.startDate)} – ${formatDate(plan.endDate)} · $days 天';
}

/// 引擎对单日计划统一命名「明日补丁餐」；如果实际从今天开始，按真实起点显示。
String planDisplayName(MealPlan plan) {
  final today = todayKey();
  if (plan.startDate == today && plan.endDate == today && plan.name.startsWith('明日')) {
    return '今天补丁餐';
  }
  return plan.name;
}

String mealSlotOrderKey(MealSlot slot) => switch (slot) {
      MealSlot.breakfast => '0-breakfast',
      MealSlot.lunch => '1-lunch',
      MealSlot.dinner => '2-dinner',
      MealSlot.snack => '3-snack',
    };

/// 数量显示：≥10 取整，其余保留 1 位，避免「+3.24 mg」这类噪声。
String formatAmount(double value) {
  if (value == 0) return '0';
  if (value >= 10) return value.round().toString();
  return value.toStringAsFixed(1);
}

class PlanChoiceChip extends StatelessWidget {
  const PlanChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final fg = selected ? t.accentInk : t.inkSecondary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(t.isQ ? t.pillRadius : t.radiusMd),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? t.accent : t.surface,
            borderRadius: BorderRadius.circular(t.isQ ? t.pillRadius : t.radiusMd),
            border: Border.all(
              color: selected ? t.accent : t.hairline,
              width: t.borderWidth,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: fg),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: fg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 离散档位滑块（时间 10/20/30/45/60，预算 10–60）。
class PlanStepSlider extends StatelessWidget {
  const PlanStepSlider({
    super.key,
    required this.values,
    required this.index,
    required this.onChanged,
    required this.formatValue,
    this.hint,
  });

  final List<num> values;
  final int index;
  final ValueChanged<int> onChanged;
  final String Function(num value) formatValue;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final maxIndex = values.length - 1;
    final safeIndex = index.clamp(0, maxIndex);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatValue(values[safeIndex]),
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(color: t.ink),
            ),
            if (hint != null) ...[
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(hint!, style: Theme.of(context).textTheme.bodySmall),
              ),
            ],
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: t.accent,
            inactiveTrackColor: t.surfaceAlt,
            thumbColor: t.accent,
            overlayColor: t.accent.withValues(alpha: 0.10),
            trackHeight: t.isQ ? 6 : 3,
            tickMarkShape: SliderTickMarkShape.noTickMark,
          ),
          child: Slider(
            value: safeIndex.toDouble(),
            min: 0,
            max: maxIndex.toDouble(),
            divisions: maxIndex == 0 ? null : maxIndex,
            label: formatValue(values[safeIndex]),
            onChanged: (value) => onChanged(value.round()),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              for (final value in values)
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      formatValue(value),
                      maxLines: 1,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 「按你的健康档案」提示卡：避免 / 限制 / 推荐 / 需就医。
/// 只解释规则，不做诊断；规则本身由 HealthRules 计算，不经过 LLM。
class PlanHealthRulesCard extends StatefulWidget {
  const PlanHealthRulesCard({super.key, required this.profile});

  final HealthProfile? profile;

  @override
  State<PlanHealthRulesCard> createState() => _PlanHealthRulesCardState();
}

class _PlanHealthRulesCardState extends State<PlanHealthRulesCard> {
  bool _expanded = false;

  static const _order = <HealthRuleCategory>[
    HealthRuleCategory.avoid,
    HealthRuleCategory.limit,
    HealthRuleCategory.recommend,
    HealthRuleCategory.seeDoctor,
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final rules = HealthRules.forProfile(widget.profile);
    if (rules.isEmpty) {
      return AppCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.health_and_safety_outlined, size: 18, color: t.inkTertiary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('健康档案未填写疾病/过敏', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(
                    '计划只按评分缺口和你填的偏好排序；补一个慢性病/过敏，条件面板会自动避开。',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final groups = <HealthRuleCategory, List<HealthRule>>{};
    for (final category in _order) {
      final items = rules.where((r) => r.category == category).toList();
      if (items.isNotEmpty) groups[category] = items;
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.health_and_safety_outlined, size: 18, color: t.inkSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text('按你的健康档案', style: Theme.of(context).textTheme.titleSmall),
              ),
              Text(
                '${rules.length} 条',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final entry in groups.entries) ...[
            _RuleGroup(
              category: entry.key,
              rules: entry.value,
              expanded: _expanded,
            ),
            const SizedBox(height: 8),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() => _expanded = !_expanded),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(_expanded ? '收起依据' : '展开依据'),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: t.surfaceAlt,
              borderRadius: BorderRadius.circular(t.radiusSm),
            ),
            child: Text(
              '这些是备餐筛选依据，不是医疗诊断；用药、化验和症状请找医生。',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: t.inkSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _RuleGroup extends StatelessWidget {
  const _RuleGroup({
    required this.category,
    required this.rules,
    required this.expanded,
  });

  final HealthRuleCategory category;
  final List<HealthRule> rules;
  final bool expanded;

  Color _color(AppTokens t) => switch (category) {
        HealthRuleCategory.avoid => t.veryHigh,
        HealthRuleCategory.limit => t.high,
        HealthRuleCategory.recommend => t.good,
        HealthRuleCategory.seeDoctor => t.low,
      };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = _color(t);
    final visible = expanded ? rules : rules.take(2).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              category.label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color),
            ),
            const SizedBox(width: 6),
            Text(
              '${rules.length}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
        const SizedBox(height: 4),
        for (final rule in visible)
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '『${rule.condition.label}』${rule.title}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: t.ink,
                      ),
                ),
                if (expanded && rule.detail.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      rule.detail,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: t.inkSecondary,
                            height: 1.45,
                          ),
                    ),
                  ),
              ],
            ),
          ),
        if (!expanded && rules.length > 2)
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              '还有 ${rules.length - 2} 条，点下方展开',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
      ],
    );
  }
}

class PlanNotesCard extends StatelessWidget {
  const PlanNotesCard({super.key, required this.notes, this.onDismiss});

  final List<String> notes;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (notes.isEmpty) return const SizedBox.shrink();
    return AppCard(
      color: t.surfaceAlt,
      showBorder: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tips_and_updates_outlined, size: 16, color: t.inkSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text('这次生成的调整', style: Theme.of(context).textTheme.labelMedium),
              ),
              if (onDismiss != null)
                InkWell(
                  onTap: onDismiss,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.close_rounded, size: 16, color: t.inkTertiary),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          for (final note in notes)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                '· $note',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.45),
              ),
            ),
        ],
      ),
    );
  }
}
