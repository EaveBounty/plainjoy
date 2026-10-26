import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/health/advice_engine.dart';
import '../../core/models/entry.dart';
import '../../core/models/enums.dart';
import '../../core/models/nutrients.dart';
import '../../core/models/score.dart';
import '../../core/state/app_state.dart';
import '../../core/state/score_providers.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/util/date_utils.dart';
import '../../core/widgets/app_widgets.dart';
import 'charts.dart';
import 'widgets.dart';

class ScoreDetailPage extends ConsumerWidget {
  const ScoreDetailPage({super.key, this.item, this.day});

  final ScoreItemResult? item;
  final DayScore? day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DayScore resolvedDay = day ?? ref.watch(todayScoreProvider);
    final data = ref.watch(dataProvider);
    final entries =
        data?.entriesForDate(resolvedDay.date) ?? const <FoodEntry>[];
    final selected = item;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          selected == null ? '评分详情' : selected.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                formatDate(resolvedDay.date),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: selected == null
            ? _DayOverview(day: resolvedDay)
            : _ItemDetail(item: selected, day: resolvedDay, entries: entries),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 单项详情
// ---------------------------------------------------------------------------

class _ItemDetail extends StatelessWidget {
  const _ItemDetail({
    required this.item,
    required this.day,
    required this.entries,
  });

  final ScoreItemResult item;
  final DayScore day;
  final List<FoodEntry> entries;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final recorded = itemHasData(day, item.code);
    final status = recorded ? item.status : ScoreStatus.unknown;
    final color = statusColor(t, status);
    final lost = item.lostPoints;
    final contributions = _contributions(day, item, entries);
    final contributionTotal = contributions.fold<double>(
      0,
      (sum, e) => sum + e.value,
    );
    final suggestion = item.status == ScoreStatus.ok && recorded
        ? '这一项已经达标。下一餐按同样份量再来一次就好。'
        : suggestionForCode(item.code);
    final bullet = BulletChart(
      intake: item.intake,
      targetMin: item.targetMin,
      targetMax: item.targetMax,
      status: status,
      showBand: isBandItem(item.code) || isLimitItem(item.code),
      limit: isLimitItem(item.code),
      recorded: recorded,
      height: 34,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        TagChip(item.domain.label),
                        if (isCompositeItem(item.code)) const TagChip('组合项'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  TagChip(
                    '${statusGlyph(status)} ${statusWord(status)}',
                    color: color,
                    filled: true,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final narrow = constraints.maxWidth < 320;
                  final scoreBlock = Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        recorded ? item.score.round().toString() : '—',
                        style: Theme.of(context).textTheme.displayMedium
                            ?.copyWith(
                              color: color,
                              fontWeight: FontWeight.w600,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6, left: 3),
                        child: Text(
                          '/ 100',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  );
                  final lostBlock = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        lost < 0.05 ? '丢 0 分' : '丢 ${compactNumber(lost)} 分',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '权重 ${item.weight.round()}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  );
                  if (narrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        scoreBlock,
                        const SizedBox(height: 4),
                        lostBlock,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [scoreBlock, const Spacer(), lostBlock],
                  );
                },
              ),
              const SizedBox(height: 4),
              Text(
                recorded ? shortfallLabel(item) : '今天没有记录到这一项',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: recorded ? t.inkSecondary : t.unknown,
                ),
              ),
              if (item.note.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  item.note.trim(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: t.inkTertiary,
                    height: 1.45,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        SectionTitle(
          '实际 vs 目标',
          subtitle: isLimitItem(item.code) ? '竖线是上限；超出段用斜纹' : '竖线是目标；浅色带是参考区间',
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!recorded) ...[
                InfoStrip(
                  icon: Icons.help_outline_rounded,
                  text: '这一项今天没有记录，评分时按 0 计；补记后分数会重算。',
                ),
                const SizedBox(height: 10),
              ],
              bullet,
              const SizedBox(height: 4),
              Row(
                children: [
                  Text('0', style: Theme.of(context).textTheme.bodySmall),
                  Expanded(
                    child: Text(
                      isLimitItem(item.code)
                          ? '上限 ${compactNumber(item.targetMax)} ${item.unit}'
                          : '目标 ${compactNumber(item.targetMin)} ${item.unit}',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  Text(
                    '${compactNumber(bullet.scaleMax)} ${item.unit}',
                    textAlign: TextAlign.right,
                    maxLines: 2,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(height: t.borderWidth, color: t.hairline),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = (constraints.maxWidth - 10) / 2;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _Fact(
                        width: width,
                        label: '实际',
                        value: recorded ? actualLabel(item) : '未记录',
                      ),
                      _Fact(
                        width: width,
                        label: '目标',
                        value: targetLabel(item),
                      ),
                      _Fact(
                        width: width,
                        label: '权重',
                        value: '${item.weight.round()} 分',
                      ),
                      _Fact(
                        width: width,
                        label: '丢分',
                        value: lost < 0.05
                            ? '0 分'
                            : '−${compactNumber(lost)} 分',
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SectionTitle('为什么是这个分', subtitle: '公式与数据口径'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _explanation(item, recorded),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: t.inkSecondary,
                  height: 1.6,
                ),
              ),
              if (isLimitItem(item.code) && recorded) ...[
                const SizedBox(height: 10),
                _LimitMath(item: item),
              ],
              if (item.code == 'B7') ...[
                const SizedBox(height: 10),
                Text(
                  '另：B12 ${compactNumber(day.totals[NutrientCode.vitaminB12] ?? 0)} μg'
                  ' / 目标 2.4 μg${day.totals.containsKey(NutrientCode.vitaminB12) ? '' : '（未记录）'}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: t.inkSecondary),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        SectionTitle('今天这些食物贡献最多', subtitle: '按这一项的实际贡献排序，最多 5 个'),
        AppCard(
          child: contributions.isEmpty
              ? Text(
                  '今天没有记录到含这一项的食物。',
                  style: Theme.of(context).textTheme.bodySmall,
                )
              : Column(
                  children: [
                    for (var i = 0; i < contributions.length; i++) ...[
                      _ContributionRow(
                        contribution: contributions[i],
                        unit: item.unit,
                        total: contributionTotal,
                        showPerHundred: !item.code.startsWith('A'),
                        highlightSodium: item.code == 'C1',
                      ),
                      if (i != contributions.length - 1) ...[
                        const SizedBox(height: 8),
                        Container(height: t.borderWidth, color: t.hairline),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ],
                ),
        ),
        const SizedBox(height: 18),
        AppCard(
          color: t.surfaceAlt,
          showBorder: false,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.swap_horiz_rounded, size: 18, color: t.inkSecondary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '下一餐怎么改',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      suggestion,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(height: 1.55),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.status == ScoreStatus.ok && recorded
                          ? '这一项没有丢分，保持比加量更重要。'
                          : '这一项现在丢 ${compactNumber(lost)} 分；补到适宜区间，最多能拿回这么多。',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: t.inkTertiary,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Footnote('数值是估算，不是化验单；份量区间和置信度见总分卡。'),
      ],
    );
  }

  String _explanation(ScoreItemResult item, bool recorded) {
    if (!recorded) {
      return '今天没有记录到这一项。评分时按 0 计，所以这里会显示扣分；补记后分数会重算。';
    }
    switch (item.code) {
      case 'C1':
        return '钠 1500 mg 以内满分；1500–2000 mg 缓降到 85 分；2000–4000 mg 线性降到 0。'
            '钾和钠的比例只展示，不参与这一项计分。';
      case 'C2':
        return '添加糖在限值一半以内满分；到限值为 60 分；到 2 倍限值归零。'
            '甜饮、酱料和甜点是主要来源。';
      case 'C3':
        return '饱和脂肪占总能量 7% 以内满分，20% 归零；反式脂肪 1% 以内满分，2% 归零。'
            '这一项看的是脂肪质量，不是总脂肪克数。';
      case 'A3':
        return '全谷杂豆占 70%、薯类占 30% 合成这一项；白米饭不算全谷。';
      case 'A6':
        return '肉蛋 60% + 水产 40% 合成这一项；素食模式按豆制品替代。';
      case 'B7':
        return '叶酸占 60%、B12 占 40% 合成这一项。素食者尤其容易缺 B12。';
      default:
        if (item.status == ScoreStatus.low) {
          final pct = item.targetMin <= 0
              ? 0
              : (item.intake / item.targetMin * 100).round();
          return '低于目标时按「实际 ÷ 目标」线性给分：现在是目标的 $pct%。'
              '先补到目标，不必追求超出。';
        }
        if (item.status == ScoreStatus.high ||
            item.status == ScoreStatus.veryHigh) {
          return '高于参考上限，超出部分按比例扣分。上限不是“危险线”，只是结构参考。';
        }
        return '在适宜区间内，这一项拿满分。保持当前份量即可。';
    }
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.width, required this.label, required this.value});

  final double width;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: t.ink,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _LimitMath extends StatelessWidget {
  const _LimitMath({required this.item});

  final ScoreItemResult item;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final over = (item.intake - item.targetMax).clamp(0.0, double.infinity);
    if (item.code == 'C1') {
      final salt = item.intake / 400;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '≈盐 ${salt.toStringAsFixed(1)} g（钠 ÷ 400）'
            '${over > 0 ? '；超出 ${compactNumber(over)} mg ≈ 盐 ${(over / 400).toStringAsFixed(1)} g' : '；在范围内'}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: over > 0 ? t.high : t.good,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            '1 勺酱油（10 ml）≈ 1.6 g 盐；1 g 味精 ≈ 0.5 g 盐。',
            style: TextStyle(fontSize: 12, height: 1.5),
          ),
        ],
      );
    }
    if (item.code == 'C2') {
      return Text(
        over > 0
            ? '超出 ${compactNumber(over)} g ≈ ${(over / 4).round()} 块方糖（按 4 g/块）'
            : '在添加糖限值内',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: over > 0 ? t.high : t.good,
          height: 1.5,
        ),
      );
    }
    return Text(
      over > 0 ? '饱和脂肪超出 ${compactNumber(over)} g；具体供能占比见上方备注。' : '饱和脂肪在参考上限内。',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: over > 0 ? t.high : t.good,
        height: 1.5,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 贡献食物
// ---------------------------------------------------------------------------

class _Contribution {
  const _Contribution({
    required this.name,
    required this.grams,
    required this.value,
    required this.meals,
  });

  final String name;
  final double grams;
  final double value;
  final Set<String> meals;

  double? get per100 => grams > 0 ? value / grams * 100 : null;
}

List<_Contribution> _contributions(
  DayScore day,
  ScoreItemResult item,
  List<FoodEntry> entries,
) {
  final nutrients = itemContributionNutrients(item.code);
  final groups = itemContributionGroups(item.code);
  final merged = <String, _Contribution>{};
  for (final entry in entries) {
    for (final food in entry.items) {
      var value = 0.0;
      for (final code in nutrients) {
        value += food.nutrient(code);
      }
      for (final code in groups) {
        value += food.group(code);
      }
      if (value <= 0.001) continue;
      final existing = merged[food.foodName];
      if (existing == null) {
        merged[food.foodName] = _Contribution(
          name: food.foodName,
          grams: food.gramsP50,
          value: value,
          meals: {entry.slot.label},
        );
      } else {
        merged[food.foodName] = _Contribution(
          name: existing.name,
          grams: existing.grams + food.gramsP50,
          value: existing.value + value,
          meals: {...existing.meals, entry.slot.label},
        );
      }
    }
  }
  final list = merged.values.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return list.take(5).toList();
}

class _ContributionRow extends StatelessWidget {
  const _ContributionRow({
    required this.contribution,
    required this.unit,
    required this.total,
    required this.showPerHundred,
    required this.highlightSodium,
  });

  final _Contribution contribution;
  final String unit;
  final double total;
  final bool showPerHundred;
  final bool highlightSodium;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final share = total <= 0
        ? 0.0
        : (contribution.value / total).clamp(0.0, 1.0);
    final per100 = contribution.per100;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                contribution.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            Text(
              '${compactNumber(contribution.grams)} g',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: t.inkTertiary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${compactNumber(contribution.value)} $unit',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: t.ink,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ThinBar(value: share, color: t.ink, height: 4),
        const SizedBox(height: 3),
        Text(
          '${contribution.meals.join('/')} · 占已记录来源 ${(share * 100).round()}%'
          '${showPerHundred && per100 != null ? ' · 每 100 g ≈ ${compactNumber(per100)} $unit' : ''}'
          '${showPerHundred && highlightSodium && per100 != null && per100 >= 600 ? '（高钠）' : ''}',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: t.inkTertiary, height: 1.45),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 全天详情（从周报 / 日历进入）
// ---------------------------------------------------------------------------

class _DayOverview extends ConsumerWidget {
  const _DayOverview({required this.day});

  final DayScore day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final total = day.total;
    final gate = gateSummary(day);
    final profile = ref.watch(profileProvider);
    final entries = ref.watch(dataProvider)?.entriesForDate(day.date) ?? const <FoodEntry>[];
    final advice = AdviceEngine.forDay(
      profile: profile,
      totals: day.totals,
      groupTotals: day.groupTotals,
      entries: entries,
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formatDateWithWeekday(day.date),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: ScoreHeroNumber(
                      value: total,
                      label: '日分',
                      caption: total == null ? null : scoreWord(total),
                    ),
                  ),
                  IntervalTag(interval: day.interval),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                conclusionForDay(day),
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: t.ink, height: 1.5),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  TagChip('记录 ${day.entryCount} 个条目'),
                  if (day.interval != null)
                    ConfidenceTag(interval: day.interval),
                  if (gate != null) TagChip(gate, color: t.high),
                  if (!day.eligible) TagChip('记录不足', color: t.unknown),
                ],
              ),
              if (!day.eligible && day.eligibilityReasons.isNotEmpty) ...[
                const SizedBox(height: 10),
                InfoStrip(text: '还差：${day.eligibilityReasons.join('、')}。'),
              ],
            ],
          ),
        ),
        if (profile != null && advice.isNotEmpty) ...[
          const SizedBox(height: 18),
          SectionTitle(
            '为你的情况',
            subtitle: profile.conditions.isEmpty ? '通用建议' : '按病况与今日摄入重排',
          ),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < advice.length; i++) ...[
                  _AdviceRow(advice: advice[i]),
                  if (i != advice.length - 1) const Hairline(),
                ],
              ],
            ),
          ),
        ],
        if (total != null) ...[
          const SizedBox(height: 18),
          SectionTitle(
            '这 ${(100 - total).round()} 分丢在哪',
            subtitle: '基线 100，按丢分从大到小',
          ),
          WaterfallCard(day: day),
        ],
        const SizedBox(height: 18),
        for (final domain in ScoreDomain.values) ...[
          SectionTitle(
            domain.label,
            subtitle: '权重 ${(domain.weight * 100).round()} · 按丢分排序',
          ),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < _itemsFor(domain).length; i++) ...[
                  BulletScoreRow(
                    item: _itemsFor(domain)[i],
                    day: day,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ScoreDetailPage(
                          item: _itemsFor(domain)[i],
                          day: day,
                        ),
                      ),
                    ),
                  ),
                  if (i != _itemsFor(domain).length - 1) const Hairline(),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],
        const Footnote('未记录的项按 0 计；补记后分数会重算。区间只反映份量不确定性，不包含漏记的餐次。'),
      ],
    );
  }

  List<ScoreItemResult> _itemsFor(ScoreDomain domain) {
    final items = day.items.where((e) => e.domain == domain).toList()
      ..sort((a, b) => b.lostPoints.compareTo(a.lostPoints));
    return items;
  }
}

class _AdviceRow extends StatelessWidget {
  const _AdviceRow({required this.advice});

  final HealthAdvice advice;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tag = advice.condition?.label ?? '通用';
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 1),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: t.surfaceAlt,
                  borderRadius: BorderRadius.circular(t.radiusSm),
                ),
                child: Text(tag, style: Theme.of(context).textTheme.labelSmall),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  advice.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(height: 1.45),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            advice.body,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: t.inkSecondary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '依据：${advice.evidence}',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: t.inkTertiary),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 某一天的底部弹层（周报 / 日历点按）
// ---------------------------------------------------------------------------

Future<void> showDayScoreSheet(BuildContext context, DayScore day) {
  final nav = Navigator.of(context);
  final top = day.sortedByLost.take(3).toList();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      final t = sheetContext.tokens;
      return SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              4,
              20,
              20 + MediaQuery.viewInsetsOf(sheetContext).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            formatDateWithWeekday(day.date),
                            style: Theme.of(sheetContext).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            day.total == null
                                ? '记录不足，暂不评分'
                                : '日分 ${day.total!.round()}',
                            style: Theme.of(sheetContext).textTheme.titleLarge
                                ?.copyWith(
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                          ),
                        ],
                      ),
                    ),
                    if (day.total != null) IntervalTag(interval: day.interval),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  conclusionForDay(day),
                  style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                    color: t.inkSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                if (!day.eligible)
                  InfoStrip(
                    text: day.eligibilityReasons.isEmpty
                        ? '记录不足，暂不评分。'
                        : '还差：${day.eligibilityReasons.join('、')}。',
                  )
                else ...[
                  Text(
                    '主要丢分',
                    style: Theme.of(sheetContext).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 4),
                  for (final item in top)
                    InkWell(
                      onTap: () {
                        nav.pop();
                        nav.push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                ScoreDetailPage(item: item, day: day),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(t.radiusSm),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 26,
                              child: Text(
                                statusGlyph(displayStatus(day, item)),
                                style: Theme.of(sheetContext)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: statusColor(
                                        t,
                                        displayStatus(day, item),
                                      ),
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                item.label,
                                style: Theme.of(
                                  sheetContext,
                                ).textTheme.titleSmall,
                              ),
                            ),
                            Text(
                              '−${compactNumber(item.lostPoints)}',
                              style: Theme.of(sheetContext).textTheme.bodySmall
                                  ?.copyWith(
                                    color: t.ink,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 16,
                              color: t.inkTertiary,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      nav.pop();
                      nav.push(
                        MaterialPageRoute<void>(
                          builder: (_) => ScoreDetailPage(day: day),
                        ),
                      );
                    },
                    child: const Text('看完整分项'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
