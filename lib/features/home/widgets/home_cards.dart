import 'package:flutter/material.dart';

import '../../../core/models/entry.dart';
import '../../../core/models/enums.dart';
import '../../../core/models/pet.dart';
import '../../../core/models/score.dart';
import '../../../core/pet/pet_state_service.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../pet/pet_stage.dart';
import '../../record/record_page.dart';

/// 总分卡：可评分时给总分 + 区间 + 三域；不足时明确说暂不评分。
class TodayScoreCard extends StatelessWidget {
  final DayScore score;
  final int entryCount;
  final VoidCallback onRecord;

  const TodayScoreCard({
    super.key,
    required this.score,
    required this.entryCount,
    required this.onRecord,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final eligible = score.eligible && score.total != null;

    if (!eligible) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ScoreRing(score: null, size: 88, label: '暂不评分'),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '记录不足，暂不评分',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        score.eligibilityReasons.isEmpty
                            ? '再记一餐，结论会更接近真实。'
                            : score.eligibilityReasons.take(2).join(' · '),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  '今天已记录 $entryCount 条',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: onRecord,
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('去补记'),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScoreRing(
            score: score.total,
            size: 92,
            color: score.total! >= 85
                ? t.good
                : score.total! >= 70
                ? t.ink
                : t.low,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '总分区间 ${score.interval?.display ?? '—'}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '已记录 $entryCount 条 · 区间越窄越可信',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                for (final domain in ScoreDomain.values) ...[
                  _DomainRow(score: score.domainScore(domain), domain: domain),
                  if (domain != ScoreDomain.values.last)
                    const SizedBox(height: 7),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DomainRow extends StatelessWidget {
  final double score;
  final ScoreDomain domain;

  const _DomainRow({required this.score, required this.domain});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = score >= 70
        ? t.good
        : score >= 45
        ? t.inkSecondary
        : t.low;
    return Row(
      children: [
        SizedBox(
          width: 48,
          child: Text(
            domain.label,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(t.pillRadius),
            child: LinearProgressIndicator(
              value: (score / 100).clamp(0.0, 1.0),
              minHeight: t.isQ ? 7 : 5,
              backgroundColor: t.surfaceAlt,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 24,
          child: Text(
            score.round().toString(),
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

/// 今日建议：只显示引擎给出的一条。
class SuggestionCard extends StatelessWidget {
  final String action;

  const SuggestionCard({super.key, required this.action});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AppCard(
      color: t.surfaceAlt,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.tips_and_updates_outlined,
            size: 20,
            color: t.inkSecondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('今天只改这一件', style: Theme.of(context).textTheme.labelSmall),
                const SizedBox(height: 4),
                Text(action, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 快捷记录 + 计划/营养入口。
class HomeQuickActions extends StatelessWidget {
  final VoidCallback onRecord;
  final VoidCallback onPlan;
  final VoidCallback onNutrition;

  const HomeQuickActions({
    super.key,
    required this.onRecord,
    required this.onPlan,
    required this.onNutrition,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _QuickTile(
                icon: Icons.photo_camera_outlined,
                label: '拍照记录',
                hint: '选图后确认份量',
                onTap: onRecord,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _QuickTile(
                icon: Icons.edit_note_rounded,
                label: '文字记录',
                hint: '一句话描述这一餐',
                onTap: onRecord,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _QuickTile(
                icon: Icons.restaurant_menu_rounded,
                label: '常吃',
                hint: '复用最近的一餐',
                onTap: onRecord,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _QuickTile(
                icon: Icons.event_note_outlined,
                label: '计划',
                hint: '下一餐补什么',
                onTap: onPlan,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _QuickTile(
                icon: Icons.insights_outlined,
                label: '营养',
                hint: '缺口与下钻',
                onTap: onNutrition,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String hint;
  final VoidCallback onTap;

  const _QuickTile({
    required this.icon,
    required this.label,
    required this.hint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: t.surfaceAlt,
              borderRadius: BorderRadius.circular(t.radiusSm),
            ),
            child: Icon(icon, size: 17, color: t.ink),
          ),
          const SizedBox(height: 8),
          Text(label, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 1),
          Text(
            hint,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

/// 四轴只显示形状，不显示数字。
class PetAxisBars extends StatelessWidget {
  final PetAxes axes;

  const PetAxisBars({super.key, required this.axes});

  @override
  Widget build(BuildContext context) {
    final items = <(String, int)>[
      ('活力', axes.vitality),
      ('皮毛', axes.coat),
      ('心情', axes.mood),
      ('水分', axes.hydration),
    ];
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  items[i].$1,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: 3),
                _AxisBar(value: items[i].$2),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _AxisBar extends StatelessWidget {
  final int value;

  const _AxisBar({required this.value});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = value >= 70
        ? t.good
        : value >= 45
        ? t.inkSecondary
        : t.low;
    return ClipRRect(
      borderRadius: BorderRadius.circular(t.pillRadius),
      child: LinearProgressIndicator(
        value: (value / 100).clamp(0.0, 1.0),
        minHeight: t.isQ ? 6 : 4,
        backgroundColor: t.surfaceAlt,
        valueColor: AlwaysStoppedAnimation(color),
      ),
    );
  }
}

/// 时间线：四餐固定顺序，空槽明确显示未记录。
class TodayTimeline extends StatelessWidget {
  final List<FoodEntry> entries;
  final VoidCallback onRecord;

  const TodayTimeline({
    super.key,
    required this.entries,
    required this.onRecord,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: EmptyState(
          icon: Icons.receipt_long_outlined,
          title: '今天还没有记录',
          body: '记下第一餐，时间线会按早餐、午餐、晚餐、加餐归位。',
          action: OutlinedButton.icon(
            onPressed: onRecord,
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('记一餐'),
          ),
        ),
      );
    }

    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          for (final slot in MealSlot.values) ...[
            _SlotBlock(
              slot: slot,
              entries: entries.where((e) => e.slot == slot).toList(),
            ),
            if (slot != MealSlot.values.last) const Hairline(indent: 14),
          ],
        ],
      ),
    );
  }
}

class _SlotBlock extends StatelessWidget {
  final MealSlot slot;
  final List<FoodEntry> entries;

  const _SlotBlock({required this.slot, required this.entries});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: entries.isEmpty ? t.hairline : t.ink,
                ),
              ),
              const SizedBox(width: 7),
              Text(slot.label, style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              Text(
                entries.isEmpty ? '未记录' : '${entries.length} 条',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
          for (final entry in entries) _EntryRow(entry: entry),
        ],
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  final FoodEntry entry;

  const _EntryRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final summary = entry.items.isEmpty
        ? (entry.note?.trim().isNotEmpty == true ? entry.note!.trim() : '已记录')
        : entry.items
              .map((item) => '${item.foodName} ${item.gramsP50.round()} g')
              .join(' · ');
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 38,
            child: Text(
              _timeLabel(entry.eatenAtMs),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Expanded(
            child: Text(
              summary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: context.tokens.ink),
            ),
          ),
        ],
      ),
    );
  }

  static String _timeLabel(int ms) {
    if (ms <= 0) return '—';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}

/// 宠物商店入口。
class PetShopEntryCard extends StatelessWidget {
  final Pet? pet;
  final int coins;
  final VoidCallback onTap;

  const PetShopEntryCard({
    super.key,
    required this.pet,
    required this.coins,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: t.surfaceAlt,
              shape: BoxShape.circle,
              border: Border.all(color: t.hairline, width: t.borderWidth),
            ),
            child: Icon(Icons.pets_outlined, size: 19, color: t.ink),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('宠物商店', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 1),
                Text(
                  pet == null
                      ? '领养一只伙伴'
                      : '${pet!.name} · ${pet!.species.label} · 爪印 $coins',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: t.inkTertiary),
        ],
      ),
    );
  }
}

/// 点宠物后的解释卡：一句解释 + 一条可执行建议。
Future<void> showPetSheet(
  BuildContext context, {
  required Pet? pet,
  required PetStateResult state,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      final t = ctx.tokens;
      final navigator = Navigator.of(ctx);
      return SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pet?.name ?? '你的伙伴',
                          style: Theme.of(ctx).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '最近 7 天的状态',
                          style: Theme.of(ctx).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Pill(petSignalLabel(state.signal)),
                ],
              ),
              const SizedBox(height: 12),
              Text(state.message, style: Theme.of(ctx).textTheme.bodyLarge),
              const SizedBox(height: 16),
              PetAxisBars(axes: state.axes),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: t.surfaceAlt,
                  borderRadius: BorderRadius.circular(t.radiusMd),
                  border: Border.all(color: t.hairline, width: t.borderWidth),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('可以做的一件事', style: Theme.of(ctx).textTheme.labelSmall),
                    const SizedBox(height: 5),
                    Text(
                      state.action,
                      style: Theme.of(ctx).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '它的状态看 7 天趋势；一天的高低不会写成结论。',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: navigator.pop,
                      child: const Text('知道了'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        navigator.pop();
                        navigator.push(
                          MaterialPageRoute<void>(
                            builder: (_) => const RecordPage(),
                          ),
                        );
                      },
                      child: const Text('去记一餐'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
