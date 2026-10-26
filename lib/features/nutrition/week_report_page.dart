import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/score_providers.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_widgets.dart';
import '../plan/plan_page.dart';
import 'charts.dart';
import 'score_detail_page.dart';
import 'widgets.dart';

class WeekReportPage extends ConsumerWidget {
  const WeekReportPage({super.key});

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
    final latest = eligible.isEmpty ? days.last : eligible.last;
    final range = days.isEmpty
        ? ''
        : '${compactDate(days.first.date)} – ${compactDate(days.last.date)}';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              children: [
                PageHeader(
                  showBack: true,
                  title: '周报',
                  subtitle: '$range · 最近 7 天',
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                    children: [
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ScoreHeroNumber(
                              value: week.total,
                              label: '周分',
                              caption: week.total == null
                                  ? null
                                  : scoreWord(week.total!),
                            ),
                            if (week.total != null) ...[
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 12,
                                runSpacing: 4,
                                children: [
                                  if (week.average != null)
                                    Text(
                                      '平均 ${week.average!.round()}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: t.ink,
                                            fontFeatures: const [
                                              FontFeature.tabularFigures(),
                                            ],
                                          ),
                                    ),
                                  Text(
                                    '波动 σ ${sd.toStringAsFixed(1)} · '
                                    '${volatilityWord(sd, scores.length)}',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: volatilityColor(
                                            t,
                                            sd,
                                            scores.length,
                                          ),
                                          fontFeatures: const [
                                            FontFeature.tabularFigures(),
                                          ],
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
                                IntervalTag(
                                  interval: week.interval,
                                  prefix: '日均区间',
                                ),
                                TagChip('记录 $recorded/${days.length} 天'),
                                TagChip('可评分 ${eligible.length} 天'),
                                TagChip('完整度 $completeness%'),
                              ],
                            ),
                            if (scores.length < 3) ...[
                              const SizedBox(height: 10),
                              InfoStrip(
                                icon: Icons.schedule_rounded,
                                text:
                                    '这周只有 ${scores.length} 天可评分。记录不足的天不计入周分，'
                                    '但样本少于 3 天时，周分和波动都只作参考。',
                              ),
                            ],
                            if (scores.length >= 3 && completeness < 60) ...[
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
                      const SizedBox(height: 18),
                      SectionTitle(
                        '每天丢分构成',
                        subtitle: '按食物组 / 营养素 / 限制项；点一天看扣分',
                      ),
                      AppCard(
                        child: StackedLossBars(
                          days: days,
                          onDayTap: (day) => showDayScoreSheet(context, day),
                        ),
                      ),
                      const SizedBox(height: 18),
                      SectionTitle(
                        '下周只改三件',
                        subtitle: '从最低分项和反复出现的扣分里挑，具体到食物与份量',
                      ),
                      AppCard(
                        child: InsightCard(
                          title: '建议',
                          insights: insights,
                          footnote: scores.length < 3
                              ? '样本少于 3 天，建议只作方向；先补记录，再追求改变。'
                              : '不追求一天全改。先做第 1 条，连续 3 天再看曲线。',
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const PlanPage(),
                            ),
                          ),
                          icon: const Icon(
                            Icons.restaurant_menu_rounded,
                            size: 18,
                          ),
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
                          icon: const Icon(
                            Icons.receipt_long_outlined,
                            size: 18,
                          ),
                          label: const Text('查看评分详情'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Footnote(
                        '周分 = 0.75×日均 + 0.25×基线 − 波动惩罚（最多 5 分）；'
                        '记录不足的天不参与。数值是估算，不承诺精确。',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
