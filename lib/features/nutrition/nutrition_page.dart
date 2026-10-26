import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/entry.dart';
import '../../core/models/enums.dart';
import '../../core/models/profile.dart';
import '../../core/models/score.dart';
import '../../core/scoring/nutrient_targets.dart';
import '../../core/state/app_state.dart';
import '../../core/state/score_providers.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/util/date_utils.dart';
import '../../core/widgets/app_widgets.dart';
import '../plan/plan_page.dart';
import '../record/record_page.dart';
import 'charts.dart';
import 'score_detail_page.dart';
import 'week_report_page.dart';
import 'widgets.dart';

enum _Span { day, week, month }

class NutritionPage extends ConsumerStatefulWidget {
  const NutritionPage({super.key});

  @override
  ConsumerState<NutritionPage> createState() => _NutritionPageState();
}

class _NutritionPageState extends ConsumerState<NutritionPage> {
  _Span _span = _Span.day;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              children: [
                PageHeader(
                  title: '营养',
                  subtitle: _subtitle(_span),
                  actions: [
                    TextButton(
                      onPressed: () => _pushWeekReport(context),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '周报',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 16,
                            color: t.ink,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SegmentedTabs(
                    labels: const ['日', '周', '月'],
                    selected: _span.index,
                    onChanged: (index) =>
                        setState(() => _span = _Span.values[index]),
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: switch (_span) {
                    _Span.day => const _DayView(),
                    _Span.week => const _WeekView(),
                    _Span.month => const _MonthView(),
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _subtitle(_Span span) {
    final today = parseDateKey(todayKey());
    return switch (span) {
      _Span.day => formatDateWithWeekday(todayKey()),
      _Span.week =>
        '${compactDate(dateKey(today.subtract(const Duration(days: 6))))} – ${compactDate(todayKey())} · 最近 7 天',
      _Span.month =>
        '${compactDate(dateKey(today.subtract(const Duration(days: 29))))} – ${compactDate(todayKey())} · 最近 30 天',
    };
  }
}

void _pushWeekReport(BuildContext context) {
  Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const WeekReportPage()));
}

void _pushRecord(BuildContext context) {
  Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const RecordPage()));
}

Widget _section(
  BuildContext context,
  String title,
  String? subtitle,
  Widget child,
) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SectionTitle(title, subtitle: subtitle),
      child,
    ],
  );
}

const _pagePadding = EdgeInsets.fromLTRB(20, 4, 20, 32);

// ---------------------------------------------------------------------------
// 日
// ---------------------------------------------------------------------------

class _DayView extends ConsumerWidget {
  const _DayView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(todayScoreProvider);
    final data = ref.watch(dataProvider);
    final profile = ref.watch(profileProvider);
    final entries = data?.entriesForDate(day.date) ?? const [];
    final targets = NutrientTargets.fromProfile(profile);
    final sodium = buildSodium(
      day: day,
      entries: entries,
      foodById: data?.foodById ?? const {},
      targetMg: targets.sodiumOk,
      idealMg: targets.sodiumIdeal,
    );
    final micro = buildMicroNutrients(day, profile);
    final last7 = ref.watch(last7ScoresProvider);

    if (!day.eligible || day.total == null) {
      return ListView(
        padding: _pagePadding,
        children: [
          _section(
            context,
            '今日评分',
            '记录不足时不评分，也不用未记录的数据吓你',
            _NotReadyCard(day: day, entries: entries, profile: profile),
          ),
          const SizedBox(height: 18),
          _section(
            context,
            '已记录到的数字',
            '只展示已记录的部分，不参与评分',
            AppCard(
              child: KeyMetricsStrip(day: day, profile: profile),
            ),
          ),
          const SizedBox(height: 18),
          _section(
            context,
            '钠从哪来',
            '≈盐 = 钠 ÷ 400；来源按今日记录聚合',
            AppCard(child: SodiumCard(breakdown: sodium)),
          ),
          const SizedBox(height: 18),
          _section(
            context,
            '微量营养素',
            '不计分；未记录不当作 0',
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MicroGrid(items: micro),
                  const SizedBox(height: 10),
                  const Footnote('参考成人 RNI/AI；孕期、慢病或服药请按医生建议调整。'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          _section(
            context,
            '最近 7 天',
            '过去可评分的天仍然有效；未评分的天断线',
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TrendBandChart(days: last7),
                  const SizedBox(height: 8),
                  const _TrendLegend(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          _WeekReviewLink(onTap: () => _pushWeekReport(context)),
        ],
      );
    }

    final total = day.total!;
    final bullets = day.sortedByLost;
    final domainScores = <ScoreDomain, double>{
      for (final domain in ScoreDomain.values) domain: day.domainScore(domain),
    };

    return ListView(
      padding: _pagePadding,
      children: [
        _section(context, '今日评分', '区间来自份量估算；分数不是精确值', _ScoreCard(day: day)),
        const SizedBox(height: 14),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: KeyMetricsStrip(day: day, profile: profile),
        ),
        const SizedBox(height: 18),
        _section(
          context,
          '三域得分',
          '食物组 40 · 营养素 32 · 限制项 28',
          AppCard(child: DomainScoresView(scores: domainScores)),
        ),
        const SizedBox(height: 18),
        _section(
          context,
          '食物组结构',
          '6 轴固定顺序；只看形状，数值以下方明细为准',
          _RadarCard(day: day),
        ),
        const SizedBox(height: 18),
        _section(
          context,
          '这 ${(100 - total).round()} 分丢在哪',
          '基线 100，按丢分从大到小；点明细看解释',
          WaterfallCard(day: day),
        ),
        const SizedBox(height: 18),
        _section(
          context,
          '16 项明细',
          '按丢分排序 · 点一项看实际、目标和替换建议',
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < bullets.length; i++) ...[
                  BulletScoreRow(
                    item: bullets[i],
                    day: day,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            ScoreDetailPage(item: bullets[i], day: day),
                      ),
                    ),
                  ),
                  if (i != bullets.length - 1) const Hairline(),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        _section(
          context,
          '钠从哪来',
          '≈盐 = 钠 ÷ 400；来源按今日记录聚合',
          AppCard(child: SodiumCard(breakdown: sodium)),
        ),
        const SizedBox(height: 18),
        _section(
          context,
          '微量营养素',
          '不计分；未记录不当作 0',
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MicroGrid(items: micro),
                const SizedBox(height: 10),
                const Footnote('参考成人 RNI/AI；孕期、慢病或服药请按医生建议调整。'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        _section(
          context,
          '最近 7 天',
          '实线是日分，浅色带是估算区间',
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TrendBandChart(days: last7),
                const SizedBox(height: 8),
                const _TrendLegend(),
                const SizedBox(height: 6),
                Footnote(
                  '${last7.where((e) => e.total == null).length} 天未评分，这些天不连线；'
                  '区间宽表示份量不确定。',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        _WeekReviewLink(onTap: () => _pushWeekReport(context)),
      ],
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.day});

  final DayScore day;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final total = day.total!;
    final color = scoreColor(t, total);
    final weakest = weakestItem(day);
    final gate = gateSummary(day);
    return AppCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 300;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RingScore(
                    value: total,
                    label: '总分',
                    size: narrow ? 88 : 102,
                    color: color,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    scoreWord(total),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: color),
                  ),
                ],
              ),
              SizedBox(width: narrow ? 12 : 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        IntervalTag(interval: day.interval),
                        ConfidenceTag(interval: day.interval),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      conclusionForDay(day),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: t.ink,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '基于 ${day.entryCount} 个食物条目',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (weakest != null)
                          TagChip(
                            '短板：${shortLabelFor(weakest.code)}',
                            color: statusColor(t, weakest.status),
                            filled: true,
                          ),
                        if (gate != null)
                          TagChip(
                            gate,
                            color: t.high,
                            icon: Icons.vertical_align_bottom_rounded,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NotReadyCard extends StatelessWidget {
  const _NotReadyCard({
    required this.day,
    required this.entries,
    required this.profile,
  });

  final DayScore day;
  final List<FoodEntry> entries;
  final HealthProfile? profile;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final checks = eligibilityChecks(day, entries, profile);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const RingScore(value: null, label: '总分', size: 92),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '记录不足，暂不评分',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '这不是吃得不好，是信息还不够。补一两项就能算分。',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '还差这些就能评分',
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: t.ink),
          ),
          const SizedBox(height: 4),
          EligibilityList(checks: checks),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _pushRecord(context),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('去记录'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RadarCard extends StatelessWidget {
  const _RadarCard({required this.day});

  final DayScore day;

  @override
  Widget build(BuildContext context) {
    final items = day.items.where((e) => e.code.startsWith('A')).toList()
      ..sort((a, b) => a.code.compareTo(b.code));
    final weakest = items.isEmpty
        ? null
        : (items.toList()..sort((a, b) => a.score.compareTo(b.score))).first;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FoodGroupRadar(items: items),
          if (weakest != null)
            Text(
              '最弱：${weakest.label} ${weakest.score.round()} 分 · '
              '${itemHasData(day, weakest.code) ? actualLabel(weakest) : '未记录'}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: context.tokens.ink),
            ),
          const SizedBox(height: 4),
          const Footnote('轴序固定（蔬菜→水果→全谷→奶类→豆坚果→鱼肉蛋）；面积不用于跨日比较。'),
        ],
      ),
    );
  }
}

class _TrendLegend extends StatelessWidget {
  const _TrendLegend();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    Widget item(Widget swatch, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        swatch,
        const SizedBox(width: 5),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        item(Container(width: 14, height: 2, color: t.ink), '日分'),
        item(
          Container(
            width: 14,
            height: 8,
            decoration: BoxDecoration(
              color: t.ink.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          '估算区间',
        ),
        item(
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: t.surface,
              border: Border.all(color: t.ink, width: 1.4),
            ),
          ),
          '空心=估算',
        ),
        item(
          SizedBox(
            width: 14,
            height: 2,
            child: Row(
              children: [
                for (var i = 0; i < 3; i++) ...[
                  Container(width: 3, height: 1.6, color: t.chartGridColor),
                  if (i != 2) const SizedBox(width: 2),
                ],
              ],
            ),
          ),
          '70 分线',
        ),
      ],
    );
  }
}

class _WeekReviewLink extends StatelessWidget {
  const _WeekReviewLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Icon(Icons.insights_outlined, size: 20, color: t.inkSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('本周回顾', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  '周分、波动、每天丢分和下周 3 条建议',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, size: 20, color: t.inkTertiary),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 周
// ---------------------------------------------------------------------------

class _WeekView extends ConsumerWidget {
  const _WeekView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final week = ref.watch(weekScoreProvider);
    final days = week.days;
    final eligible = days.where((e) => e.eligible && e.total != null).toList();
    final scores = eligible.map((e) => e.total!).toList();
    final sd = stdDev(scores);
    final recorded = days.where((e) => e.entryCount > 0).length;
    final completeness = days.isEmpty
        ? 0
        : (recorded / days.length * 100).round();
    final insights = buildInsights(days);
    final avg = week.average;
    final latest = eligible.isEmpty ? days.last : eligible.last;

    return ListView(
      padding: _pagePadding,
      children: [
        _section(
          context,
          '周分',
          '由日均、基线和波动惩罚合成；记录不足的天不计入',
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ScoreHeroNumber(
                  value: week.total,
                  label: '最近 7 天',
                  caption: week.total == null ? null : scoreWord(week.total!),
                ),
                if (week.total != null) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      if (avg != null)
                        Text(
                          '日均 ${avg.round()}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: t.ink,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                        ),
                      Text(
                        '波动 ${sd.toStringAsFixed(1)} · ${volatilityWord(sd, scores.length)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: volatilityColor(t, sd, scores.length),
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    IntervalTag(interval: week.interval, prefix: '日均区间'),
                    TagChip('记录 $recorded/${days.length} 天'),
                    TagChip('可评分 ${eligible.length} 天'),
                    TagChip('完整度 $completeness%'),
                  ],
                ),
                if (scores.length < 3) ...[
                  const SizedBox(height: 10),
                  InfoStrip(
                    icon: Icons.schedule_rounded,
                    text: '这周只有 ${scores.length} 天可评分。先用日视图记满 3 天，周分和波动才站得住。',
                  ),
                ] else if (completeness < 60) ...[
                  const SizedBox(height: 6),
                  Text(
                    '记录覆盖 $completeness%，波动和均值只作参考。',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 12),
                Container(height: t.borderWidth, color: t.hairline),
                const SizedBox(height: 12),
                DomainScoresView(scores: week.domains),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        _section(
          context,
          '每天丢分构成',
          '按食物组 / 营养素 / 限制项；点一天看扣分',
          AppCard(
            child: StackedLossBars(
              days: days,
              onDayTap: (day) => showDayScoreSheet(context, day),
            ),
          ),
        ),
        const SizedBox(height: 18),
        _section(
          context,
          '下周只改三件',
          '按高频扣分和最低分项排；具体到食物与份量',
          AppCard(
            child: InsightCard(
              title: '建议',
              insights: insights,
              footnote: scores.length < 3
                  ? '样本少于 3 天，建议只作方向；先补记录。'
                  : '不追求一天全改；先做第 1 条，连续 3 天再看效果。',
            ),
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => const PlanPage())),
            icon: const Icon(Icons.restaurant_menu_rounded, size: 18),
            label: const Text('生成下周补丁餐'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ScoreDetailPage(day: latest),
              ),
            ),
            icon: const Icon(Icons.receipt_long_outlined, size: 18),
            label: const Text('查看评分详情'),
          ),
        ),
        const SizedBox(height: 10),
        const Footnote('周分不是日分简单平均：还含基线和波动惩罚。记录不足的天不拉低周分，但会降低结论的可信度。'),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 月
// ---------------------------------------------------------------------------

class _MonthView extends ConsumerWidget {
  const _MonthView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final month = ref.watch(monthScoreProvider);
    final days = ref.watch(last30ScoresProvider);
    final weeks = buildWeekRows(days);
    final eligible = days.where((e) => e.eligible && e.total != null).length;
    final recorded = days.where((e) => e.entryCount > 0).length;
    final completeness = days.isEmpty
        ? 0
        : (recorded / days.length * 100).round();
    final insights = buildInsights(days, scope: '这个月');
    final diff = month.trend;

    return ListView(
      padding: _pagePadding,
      children: [
        _section(
          context,
          '月分',
          '取 4 个连续 7 天窗口的中位数；趋势只做箭头',
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: ScoreHeroNumber(
                        value: month.total,
                        label: '4 周窗口',
                        caption: month.total == null
                            ? null
                            : scoreWord(month.total!),
                      ),
                    ),
                    if (diff != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          TrendArrow(diff: diff, showText: true),
                          const SizedBox(height: 2),
                          Text(
                            '较月初',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    IntervalTag(interval: month.interval, prefix: '周分范围'),
                    TagChip('记录 $recorded/${days.length} 天'),
                    TagChip('可评分 $eligible 天'),
                    TagChip('完整度 $completeness%'),
                  ],
                ),
                if (weeks.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Builder(
                    builder: (context) {
                      final endIndex = math.min(
                        days.length - 1,
                        weeks.length * 7 - 1,
                      );
                      return Text(
                        '月分覆盖 ${compactDate(days.first.date)}–'
                        '${compactDate(days[endIndex].date)}；日历为最近 30 天',
                        style: Theme.of(context).textTheme.bodySmall,
                      );
                    },
                  ),
                ],
                if (month.total == null) ...[
                  const SizedBox(height: 10),
                  const InfoStrip(
                    icon: Icons.calendar_month_outlined,
                    text: '这个月还没有可评分的周；先记 2–3 天，日分和热力会先出来。',
                  ),
                ],
                const SizedBox(height: 12),
                Container(height: t.borderWidth, color: t.hairline),
                const SizedBox(height: 12),
                DomainScoresView(scores: month.domains),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        _section(
          context,
          '4 周周分',
          '月分取这 4 周的中位数；箭头是相邻两周差（±3 分以上）',
          AppCard(child: WeekTrendList(rows: weeks)),
        ),
        const SizedBox(height: 18),
        _section(
          context,
          '30 天日历',
          '颜色 + 斜纹 + 箭头三通道；点格子看当天扣分',
          AppCard(
            child: CalendarHeatmap(
              days: days,
              onDayTap: (day) => showDayScoreSheet(context, day),
            ),
          ),
        ),
        const SizedBox(height: 18),
        _section(
          context,
          '下个月只改三件',
          '看 30 天里反复出现的缺口，而不是某一天的波动',
          AppCard(
            child: InsightCard(
              title: '建议',
              insights: insights,
              footnote: eligible < 3
                  ? '可评分天数少于 3 天，建议只作方向。'
                  : '先改第 1 条；其余两条等第 1 条稳定了再说。',
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Footnote(
          '月分按 4 个连续 7 天窗口聚合（共 28 天）；日历里的最近 2 天暂未进入月分窗口，会先计入本周周报。数值是估算，区间见上。',
        ),
      ],
    );
  }
}
