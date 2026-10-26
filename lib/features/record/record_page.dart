import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/entry.dart';
import '../../core/models/enums.dart';
import '../../core/models/nutrients.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/util/date_utils.dart';
import '../../core/widgets/app_widgets.dart';
import 'container_calibration_page.dart';
import 'entry_editor.dart';
import 'widgets/entry_composer.dart';
import 'widgets/record_common.dart';

class RecordPage extends ConsumerStatefulWidget {
  const RecordPage({super.key});

  @override
  ConsumerState<RecordPage> createState() => _RecordPageState();
}

class _RecordPageState extends ConsumerState<RecordPage> {
  String _date = todayKey();
  final Set<String> _pendingDelete = <String>{};

  Future<void> _openComposer(ComposerMode mode) async {
    final saved = await showEntryComposer(
      context,
      date: _date,
      initialMode: mode,
    );
    if (saved == true && mounted) {
      showToast(context, '已记录 ✓');
    }
  }

  Future<void> _openEditor(FoodEntry entry) async {
    final changed = await showEntryEditor(context, entry: entry);
    if (changed == true && mounted) {
      showToast(context, '已更新 ✓');
    }
  }

  Future<bool> _confirmDelete(FoodEntry entry) async {
    final t = context.tokens;
    final kcal = entriesNutrientRange([entry], NutrientCode.energy);
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: t.surface,
        title: const Text('删除这条记录？'),
        content: Text(
          '${entry.slot.label} · ${entry.items.length} 项 · '
          '约 ${formatKcal(kcal.p50)} kcal。删除后无法撤销。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: t.veryHigh),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _delete(FoodEntry entry) async {
    // Dismissible 要求确认后立刻从树里消失；先本地摘除，再异步落库。
    setState(() => _pendingDelete.add(entry.id));
    try {
      await ref.read(appStateProvider.notifier).deleteEntry(entry.id);
      if (mounted) showToast(context, '已删除');
    } catch (_) {
      if (!mounted) return;
      setState(() => _pendingDelete.remove(entry.id));
      showToast(context, '删除失败，请再试一次');
    }
  }

  Future<void> _deleteWithConfirm(FoodEntry entry) async {
    final ok = await _confirmDelete(entry);
    if (ok) await _delete(entry);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final data = ref.watch(dataProvider);
    final entries = (data?.entriesForDate(_date) ?? const <FoodEntry>[])
        .where((entry) => !_pendingDelete.contains(entry.id))
        .toList();
    final kcal = entriesNutrientRange(entries, NutrientCode.energy);
    final protein = entriesNutrientRange(entries, NutrientCode.protein);
    final sodium = entriesNutrientRange(entries, NutrientCode.sodium);
    final today = todayKey();
    final dateValues = [addDaysKey(today, -1), today, addDaysKey(today, 1)];
    final grouped = <MealSlot, List<FoodEntry>>{
      for (final slot in MealSlot.values)
        slot: entries.where((entry) => entry.slot == slot).toList(),
    };

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              title: '记录',
              subtitle:
                  '${relativeDayLabel(_date)} · ${formatDateWithWeekday(_date)}',
              actions: [
                IconButton(
                  tooltip: '容器标定',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ContainerCalibrationPage(),
                    ),
                  ),
                  icon: const Icon(Icons.rice_bowl_outlined),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: SegmentedChoice<String>(
                values: dateValues,
                selected: _date,
                label: relativeDayLabel,
                onChanged: (value) => setState(() => _date = value),
                dense: true,
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
                children: [
                  _OverviewCard(
                    kcal: kcal,
                    protein: protein,
                    sodium: sodium,
                    entryCount: entries.length,
                    isToday: _date == today,
                  ),
                  const SizedBox(height: 18),
                  if (entries.isEmpty)
                    _EmptyRecord(
                      dayLabel: relativeDayLabel(_date),
                      onText: () => _openComposer(ComposerMode.text),
                      onPhoto: () => _openComposer(ComposerMode.photo),
                      onSearch: () => _openComposer(ComposerMode.search),
                    )
                  else
                    for (final slot in MealSlot.values)
                      if (grouped[slot]!.isNotEmpty) ...[
                        _SlotHeader(slot: slot, entries: grouped[slot]!),
                        const SizedBox(height: 8),
                        for (final entry in grouped[slot]!)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Dismissible(
                              key: ValueKey('entry-${entry.id}'),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                decoration: BoxDecoration(
                                  color: t.veryHigh,
                                  borderRadius: BorderRadius.circular(
                                    t.radiusLg,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.delete_outline_rounded,
                                      color: t.accentInk,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      '删除',
                                      style: TextStyle(
                                        color: t.accentInk,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              confirmDismiss: (_) => _confirmDelete(entry),
                              onDismissed: (_) => _delete(entry),
                              child: GestureDetector(
                                onLongPress: () => _deleteWithConfirm(entry),
                                child: _EntryCard(
                                  entry: entry,
                                  onTap: () => _openEditor(entry),
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 10),
                      ],
                  if (entries.isNotEmpty)
                    Text(
                      '左滑或长按可删除；点条目改份量。区间是估算，不是精确值。',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openComposer(ComposerMode.text),
        icon: const Icon(Icons.add_rounded),
        label: const Text('记一餐'),
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  final NutrientRange kcal;
  final NutrientRange protein;
  final NutrientRange sodium;
  final int entryCount;
  final bool isToday;

  const _OverviewCard({
    required this.kcal,
    required this.protein,
    required this.sodium,
    required this.entryCount,
    required this.isToday,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final sodiumColor = sodium.p50 <= 1500
        ? t.good
        : sodium.p50 <= 2000
        ? t.ink
        : sodium.p50 <= 4000
        ? t.high
        : t.veryHigh;
    Widget divider() =>
        Container(width: t.borderWidth, height: 38, color: t.hairline);

    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                isToday ? '今日概览' : '当日概览',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const Spacer(),
              Text(
                entryCount == 0 ? '还没记录' : '$entryCount 条记录',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StatBlock(
                  label: '热量',
                  value: formatKcal(kcal.p50),
                  unit: 'kcal',
                  sub: '${formatKcal(kcal.p10)}–${formatKcal(kcal.p90)}',
                ),
              ),
              divider(),
              const SizedBox(width: 12),
              Expanded(
                child: StatBlock(
                  label: '蛋白质',
                  value: protein.p50.toStringAsFixed(0),
                  unit: 'g',
                  sub: '${protein.p10.round()}–${protein.p90.round()} g',
                ),
              ),
              divider(),
              const SizedBox(width: 12),
              Expanded(
                child: StatBlock(
                  label: '钠',
                  value: formatKcal(sodium.p50),
                  unit: 'mg',
                  sub: '理想 1500 · 上限 2000',
                  valueColor: sodiumColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.straighten_rounded, size: 13, color: t.inkTertiary),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  '热量/蛋白质按 p10–p90 区间汇总；单餐误差是常态，先看趋势。',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SlotHeader extends StatelessWidget {
  final MealSlot slot;
  final List<FoodEntry> entries;

  const _SlotHeader({required this.slot, required this.entries});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final kcal = entriesNutrientRange(entries, NutrientCode.energy);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(slot.label, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(width: 8),
        Text(
          '${entries.length} 条',
          style: Theme.of(context).textTheme.labelSmall,
        ),
        const Spacer(),
        Text(
          formatKcalRange(kcal),
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: t.inkSecondary),
        ),
      ],
    );
  }
}

class _EntryCard extends StatelessWidget {
  final FoodEntry entry;
  final VoidCallback onTap;

  const _EntryCard({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final kcal = entriesNutrientRange([entry], NutrientCode.energy);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                timeLabel(entry.eatenAtMs),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                inputModeIcon(entry.inputMode),
                size: 13,
                color: t.inkTertiary,
              ),
              const SizedBox(width: 3),
              Text(
                inputModeLabel(entry.inputMode),
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const Spacer(),
              Text(
                '≈ ${formatKcal(kcal.p50)} kcal',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              formatKcalRange(kcal),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
          const SizedBox(height: 8),
          Hairline(),
          for (var i = 0; i < entry.items.length; i++) ...[
            if (i > 0) Hairline(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: _EntryItemRow(item: entry.items[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _EntryItemRow extends StatelessWidget {
  final EntryItem item;

  const _EntryItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final kcal = itemNutrientRange(item, NutrientCode.energy);
    final grams = (p10: item.gramsP10, p50: item.gramsP50, p90: item.gramsP90);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.foodName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 3),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    formatGramRange(grams),
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: t.inkSecondary),
                  ),
                  MethodChip(item.method),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '≈ ${formatKcal(kcal.p50)}',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Text(
              '${formatKcal(kcal.p10)}–${formatKcal(kcal.p90)}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ],
    );
  }
}

class _EmptyRecord extends StatelessWidget {
  final String dayLabel;
  final VoidCallback onText;
  final VoidCallback onPhoto;
  final VoidCallback onSearch;

  const _EmptyRecord({
    required this.dayLabel,
    required this.onText,
    required this.onPhoto,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: t.surfaceAlt,
              shape: BoxShape.circle,
              border: Border.all(color: t.hairline, width: t.borderWidth),
            ),
            child: Icon(
              Icons.restaurant_outlined,
              size: 24,
              color: t.inkSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '$dayLabel还没有记录',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            '记一餐 10 秒就够：说一句、拍一张，或者搜一个常吃的。\n'
            '不知道份量也行，先记个大概。',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _EntryAction(
                  icon: Icons.notes_rounded,
                  label: '文字',
                  hint: '说一句',
                  onTap: onText,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _EntryAction(
                  icon: Icons.photo_camera_outlined,
                  label: '拍照',
                  hint: '识别餐食',
                  onTap: onPhoto,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _EntryAction(
                  icon: Icons.search_rounded,
                  label: '搜索',
                  hint: '常吃/最近',
                  onTap: onSearch,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '记录时只回「已记录」，不评判。',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

class _EntryAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final String hint;
  final VoidCallback onTap;

  const _EntryAction({
    required this.icon,
    required this.label,
    required this.hint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(t.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: t.surfaceAlt,
          borderRadius: BorderRadius.circular(t.radiusMd),
          border: Border.all(color: t.hairline, width: t.borderWidth),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: t.ink),
            const SizedBox(height: 6),
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
      ),
    );
  }
}
