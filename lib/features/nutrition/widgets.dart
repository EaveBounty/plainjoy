import 'dart:math' as math;

import 'package:flutter/material.dart' hide Interval;

import '../../core/models/entry.dart';
import '../../core/models/enums.dart';
import '../../core/models/food.dart';
import '../../core/models/nutrients.dart';
import '../../core/models/profile.dart';
import '../../core/models/score.dart';
import '../../core/scoring/nutrient_targets.dart';
import '../../core/scoring/score_aggregator.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/util/date_utils.dart';
import '../../core/widgets/app_widgets.dart';
import 'charts.dart';

// ---------------------------------------------------------------------------
// 文案与状态映射
// ---------------------------------------------------------------------------

const _shortLabels = <String, String>{
  'A1': '蔬菜',
  'A2': '水果',
  'A3': '全谷薯',
  'A4': '奶类',
  'A5': '豆坚果',
  'A6': '鱼禽蛋肉',
  'B1': '蛋白质',
  'B2': '纤维',
  'B3': '钙',
  'B4': '铁',
  'B5': '维 A',
  'B6': '维 C',
  'B7': '叶酸B12',
  'C1': '钠',
  'C2': '添加糖',
  'C3': '脂肪质量',
};

String shortLabelFor(String code) => _shortLabels[code] ?? code;

bool isLimitItem(String code) => code == 'C1' || code == 'C2' || code == 'C3';

/// 适宜区间（参考带）只对食物组、蛋白质、纤维、限制项有意义；
/// 微量项的 targetMax 是 UL，不是“越多越好”，不画成区间。
bool isBandItem(String code) =>
    code.startsWith('A') || code == 'B1' || code == 'B2';

bool isCompositeItem(String code) =>
    code == 'A3' || code == 'A6' || code == 'B7';

const _itemNutrientCodes = <String, List<String>>{
  'B1': [NutrientCode.protein],
  'B2': [NutrientCode.fiber],
  'B3': [NutrientCode.calcium],
  'B4': [NutrientCode.iron],
  'B5': [NutrientCode.vitaminA],
  'B6': [NutrientCode.vitaminC],
  'B7': [NutrientCode.folate],
  'C1': [NutrientCode.sodium],
  'C2': [NutrientCode.sugar],
  'C3': [NutrientCode.sfa],
};

const _itemGroupCodes = <String, List<String>>{
  'A1': [FoodGroupCode.vegetable],
  'A2': [FoodGroupCode.fruit],
  'A3': [FoodGroupCode.wholeGrain, FoodGroupCode.tuber],
  'A4': [FoodGroupCode.dairy],
  'A5': [FoodGroupCode.soyNut],
  'A6': [FoodGroupCode.animalProtein, FoodGroupCode.fish],
};

List<String> itemContributionNutrients(String code) =>
    _itemNutrientCodes[code] ?? const [];

List<String> itemContributionGroups(String code) =>
    _itemGroupCodes[code] ?? const [];

bool itemHasData(DayScore day, String code) {
  if (code == 'B7') {
    return day.totals.containsKey(NutrientCode.folate) ||
        day.totals.containsKey(NutrientCode.vitaminB12);
  }
  if (code == 'C3') {
    return day.totals.containsKey(NutrientCode.sfa) ||
        day.totals.containsKey(NutrientCode.tfa);
  }
  final nutrients = _itemNutrientCodes[code];
  if (nutrients != null) return nutrients.any(day.totals.containsKey);
  final groups = _itemGroupCodes[code];
  return groups != null && groups.any(day.groupTotals.containsKey);
}

ScoreStatus displayStatus(DayScore day, ScoreItemResult item) =>
    itemHasData(day, item.code) ? item.status : ScoreStatus.unknown;

Color statusColor(AppTokens t, ScoreStatus status) => switch (status) {
  ScoreStatus.low => t.low,
  ScoreStatus.ok => t.good,
  ScoreStatus.high => t.high,
  ScoreStatus.veryHigh => t.veryHigh,
  ScoreStatus.unknown => t.unknown,
};

String statusGlyph(ScoreStatus status) => switch (status) {
  ScoreStatus.low => '↓',
  ScoreStatus.ok => '✓',
  ScoreStatus.high => '↑',
  ScoreStatus.veryHigh => '↑↑',
  ScoreStatus.unknown => '?',
};

String statusWord(ScoreStatus status) => switch (status) {
  ScoreStatus.low => '不足',
  ScoreStatus.ok => '达标',
  ScoreStatus.high => '偏多',
  ScoreStatus.veryHigh => '明显偏多',
  ScoreStatus.unknown => '未记录',
};

Color scoreColor(AppTokens t, double score) {
  if (score >= 85) return t.good;
  if (score >= 70) return t.ink;
  return t.low;
}

String scoreWord(double score) {
  if (score >= 85) return '稳';
  if (score >= 70) return '够用';
  if (score >= 55) return '待补';
  return '慢慢补';
}

String confidenceLabel(double width) {
  if (width >= 8) return '低';
  if (width >= 4) return '中';
  return '高';
}

String conclusionForDay(DayScore day) {
  final total = day.total;
  if (!day.eligible || total == null) return '记录不足，暂不评分';
  final weakest = weakestItem(day);
  if (weakest == null) return '结构完整，保持这个节奏。';
  final label = shortLabelFor(weakest.code);
  final status = weakest.status;
  if (total >= 85) return '结构完整，保持今天的节奏。';
  if (total >= 70) {
    return isLimitItem(weakest.code)
        ? '整体够用；$label 再收一点会更稳。'
        : '整体够用；$label 再补一点会更稳。';
  }
  if (total >= 55) {
    return status == ScoreStatus.low
        ? '$label 还差一点，是今天最值得补的。'
        : '$label 偏多，是今天最值得改的。';
  }
  return '今天记录到的部分偏少；先看 $label，其余明天再说。';
}

ScoreItemResult? weakestItem(DayScore day) {
  final candidates =
      day.items
          .where((e) => itemHasData(day, e.code) && e.lostPoints >= 0.05)
          .toList()
        ..sort((a, b) => b.lostPoints.compareTo(a.lostPoints));
  return candidates.isEmpty ? null : candidates.first;
}

String? gateSummary(DayScore day) {
  if (day.gates.isEmpty) return null;
  final gate = day.gates.first;
  return '${gate.label} · 分数上限 ${gate.cap.round()}';
}

String targetLabel(ScoreItemResult item) {
  final unit = item.unit;
  if (isLimitItem(item.code)) {
    return '目标 ≤ ${compactNumber(item.targetMax)} $unit';
  }
  if (isBandItem(item.code) && item.targetMax > item.targetMin * 1.12) {
    return '目标 ${compactNumber(item.targetMin)}–${compactNumber(item.targetMax)} $unit';
  }
  return '目标 ≥ ${compactNumber(item.targetMin)} $unit';
}

String actualLabel(ScoreItemResult item) =>
    '${compactNumber(item.intake)} ${item.unit}';

String ratioLabel(DayScore day, ScoreItemResult item) {
  if (!itemHasData(day, item.code)) return '未记录';
  final reference = isLimitItem(item.code) ? item.targetMax : item.targetMin;
  if (reference <= 0) return '';
  final percent = item.intake / reference * 100;
  return '${percent.round()}% ${isLimitItem(item.code) ? '上限' : '目标'}';
}

String shortfallLabel(ScoreItemResult item) {
  final unit = item.unit;
  if (item.status == ScoreStatus.low) {
    final gap = (item.targetMin - item.intake).clamp(0.0, double.infinity);
    return '还差 ${compactNumber(gap)} $unit';
  }
  if (item.status == ScoreStatus.high || item.status == ScoreStatus.veryHigh) {
    final over = (item.intake - item.targetMax).clamp(0.0, double.infinity);
    return '超出 ${compactNumber(over)} $unit';
  }
  return '在范围内';
}

String suggestionForCode(String code) => switch (code) {
  'A1' => '加一拳绿叶菜（约 100–150 g），深色蔬菜占一半。',
  'A2' => '加一个苹果或一小碗莓果（约 150 g），不用果汁替代。',
  'A3' => '白米饭换半碗糙米/燕麦，或加一小块红薯（约 100 g）。',
  'A4' => '加一杯无糖酸奶或 200 ml 牛奶；乳糖不耐换无乳糖奶。',
  'A5' => '加一小把坚果（约 10 g）或一块豆腐（约 100 g）。',
  'A6' => '加一掌心鱼/鸡胸/瘦肉（约 75–100 g），一周两次鱼。',
  'B1' => '加一个鸡蛋或 100 g 鸡胸，蛋白质约 +12–25 g。',
  'B2' => '加一份绿叶菜 + 半碗杂粮饭，纤维约 +6–9 g。',
  'B3' => '加 200 ml 奶或一块北豆腐（约 100 g），钙约 +200–300 mg。',
  'B4' => '加 50 g 瘦牛肉或一份动物肝脏（每周一次），配一个猕猴桃助吸收。',
  'B5' => '加一份胡萝卜/南瓜/深绿叶菜（约 100 g）。',
  'B6' => '加一个猕猴桃或半个彩椒（约 100 g）。',
  'B7' => '加一份深绿叶菜 + 一个鸡蛋；素食者选 B12 强化食品。',
  'C1' => '汤面换清汤，酱油减半（10 ml ≈ 1.6 g 盐），蘸料分开装。',
  'C2' => '甜饮换无糖茶/白水；一瓶甜饮约 30–50 g 糖。',
  'C3' => '少一次煎炸，换蒸/煮/烤；肥肉、酥皮、奶油是饱和脂肪大户。',
  _ => '下一餐先加蔬菜和一掌心蛋白质，比纠结总分更有用。',
};

// ---------------------------------------------------------------------------
// 分数区间 / 标签
// ---------------------------------------------------------------------------

class TagChip extends StatelessWidget {
  const TagChip(
    this.text, {
    super.key,
    this.color,
    this.icon,
    this.filled = false,
  });

  final String text;
  final Color? color;
  final IconData? icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = color ?? t.inkSecondary;
    return LayoutBuilder(
      builder: (context, constraints) {
        final label = Text(
          text,
          maxLines: 2,
          softWrap: true,
          overflow: TextOverflow.fade,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: c,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        );
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: filled ? c.withValues(alpha: 0.10) : Colors.transparent,
            borderRadius: BorderRadius.circular(
              t.isQ ? t.pillRadius : t.radiusSm,
            ),
            border: Border.all(
              color: filled ? c.withValues(alpha: 0.22) : t.hairline,
              width: t.borderWidth,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 13, color: c),
                const SizedBox(width: 4),
              ],
              if (constraints.maxWidth.isFinite)
                Flexible(child: label)
              else
                label,
            ],
          ),
        );
      },
    );
  }
}

class IntervalTag extends StatelessWidget {
  const IntervalTag({super.key, required this.interval, this.prefix = '区间'});

  final Interval? interval;
  final String prefix;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final i = interval;
    if (i == null) {
      return TagChip('单点估算', color: t.inkSecondary);
    }
    return TagChip(
      '$prefix ${i.p10.round()}–${i.p90.round()}',
      color: t.inkSecondary,
      icon: Icons.linear_scale_rounded,
    );
  }
}

class ConfidenceTag extends StatelessWidget {
  const ConfidenceTag({super.key, required this.interval});

  final Interval? interval;

  @override
  Widget build(BuildContext context) {
    final i = interval;
    if (i == null) return const SizedBox.shrink();
    return TagChip('置信度 ${confidenceLabel(i.width)}');
  }
}

class SegmentedTabs extends StatelessWidget {
  const SegmentedTabs({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;

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
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Semantics(
                selected: i == selected,
                button: true,
                label: labels[i],
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onChanged(i),
                    borderRadius: BorderRadius.circular(
                      t.isQ ? t.pillRadius : t.radiusSm,
                    ),
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: t.motionMs.toInt()),
                      curve: t.motionCurve,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: i == selected ? t.accent : Colors.transparent,
                        borderRadius: BorderRadius.circular(
                          t.isQ ? t.pillRadius : t.radiusSm,
                        ),
                      ),
                      child: Text(
                        labels[i],
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: i == selected
                                  ? t.accentInk
                                  : t.inkSecondary,
                              fontSize: 13,
                            ),
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

// ---------------------------------------------------------------------------
// 三域
// ---------------------------------------------------------------------------

class DomainScoresView extends StatelessWidget {
  const DomainScoresView({super.key, required this.scores});

  final Map<ScoreDomain, double> scores;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final domain in ScoreDomain.values)
          Expanded(
            child: Column(
              children: [
                RingScore(
                  value: scores[domain],
                  label: '',
                  size: 72,
                  color: t.ink,
                  semanticLabel:
                      '${domain.label} ${scores[domain]?.round() ?? '暂无'} 分，'
                      '权重 ${(domain.weight * 100).round()}',
                ),
                const SizedBox(height: 4),
                Text(
                  domain.label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: t.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '权重 ${(domain.weight * 100).round()}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: t.inkTertiary),
                ),
                const SizedBox(height: 2),
                Text(
                  _domainWord(scores[domain]),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _domainColor(t, scores[domain]),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  static String _domainWord(double? score) {
    if (score == null) return '未评分';
    if (score >= 80) return '稳';
    if (score >= 60) return '一般';
    return '偏弱';
  }

  static Color _domainColor(AppTokens t, double? score) {
    if (score == null) return t.unknown;
    if (score >= 80) return t.good;
    if (score >= 60) return t.inkSecondary;
    return t.low;
  }
}

// ---------------------------------------------------------------------------
// 关键三数（能量 / 钠 / 纤维）
// ---------------------------------------------------------------------------

class KeyMetricsStrip extends StatelessWidget {
  const KeyMetricsStrip({super.key, required this.day, required this.profile});

  final DayScore day;
  final HealthProfile? profile;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final targets = NutrientTargets.fromProfile(profile);
    final metrics = <_MetricData>[
      _MetricData(
        label: '能量',
        value: day.totals[NutrientCode.energy],
        target: targets.energy,
        unit: 'kcal',
        status: _energyWord(day, targets),
        statusColor: _energyColor(t, day, targets),
      ),
      _MetricData(
        label: '钠',
        value: day.totals[NutrientCode.sodium],
        target: targets.sodiumOk,
        unit: 'mg',
        status: _sodiumWord(day, targets),
        statusColor: _sodiumColor(t, day, targets),
        limit: true,
      ),
      _MetricData(
        label: '膳食纤维',
        value: day.totals[NutrientCode.fiber],
        target: targets.fiber,
        unit: 'g',
        status: _fiberWord(day, targets),
        statusColor: _fiberColor(t, day, targets),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 300) {
          return Column(
            children: [
              for (var i = 0; i < metrics.length; i++) ...[
                _MetricRow(data: metrics[i]),
                if (i != metrics.length - 1) ...[
                  const SizedBox(height: 8),
                  Container(height: t.borderWidth, color: t.hairline),
                  const SizedBox(height: 8),
                ],
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < metrics.length; i++) ...[
              if (i > 0)
                Container(width: t.borderWidth, height: 68, color: t.hairline),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: i == 0 ? 0 : 10,
                    right: i == 2 ? 0 : 10,
                  ),
                  child: _MetricTile(data: metrics[i]),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  static String _energyWord(DayScore day, NutrientTargets targets) {
    final value = day.totals[NutrientCode.energy];
    if (value == null) return '未记录';
    if (value >= targets.energy * 0.9) return '够了';
    return '有缺口';
  }

  static Color _energyColor(
    AppTokens t,
    DayScore day,
    NutrientTargets targets,
  ) {
    final value = day.totals[NutrientCode.energy];
    if (value == null) return t.unknown;
    return value >= targets.energy * 0.9 ? t.good : t.inkSecondary;
  }

  static String _sodiumWord(DayScore day, NutrientTargets targets) {
    final value = day.totals[NutrientCode.sodium];
    if (value == null) return '未记录';
    if (value <= targets.sodiumOk) return '在范围';
    if (value <= targets.sodiumZero) return '偏多';
    return '明显偏多';
  }

  static Color _sodiumColor(
    AppTokens t,
    DayScore day,
    NutrientTargets targets,
  ) {
    final value = day.totals[NutrientCode.sodium];
    if (value == null) return t.unknown;
    if (value <= targets.sodiumOk) return t.good;
    if (value <= targets.sodiumZero) return t.high;
    return t.veryHigh;
  }

  static String _fiberWord(DayScore day, NutrientTargets targets) {
    final value = day.totals[NutrientCode.fiber];
    if (value == null) return '未记录';
    return value >= targets.fiber ? '够了' : '有缺口';
  }

  static Color _fiberColor(AppTokens t, DayScore day, NutrientTargets targets) {
    final value = day.totals[NutrientCode.fiber];
    if (value == null) return t.unknown;
    return value >= targets.fiber ? t.good : t.low;
  }
}

class _MetricData {
  const _MetricData({
    required this.label,
    required this.value,
    required this.target,
    required this.unit,
    required this.status,
    required this.statusColor,
    this.limit = false,
  });

  final String label;
  final double? value;
  final double target;
  final String unit;
  final String status;
  final Color statusColor;
  final bool limit;
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.data});

  final _MetricData data;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final value = data.value;
    final progress = value == null
        ? 0.0
        : (value / data.target).clamp(0.0, 1.15);
    return Row(
      children: [
        SizedBox(
          width: 58,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.label,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: t.inkSecondary),
              ),
              const SizedBox(height: 2),
              Text(
                data.status,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: data.statusColor),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value == null ? '未记录' : '${compactNumber(value)} ${data.unit}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                data.limit
                    ? '上限 ${compactNumber(data.target)}'
                    : '目标 ${compactNumber(data.target)}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: t.inkTertiary),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 56,
          child: ThinBar(value: progress, color: t.ink, height: 5),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.data});

  final _MetricData data;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final value = data.value;
    final progress = value == null
        ? 0.0
        : (value / data.target).clamp(0.0, 1.15);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                data.label,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: t.inkSecondary),
              ),
            ),
            Text(
              data.status,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: data.statusColor),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          value == null ? '未记录' : '${compactNumber(value)} ${data.unit}',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          data.limit
              ? '上限 ${compactNumber(data.target)}'
              : '目标 ${compactNumber(data.target)}',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: t.inkTertiary),
        ),
        const SizedBox(height: 5),
        ThinBar(value: progress, color: t.ink, height: 4),
      ],
    );
  }
}

class ThinBar extends StatelessWidget {
  const ThinBar({
    super.key,
    required this.value,
    required this.color,
    this.height = 5,
    this.track,
  });

  final double value;
  final Color color;
  final double height;
  final Color? track;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return SizedBox(
          height: height,
          child: Stack(
            children: [
              Container(
                width: width,
                height: height,
                decoration: BoxDecoration(
                  color: track ?? t.surfaceAlt,
                  borderRadius: BorderRadius.circular(height / 2),
                ),
              ),
              Container(
                width: width * value.clamp(0.0, 1.0),
                height: height,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(height / 2),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// 16 项子弹行
// ---------------------------------------------------------------------------

class BulletScoreRow extends StatelessWidget {
  const BulletScoreRow({
    super.key,
    required this.item,
    required this.day,
    this.onTap,
    this.showNote = true,
  });

  final ScoreItemResult item;
  final DayScore day;
  final VoidCallback? onTap;
  final bool showNote;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final recorded = itemHasData(day, item.code);
    final status = recorded ? item.status : ScoreStatus.unknown;
    final color = statusColor(t, status);
    final lost = item.lostPoints;
    final composite = isCompositeItem(item.code);
    final note = item.note.trim();
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatusBadge(status: status, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.label,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              if (composite)
                Padding(
                  padding: const EdgeInsets.only(left: 4, right: 6),
                  child: Text(
                    '组合',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: t.inkTertiary),
                  ),
                ),
              Text(
                lost < 0.05 ? '0' : '−${compactNumber(lost)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: t.ink,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          BulletChart(
            intake: item.intake,
            targetMin: item.targetMin,
            targetMax: item.targetMax,
            status: status,
            showBand: isBandItem(item.code) || isLimitItem(item.code),
            limit: isLimitItem(item.code),
            recorded: recorded,
          ),
          const SizedBox(height: 5),
          Wrap(
            spacing: 8,
            runSpacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                recorded ? actualLabel(item) : '未记录',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: recorded ? t.ink : t.unknown,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                targetLabel(item),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                ratioLabel(day, item),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: recorded ? t.inkSecondary : t.unknown,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          if (showNote && note.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              note,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: t.inkTertiary,
                height: 1.4,
              ),
            ),
          ],
          if (showNote && !recorded) ...[
            const SizedBox(height: 2),
            Text(
              '未记录的营养素按 0 计；补记后分数会变化。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: t.inkTertiary,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
    return Semantics(
      button: onTap != null,
      label:
          '${item.label}，${recorded ? actualLabel(item) : '未记录'}，'
          '${targetLabel(item)}，${statusWord(status)}，丢 ${compactNumber(lost)} 分。'
          '${onTap == null ? '' : '点按看解释。'}',
      child: ExcludeSemantics(
        child: onTap == null
            ? content
            : Material(
                color: Colors.transparent,
                child: InkWell(onTap: onTap, child: content),
              ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.color});

  final ScoreStatus status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(t.isQ ? t.pillRadius : t.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.24), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            statusGlyph(status),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: status == ScoreStatus.veryHigh ? 10 : 12,
              height: 1.1,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            statusWord(status),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: color, height: 1.1),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 资格门槛
// ---------------------------------------------------------------------------

class EligibilityCheck {
  const EligibilityCheck({
    required this.label,
    required this.current,
    required this.target,
    required this.met,
  });

  final String label;
  final String current;
  final String target;
  final bool met;
}

List<EligibilityCheck> eligibilityChecks(
  DayScore day,
  List<FoodEntry> entries,
  HealthProfile? profile,
) {
  final targets = NutrientTargets.fromProfile(profile);
  final energy = day.totals[NutrientCode.energy] ?? 0;
  final slots = entries
      .where((e) => e.items.isNotEmpty)
      .map((e) => e.slot)
      .toSet()
      .length;
  final groups = day.groupTotals.values.where((e) => e > 0.5).length;
  final limits = [
    NutrientCode.sodium,
    NutrientCode.sugar,
    NutrientCode.sfa,
  ].where(day.totals.containsKey).length;
  final energyPct = targets.energy <= 0 ? 0.0 : energy / targets.energy;
  return [
    EligibilityCheck(
      label: '能量记录',
      current: '${(energyPct * 100).round()}% EER',
      target: '≥70%',
      met: energyPct >= 0.7,
    ),
    EligibilityCheck(
      label: '进食场合',
      current: '$slots',
      target: '≥2',
      met: slots >= 2,
    ),
    EligibilityCheck(
      label: '食物条目',
      current: '${day.entryCount}',
      target: '≥5',
      met: day.entryCount >= 5,
    ),
    EligibilityCheck(
      label: '食物组',
      current: '$groups',
      target: '≥3',
      met: groups >= 3,
    ),
    EligibilityCheck(
      label: '可估限制项',
      current: '$limits',
      target: '≥2',
      met: limits >= 2,
    ),
  ];
}

class EligibilityList extends StatelessWidget {
  const EligibilityList({super.key, required this.checks});

  final List<EligibilityCheck> checks;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      children: [
        for (final check in checks)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Icon(
                  check.met
                      ? Icons.check_circle_outline_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 16,
                  color: check.met ? t.good : t.inkTertiary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    check.label,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: t.inkSecondary),
                  ),
                ),
                Text(
                  '${check.current} / ${check.target}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: check.met ? t.good : t.inkSecondary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 钠来源
// ---------------------------------------------------------------------------

enum SodiumBucket { condiment, soup, processed, takeout, other }

extension SodiumBucketX on SodiumBucket {
  String get label => switch (this) {
    SodiumBucket.condiment => '调味品',
    SodiumBucket.soup => '汤汁',
    SodiumBucket.processed => '加工食品',
    SodiumBucket.takeout => '外卖',
    SodiumBucket.other => '其他',
  };
}

class SodiumSource {
  const SodiumSource({
    required this.bucket,
    required this.mg,
    required this.foods,
  });

  final SodiumBucket bucket;
  final double mg;
  final List<String> foods;
}

class SodiumBreakdown {
  const SodiumBreakdown({
    required this.totalMg,
    required this.targetMg,
    required this.idealMg,
    required this.sources,
    required this.unlabeled,
    required this.missingData,
    required this.dishCount,
    required this.potassiumMg,
  });

  final double totalMg;
  final double targetMg;
  final double idealMg;
  final List<SodiumSource> sources;
  final List<String> unlabeled;
  final List<String> missingData;
  final int dishCount;
  final double? potassiumMg;

  double get saltG => totalMg / 400;
  bool get hasData => totalMg > 0;
  SodiumSource? get top => sources.isEmpty ? null : sources.first;

  String get swap {
    if (!hasData) return '包装食品看标签；外卖按高值看更接近实际。';
    if (totalMg <= targetMg) return '钠在范围内，保持现在的调味习惯就好。';
    return switch (top?.bucket) {
      SodiumBucket.condiment => '把酱油/蚝油减半（10 ml 酱油 ≈ 1.6 g 盐），蘸料分开装，用醋和柠檬补味。',
      SodiumBucket.soup => '汤喝一半，或把汤面换成清汤/拌面；一碗汤面的汤底常有 3–5 g 盐。',
      SodiumBucket.processed => '火腿/香肠/方便面一周不超过 2 次；方便面调料包只放一半。',
      SodiumBucket.takeout => '点单备注少盐、酱分装；汤类少喝，优先蒸/煮/烤。',
      _ => '下一餐少放半勺盐（约 1 g），用葱姜蒜/醋提味。',
    };
  }
}

const _condimentWords = [
  '酱油',
  '生抽',
  '老抽',
  '蚝油',
  '豆瓣酱',
  '甜面酱',
  '黄豆酱',
  '鸡精',
  '味精',
  '调料',
  '蘸料',
  '腐乳',
  '火锅底料',
  '沙茶酱',
  '芝麻酱',
  '蛋黄酱',
  '番茄酱',
  '盐',
];

const _soupWords = [
  '汤',
  '羹',
  '火锅',
  '麻辣烫',
  '汤底',
  '面汤',
  '牛肉面',
  '拉面',
  '汤面',
  '酸辣粉',
  '螺蛳粉',
];

const _processedWords = [
  '方便面',
  '火腿',
  '香肠',
  '腊',
  '培根',
  '午餐肉',
  '咸菜',
  '泡菜',
  '榨菜',
  '薯片',
  '饼干',
  '罐头',
  '肉干',
  '咸蛋',
  '挂面',
  '速冻',
  '丸子',
  '鱼丸',
  '蟹棒',
  '卤蛋',
  '豆干',
];

SodiumBreakdown buildSodium({
  required DayScore day,
  required List<FoodEntry> entries,
  required Map<String, Food> foodById,
  required double targetMg,
  required double idealMg,
}) {
  final byBucket = <SodiumBucket, double>{};
  final foodsByBucket = <SodiumBucket, List<String>>{};
  final unlabeled = <String>[];
  final missing = <String>[];
  var dishCount = 0;

  for (final entry in entries) {
    for (final item in entry.items) {
      final name = item.foodName;
      final food = item.foodId == null ? null : foodById[item.foodId];
      final hasSodium = item.nutrientSnapshot.containsKey(NutrientCode.sodium);
      if (!hasSodium) {
        if (!missing.contains(name)) missing.add(name);
      }
      final sodium = item.nutrient(NutrientCode.sodium);
      if (food == null || food.category == 'other') {
        if (!unlabeled.contains(name)) unlabeled.add(name);
      }
      if (sodium <= 0) continue;
      final bucket = _sodiumBucket(item, food, entry);
      if (bucket == SodiumBucket.other &&
          food?.category == 'dish' &&
          !item.foodName.contains('外卖') &&
          !(entry.note ?? '').contains('外卖')) {
        dishCount++;
      }
      byBucket[bucket] = (byBucket[bucket] ?? 0) + sodium;
      final list = foodsByBucket.putIfAbsent(bucket, () => []);
      if (!list.contains(name)) list.add(name);
    }
  }

  final sources =
      byBucket.entries
          .where((e) => e.value > 0)
          .map(
            (e) => SodiumSource(
              bucket: e.key,
              mg: e.value,
              foods: foodsByBucket[e.key] ?? const [],
            ),
          )
          .toList()
        ..sort((a, b) => b.mg.compareTo(a.mg));

  final total =
      day.totals[NutrientCode.sodium] ??
      sources.fold<double>(0, (a, b) => a + b.mg);
  return SodiumBreakdown(
    totalMg: total,
    targetMg: targetMg,
    idealMg: idealMg,
    sources: sources,
    unlabeled: unlabeled,
    missingData: missing,
    dishCount: dishCount,
    potassiumMg: day.totals[NutrientCode.potassium],
  );
}

SodiumBucket _sodiumBucket(EntryItem item, Food? food, FoodEntry entry) {
  final name = item.foodName;
  final tags = food?.tags ?? const <String>[];
  if (food?.category == 'condiment' ||
      tags.contains('condiment') ||
      _containsAny(name, _condimentWords)) {
    return SodiumBucket.condiment;
  }
  if (_containsAny(name, _soupWords)) return SodiumBucket.soup;
  if (tags.contains('upf') || _containsAny(name, _processedWords)) {
    return SodiumBucket.processed;
  }
  if ((entry.note ?? '').contains('外卖') ||
      name.contains('外卖') ||
      name.contains('便当') ||
      name.contains('盒饭') ||
      tags.contains('takeout')) {
    return SodiumBucket.takeout;
  }
  return SodiumBucket.other;
}

bool _containsAny(String name, List<String> words) => words.any(name.contains);

class SodiumCard extends StatelessWidget {
  const SodiumCard({super.key, required this.breakdown});

  final SodiumBreakdown breakdown;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final b = breakdown;
    final ratio = (b.potassiumMg != null && b.potassiumMg! > 0)
        ? b.totalMg / b.potassiumMg!
        : null;
    final over = b.totalMg - b.targetMg;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('总钠', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 2),
                  Text(
                    '${compactNumber(b.totalMg)} mg',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (b.hasData)
              TagChip(
                '≈盐 ${b.saltG.toStringAsFixed(1)} g',
                color: over > 0 ? t.high : t.good,
                filled: true,
              )
            else
              TagChip('未记录', color: t.unknown),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          b.hasData
              ? '目标 ≤ ${compactNumber(b.targetMg)} mg（≈${(b.targetMg / 400).toStringAsFixed(1)} g 盐）'
                    ' · 理想 ≤ ${compactNumber(b.idealMg)} mg'
                    '${over > 0 ? ' · 超出 ${compactNumber(over)} mg' : ' · 在范围内'}'
              : '目标 ≤ ${compactNumber(b.targetMg)} mg · 理想 ≤ ${compactNumber(b.idealMg)} mg',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (!b.hasData) ...[
          const SizedBox(height: 10),
          Text(
            '今天没有可估的钠。包装食品看标签；外卖按高值看更接近实际。',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: t.inkSecondary),
          ),
        ] else ...[
          const SizedBox(height: 12),
          if (b.sources.isEmpty)
            Text('今天没有可拆分的来源明细。', style: Theme.of(context).textTheme.bodySmall),
          for (var i = 0; i < b.sources.length; i++) ...[
            _SodiumSourceRow(
              source: b.sources[i],
              total: b.totalMg,
              isTop: i == 0 && b.sources[i].mg / b.totalMg >= 0.4,
            ),
            if (i != b.sources.length - 1) const SizedBox(height: 9),
          ],
          const SizedBox(height: 8),
          Text(
            '钠 ÷ 400 = 盐。1 勺酱油（10 ml）≈ 1.6 g 盐，1 g 味精 ≈ 0.5 g 盐。',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: t.inkTertiary),
          ),
        ],
        if (ratio != null) ...[
          const SizedBox(height: 6),
          Text(
            '钠钾比 ${ratio.toStringAsFixed(1)}${ratio > 1 ? '（偏高）' : '（尚可）'} · 仅展示，不计分',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: ratio > 1 ? t.high : t.inkSecondary,
            ),
          ),
        ],
        if (b.unlabeled.isNotEmpty) ...[
          const SizedBox(height: 6),
          _Caveat(
            icon: Icons.label_off_outlined,
            text:
                '${b.unlabeled.length} 项没有包装标签（${b.unlabeled.take(3).join('、')}），'
                '钠可能被低估；这类先按高值看。',
          ),
        ],
        if (b.missingData.isNotEmpty) ...[
          const SizedBox(height: 4),
          _Caveat(
            icon: Icons.help_outline_rounded,
            text:
                '${b.missingData.length} 项没有钠数据（${b.missingData.take(3).join('、')}）。',
          ),
        ],
        if (b.dishCount > 0) ...[
          const SizedBox(height: 4),
          _Caveat(
            icon: Icons.restaurant_outlined,
            text: '${b.dishCount} 份菜品；若来自餐馆/外卖，钠常是家常的 1.5–2.5 倍。',
          ),
        ],
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: t.surfaceAlt,
            borderRadius: BorderRadius.circular(t.radiusMd),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.swap_horiz_rounded, size: 16, color: t.inkSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '替换建议',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: t.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(b.swap, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SodiumSourceRow extends StatelessWidget {
  const _SodiumSourceRow({
    required this.source,
    required this.total,
    required this.isTop,
  });

  final SodiumSource source;
  final double total;
  final bool isTop;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final share = total <= 0 ? 0.0 : source.mg / total;
    return Semantics(
      label:
          '${source.bucket.label} ${source.mg.round()} 毫克，占 ${(share * 100).round()}%',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 64,
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          source.bucket.label,
                          maxLines: 1,
                          overflow: TextOverflow.fade,
                          softWrap: false,
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(color: t.ink),
                        ),
                      ),
                      if (isTop) ...[
                        const SizedBox(width: 3),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: t.ink,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: ThinBar(value: share, color: t.ink, height: 8),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 60,
                  child: Text(
                    '${compactNumber(source.mg)} mg',
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: t.ink,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                SizedBox(
                  width: 34,
                  child: Text(
                    '${(share * 100).round()}%',
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: t.inkSecondary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.only(left: 70),
              child: Text(
                '≈盐 ${(source.mg / 400).toStringAsFixed(1)} g · ${source.foods.take(3).join('、')}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: t.inkTertiary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Caveat extends StatelessWidget {
  const _Caveat({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 13, color: t.inkTertiary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: t.inkTertiary, height: 1.45),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 微量营养素（不计分）
// ---------------------------------------------------------------------------

class MicroNutrient {
  const MicroNutrient({
    required this.code,
    required this.label,
    required this.unit,
    required this.target,
    required this.value,
    required this.recorded,
  });

  final String code;
  final String label;
  final String unit;
  final double target;
  final double value;
  final bool recorded;

  double get progress => target <= 0 ? 0 : (value / target).clamp(0.0, 1.15);

  String get valueText => recorded
      ? '${compactNumber(value)} / ${compactNumber(target)} $unit'
      : '未记录 / ${compactNumber(target)} $unit';

  String get statusText {
    if (!recorded) return '未记录';
    if (value >= target) return '够了';
    final pct = (value / target * 100).round();
    return '$pct%';
  }

  Color statusColor(AppTokens t) {
    if (!recorded) return t.unknown;
    if (value >= target) return t.good;
    if (value >= target * 0.7) return t.inkSecondary;
    return t.low;
  }
}

List<MicroNutrient> buildMicroNutrients(DayScore day, HealthProfile? profile) {
  final male = profile?.sex == Sex.male;
  final specs = <List<Object>>[
    ['vd_ug', '维生素 D', 'μg', 10.0],
    ['zinc_mg', '锌', 'mg', male ? 12.5 : 7.5],
    ['selenium_ug', '硒', 'μg', 60.0],
    ['vb1_mg', '维生素 B1', 'mg', male ? 1.4 : 1.2],
    ['vb2_mg', '维生素 B2', 'mg', male ? 1.4 : 1.2],
    ['vb6_mg', '维生素 B6', 'mg', 1.4],
    ['potassium_mg', '钾', 'mg', 2000.0],
    ['omega3_g', 'Omega-3', 'g', male ? 1.6 : 1.1],
  ];
  return [
    for (final spec in specs)
      MicroNutrient(
        code: spec[0] as String,
        label: spec[1] as String,
        unit: spec[2] as String,
        target: spec[3] as double,
        value: day.totals[spec[0] as String] ?? 0,
        recorded: day.totals.containsKey(spec[0] as String),
      ),
  ];
}

class MicroGrid extends StatelessWidget {
  const MicroGrid({super.key, required this.items});

  final List<MicroNutrient> items;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;
        final width = (constraints.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: 14,
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: t.ink,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          item.statusText,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: item.statusColor(t),
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ThinBar(
                      value: item.progress,
                      color: item.recorded
                          ? t.ink
                          : t.unknown.withValues(alpha: 0.35),
                      height: 4,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.valueText,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: item.recorded ? t.inkSecondary : t.unknown,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// 周/月建议
// ---------------------------------------------------------------------------

class ScoreInsight {
  const ScoreInsight({
    required this.code,
    required this.headline,
    required this.action,
    required this.status,
    this.keep = false,
  });

  final String code;
  final String headline;
  final String action;
  final ScoreStatus status;
  final bool keep;
}

class _InsightAgg {
  int days = 0;
  double lost = 0;
  ScoreStatus worst = ScoreStatus.low;

  void add(ScoreItemResult item) {
    days++;
    lost += item.lostPoints;
    if (item.status == ScoreStatus.veryHigh ||
        (item.status == ScoreStatus.high && worst != ScoreStatus.veryHigh)) {
      worst = item.status;
    }
  }
}

List<ScoreInsight> buildInsights(
  List<DayScore> days, {
  String scope = '这周',
  int limit = 3,
}) {
  final eligible = days.where((d) => d.eligible && d.total != null).toList();
  final sample = eligible.isEmpty
      ? days.where((d) => d.entryCount > 0).toList()
      : eligible;
  if (sample.isEmpty) {
    return const [
      ScoreInsight(
        code: '',
        headline: '还没有可用的记录',
        action: '先记 2–3 天：早餐和午餐各一条就够，周报才有东西可看。',
        status: ScoreStatus.unknown,
      ),
      ScoreInsight(
        code: '',
        headline: '先固定一餐',
        action: '把早餐固定成鸡蛋 + 奶 + 主食，蛋白质和纤维更容易够。',
        status: ScoreStatus.unknown,
      ),
      ScoreInsight(
        code: '',
        headline: '水放在手边',
        action: '今天先喝够 1500 ml；含糖饮料换白水或无糖茶。',
        status: ScoreStatus.unknown,
      ),
    ];
  }

  final agg = <String, _InsightAgg>{};
  for (final day in sample) {
    for (final item in day.items) {
      if (!itemHasData(day, item.code)) continue;
      if (item.status == ScoreStatus.ok || item.status == ScoreStatus.unknown) {
        continue;
      }
      if (item.lostPoints < 0.5) continue;
      agg.putIfAbsent(item.code, _InsightAgg.new).add(item);
    }
  }
  final ranked = agg.entries.toList()
    ..sort((a, b) {
      final scoreA = a.value.lost + a.value.days * 1.2;
      final scoreB = b.value.lost + b.value.days * 1.2;
      return scoreB.compareTo(scoreA);
    });

  final out = <ScoreInsight>[];
  final used = <String>{};
  final countText = scope == '这个月'
      ? '${sample.length} 个评分日里'
      : '${sample.length} 个评分日里';
  for (final entry in ranked) {
    if (out.length >= limit) break;
    final code = entry.key;
    final value = entry.value;
    final direction = isLimitItem(code) ? '偏多' : '不足';
    final word = value.worst == ScoreStatus.veryHigh ? '明显偏多' : direction;
    out.add(
      ScoreInsight(
        code: code,
        headline: '${shortLabelFor(code)} $countText ${value.days} 天$word',
        action: suggestionForCode(code),
        status: value.worst,
      ),
    );
    used.add(code);
  }

  // 不足 3 条时，用“保持”补足，而不是硬凑缺口。
  if (out.length < limit) {
    final keepAgg = <String, int>{};
    for (final day in sample) {
      for (final item in day.items) {
        if (!itemHasData(day, item.code)) continue;
        if (item.status != ScoreStatus.ok) continue;
        if (item.score < 80) continue;
        keepAgg[item.code] = (keepAgg[item.code] ?? 0) + 1;
      }
    }
    final keepRanked = keepAgg.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final entry in keepRanked) {
      if (out.length >= limit) break;
      if (used.contains(entry.key)) continue;
      out.add(
        ScoreInsight(
          code: entry.key,
          headline:
              '${shortLabelFor(entry.key)} $countText ${entry.value} 天在范围内',
          action: '保持现在的份量，不用额外加。',
          status: ScoreStatus.ok,
          keep: true,
        ),
      );
      used.add(entry.key);
    }
  }

  const fallbacks = [
    ScoreInsight(
      code: '',
      headline: '先固定一餐',
      action: '把早餐固定成鸡蛋 + 奶 + 主食，蛋白质和纤维更容易够。',
      status: ScoreStatus.unknown,
    ),
    ScoreInsight(
      code: '',
      headline: '记录再稳一点',
      action: '下周至少记 3 天早餐或午餐，周报才能看出规律。',
      status: ScoreStatus.unknown,
    ),
    ScoreInsight(
      code: '',
      headline: '水放在手边',
      action: '今天先喝够 1500 ml；含糖饮料换白水或无糖茶。',
      status: ScoreStatus.unknown,
    ),
  ];
  var fallbackIndex = 0;
  while (out.length < limit) {
    out.add(fallbacks[fallbackIndex % fallbacks.length]);
    fallbackIndex++;
  }
  return out;
}

class InsightCard extends StatelessWidget {
  const InsightCard({
    super.key,
    required this.title,
    required this.insights,
    this.footnote,
  });

  final String title;
  final List<ScoreInsight> insights;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(title, style: Theme.of(context).textTheme.titleSmall),
            ),
            Text(
              '${insights.length} 条',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < insights.length; i++) ...[
          _InsightRow(index: i + 1, insight: insights[i]),
          if (i != insights.length - 1) ...[
            const SizedBox(height: 8),
            Container(height: t.borderWidth, color: t.hairline),
            const SizedBox(height: 8),
          ],
        ],
        if (footnote != null) ...[
          const SizedBox(height: 8),
          Text(
            footnote!,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: t.inkTertiary),
          ),
        ],
      ],
    );
  }
}

class _InsightRow extends StatelessWidget {
  const _InsightRow({required this.index, required this.insight});

  final int index;
  final ScoreInsight insight;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = insight.keep
        ? t.good
        : statusColor(
            t,
            insight.status == ScoreStatus.unknown
                ? ScoreStatus.unknown
                : insight.status,
          );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
          ),
          child: Text(
            '$index',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                insight.headline,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 2),
              Text(
                insight.action,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(height: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 月视图：4 周周分 + 趋势箭头
// ---------------------------------------------------------------------------

class WeekTrendRow {
  const WeekTrendRow({
    required this.label,
    required this.range,
    required this.score,
    required this.eligibleDays,
    required this.recordedDays,
    required this.diff,
  });

  final String label;
  final String range;
  final double? score;
  final int eligibleDays;
  final int recordedDays;
  final double? diff;
}

List<WeekTrendRow> buildWeekRows(List<DayScore> days) {
  final rows = <WeekTrendRow>[];
  double? previous;
  for (var i = 0; i < 4; i++) {
    final start = i * 7;
    if (start + 7 > days.length) break;
    final slice = days.sublist(start, start + 7);
    final period = ScoreAggregator.week(
      weekKey: weekKey(slice.last.date),
      label: '第 ${i + 1} 周',
      days: slice,
    );
    final diff = previous == null || period.total == null
        ? null
        : period.total! - previous;
    rows.add(
      WeekTrendRow(
        label: '第 ${i + 1} 周',
        range:
            '${compactDate(slice.first.date)}–${compactDate(slice.last.date)}',
        score: period.total,
        eligibleDays: period.eligibleDays,
        recordedDays: slice.where((e) => e.entryCount > 0).length,
        diff: diff,
      ),
    );
    previous = period.total;
  }
  return rows;
}

String compactDate(String key) {
  final date = parseDateKey(key);
  return '${date.month}/${date.day}';
}

class WeekTrendList extends StatelessWidget {
  const WeekTrendList({super.key, required this.rows});

  final List<WeekTrendRow> rows;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          Row(
            children: [
              SizedBox(
                width: 52,
                child: Text(
                  rows[i].label,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: t.ink),
                ),
              ),
              Expanded(
                child: Text(
                  rows[i].range,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: t.inkTertiary),
                ),
              ),
              Text(
                rows[i].score == null ? '—' : rows[i].score!.round().toString(),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 6),
              TrendArrow(diff: rows[i].diff),
              const SizedBox(width: 6),
              SizedBox(
                width: 58,
                child: Text(
                  '${rows[i].eligibleDays}/${rows[i].recordedDays} 天',
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: t.inkTertiary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
          if (i != rows.length - 1) ...[
            const SizedBox(height: 6),
            Container(height: t.borderWidth, color: t.hairline),
            const SizedBox(height: 6),
          ],
        ],
        const SizedBox(height: 6),
        Text(
          '右侧为「可评分 / 有记录」天数。',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: t.inkTertiary),
        ),
      ],
    );
  }
}

class TrendArrow extends StatelessWidget {
  const TrendArrow({super.key, this.diff, this.showText = false});

  final double? diff;
  final bool showText;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final d = diff;
    if (d == null) {
      return Icon(Icons.remove_rounded, size: 14, color: t.inkTertiary);
    }
    if (d >= 3) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.arrow_upward_rounded, size: 14, color: t.good),
          if (showText)
            Text(
              '+${d.round()}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: t.good),
            ),
        ],
      );
    }
    if (d <= -3) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.arrow_downward_rounded, size: 14, color: t.low),
          if (showText)
            Text(
              '${d.round()}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: t.low),
            ),
        ],
      );
    }
    return Icon(Icons.remove_rounded, size: 14, color: t.inkTertiary);
  }
}

// ---------------------------------------------------------------------------
// 瀑布卡片（可展开）
// ---------------------------------------------------------------------------

class WaterfallViewData {
  const WaterfallViewData({
    required this.steps,
    required this.rawTotal,
    required this.finalTotal,
    required this.totalLost,
    required this.hiddenCount,
    required this.hasUnrecorded,
    this.capLabel,
  });

  final List<WaterfallStep> steps;
  final double rawTotal;
  final double finalTotal;
  final double totalLost;
  final int hiddenCount;
  final bool hasUnrecorded;
  final String? capLabel;
}

WaterfallViewData buildWaterfallData(
  DayScore day,
  AppTokens t, {
  int maxItems = 6,
}) {
  final sorted = day.sortedByLost.where((e) => e.lostPoints >= 0.05).toList();
  final lostAll = sorted.fold<double>(0, (sum, e) => sum + e.lostPoints);
  final raw = (100 - lostAll).clamp(0.0, 100.0).toDouble();
  final visible = sorted.take(maxItems).toList();
  final hidden = sorted.skip(maxItems).toList();
  final steps = <WaterfallStep>[];
  for (final item in visible) {
    final recorded = itemHasData(day, item.code);
    steps.add(
      WaterfallStep(
        label: shortLabelFor(item.code),
        amount: item.lostPoints,
        color: recorded ? statusColor(t, item.status) : t.unknown,
      ),
    );
  }
  if (hidden.isNotEmpty) {
    steps.add(
      WaterfallStep(
        label: '其他 ${hidden.length} 项',
        amount: hidden.fold<double>(0, (sum, e) => sum + e.lostPoints),
        color: t.inkTertiary,
      ),
    );
  }
  final finalTotal = (day.total ?? raw).clamp(0.0, 100.0).toDouble();
  String? capLabel;
  if (day.gates.isNotEmpty) {
    final gate = day.gates.reduce((a, b) => a.cap <= b.cap ? a : b);
    capLabel = '${gate.label} · 上限 ${gate.cap.round()}';
  }
  return WaterfallViewData(
    steps: steps,
    rawTotal: raw,
    finalTotal: finalTotal,
    totalLost: (100 - finalTotal).clamp(0.0, 100.0),
    hiddenCount: hidden.length,
    hasUnrecorded: sorted.any((e) => !itemHasData(day, e.code)),
    capLabel: capLabel,
  );
}

class WaterfallCard extends StatefulWidget {
  const WaterfallCard({super.key, required this.day, this.initialMaxItems = 6});

  final DayScore day;
  final int initialMaxItems;

  @override
  State<WaterfallCard> createState() => _WaterfallCardState();
}

class _WaterfallCardState extends State<WaterfallCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final data = buildWaterfallData(
      widget.day,
      t,
      maxItems: _expanded ? 99 : widget.initialMaxItems,
    );
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WaterfallChart(
            steps: data.steps,
            rawTotal: data.rawTotal,
            finalTotal: data.finalTotal,
            capLabel: data.capLabel,
          ),
          if (data.hiddenCount > 0) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 0),
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(_expanded ? '收起' : '展开其余 ${data.hiddenCount} 项'),
              ),
            ),
          ],
          if (data.hasUnrecorded) ...[
            const SizedBox(height: 6),
            Text(
              '灰色的项今天没有记录，按 0 计；补记后分数会变化。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: t.inkTertiary,
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 小工具
// ---------------------------------------------------------------------------

class Footnote extends StatelessWidget {
  const Footnote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: t.inkTertiary, height: 1.5),
      ),
    );
  }
}

class ScoreHeroNumber extends StatelessWidget {
  const ScoreHeroNumber({
    super.key,
    required this.value,
    required this.label,
    this.caption,
    this.color,
  });

  final double? value;
  final String label;
  final String? caption;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = color ?? (value == null ? t.unknown : scoreColor(t, value!));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        SizedBox(
          height: 52,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value == null ? '—' : value!.round().toString(),
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                color: c,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
        if (caption != null)
          Text(
            caption!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: c),
          ),
      ],
    );
  }
}

class InfoStrip extends StatelessWidget {
  const InfoStrip({
    super.key,
    required this.text,
    this.icon = Icons.info_outline_rounded,
    this.color,
  });

  final String text;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = color ?? t.inkSecondary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(t.radiusMd),
        border: Border.all(
          color: c.withValues(alpha: 0.18),
          width: t.borderWidth,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: c),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: t.inkSecondary,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

double stdDev(List<double> values) {
  if (values.length < 2) return 0;
  final mean = values.reduce((a, b) => a + b) / values.length;
  final variance =
      values.map((e) => math.pow(e - mean, 2)).reduce((a, b) => a + b) /
      values.length;
  return math.sqrt(variance);
}

String volatilityWord(double sd, int sample) {
  if (sample < 3) return '样本少';
  if (sd <= 5) return '稳定';
  if (sd <= 10) return '有起伏';
  return '波动较大';
}

Color volatilityColor(AppTokens t, double sd, int sample) {
  if (sample < 3) return t.unknown;
  if (sd <= 5) return t.good;
  if (sd <= 10) return t.inkSecondary;
  return t.high;
}
