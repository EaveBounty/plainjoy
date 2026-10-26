import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/entry.dart';
import '../../core/models/enums.dart';
import '../../core/models/nutrients.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/app_tokens.dart';
import 'portion_sheet.dart';
import 'widgets/record_common.dart';

/// 返回 true 表示条目被修改或删除。
Future<bool?> showEntryEditor(
  BuildContext context, {
  required FoodEntry entry,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => EntryEditorSheet(entry: entry),
  );
}

PrecisionTier tierForMethod(EstimateMethod method) => switch (method) {
  EstimateMethod.weighed => PrecisionTier.precise,
  EstimateMethod.container ||
  EstimateMethod.reference => PrecisionTier.standard,
  _ => PrecisionTier.quick,
};

class EntryEditorSheet extends ConsumerStatefulWidget {
  final FoodEntry entry;

  const EntryEditorSheet({super.key, required this.entry});

  @override
  ConsumerState<EntryEditorSheet> createState() => _EntryEditorSheetState();
}

class _EntryEditorSheetState extends ConsumerState<EntryEditorSheet> {
  late MealSlot _slot;
  late List<EntryItem> _items;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _slot = widget.entry.slot;
    _items = widget.entry.items.toList()
      ..sort((a, b) => a.position.compareTo(b.position));
  }

  Future<void> _editItem(int index) async {
    final item = _items[index];
    final data = ref.read(dataProvider);
    final food = item.foodId == null ? null : data?.foodById[item.foodId];
    final estimateFood = food ?? foodSnapshotFromItem(item);
    final entries = data?.entries ?? const <FoodEntry>[];
    final choice = await showPortionSheet(
      context,
      food: estimateFood,
      initial: PortionChoice(
        gramsP10: item.gramsP10,
        gramsP50: item.gramsP50,
        gramsP90: item.gramsP90,
        method: item.method,
        confidence: item.confidence,
        explanation: '',
        tier: tierForMethod(item.method),
        containerId: item.containerId,
        referenceObjectId: item.referenceObjectId,
      ),
      personalMedian: historyMedianGrams(entries, item.foodId ?? ''),
    );
    if (choice == null || !mounted) return;
    setState(() {
      _items[index] = rebuildItem(
        base: item,
        p10: choice.gramsP10,
        p50: choice.gramsP50,
        p90: choice.gramsP90,
        method: choice.method,
        confidence: choice.confidence,
        containerId: choice.containerId,
        referenceObjectId: choice.referenceObjectId,
        food: food,
      );
    });
  }

  Future<void> _deleteItem(int index) async {
    final item = _items[index];
    if (_items.length == 1) {
      final removeEntry = await _confirm(
        title: '删除整条记录？',
        body: '「${item.foodName}」是这条记录里唯一的食物。删除后这条记录会消失。',
        confirm: '删除',
      );
      if (removeEntry == true) await _deleteEntry();
      return;
    }
    final ok = await _confirm(
      title: '移除这一项？',
      body: '只删除「${item.foodName}」，其余食物保留。',
      confirm: '移除',
    );
    if (ok != true || !mounted) return;
    setState(() {
      _items.removeAt(index);
      for (var i = 0; i < _items.length; i++) {
        _items[i] = _items[i].copyWith(position: i);
      }
    });
  }

  Future<bool?> _confirm({
    required String title,
    required String body,
    required String confirm,
  }) {
    final t = context.tokens;
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: t.surface,
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: t.veryHigh),
            child: Text(confirm),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_items.isEmpty || _saving) return;
    setState(() => _saving = true);
    await ref
        .read(appStateProvider.notifier)
        .saveEntry(
          widget.entry.copyWith(
            items: _items,
            slot: _slot,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _deleteEntry() async {
    if (_saving) return;
    setState(() => _saving = true);
    await ref.read(appStateProvider.notifier).deleteEntry(widget.entry.id);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _confirmDeleteEntry() async {
    final ok = await _confirm(
      title: '删除这条记录？',
      body:
          '${widget.entry.slot.label} · ${widget.entry.items.length} 项。删除后无法撤销。',
      confirm: '删除',
    );
    if (ok == true) await _deleteEntry();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final totals = <NutrientRange>[
      for (final item in _items) itemNutrientRange(item, NutrientCode.energy),
    ];
    final kcal = (
      p10: totals.fold<double>(0, (sum, e) => sum + e.p10),
      p50: totals.fold<double>(0, (sum, e) => sum + e.p50),
      p90: totals.fold<double>(0, (sum, e) => sum + e.p90),
    );
    final maxHeight = MediaQuery.of(context).size.height * 0.92;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '编辑记录',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.entry.localDate} ${timeLabel(widget.entry.eatenAtMs)} · '
                          '${inputModeLabel(widget.entry.inputMode)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: Icon(
                      Icons.close_rounded,
                      color: t.inkSecondary,
                      size: 20,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: SegmentedChoice<MealSlot>(
                values: MealSlot.values,
                selected: _slot,
                label: (slot) => slot.label,
                onChanged: (slot) => setState(() => _slot = slot),
                dense: true,
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '这一餐 · ${_items.length} 项',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      Text(
                        formatKcalRange(kcal),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (var i = 0; i < _items.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _EditableItem(
                        item: _items[i],
                        onTap: () => _editItem(i),
                        onDelete: () => _deleteItem(i),
                      ),
                    ),
                  if (widget.entry.note != null &&
                      widget.entry.note!.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '备注：${widget.entry.note}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    '改份量只调整区间，不会评判；保存后营养与评分会重新计算。',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
              decoration: BoxDecoration(
                color: t.surface,
                border: Border(
                  top: BorderSide(color: t.hairline, width: t.borderWidth),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    TextButton(
                      onPressed: _saving ? null : _confirmDeleteEntry,
                      style: TextButton.styleFrom(foregroundColor: t.veryHigh),
                      child: const Text('删除整条'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: _items.isEmpty || _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('保存修改'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditableItem extends StatelessWidget {
  final EntryItem item;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _EditableItem({
    required this.item,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final kcal = itemNutrientRange(item, NutrientCode.energy);
    final grams = (p10: item.gramsP10, p50: item.gramsP50, p90: item.gramsP90);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(t.radiusMd),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(t.radiusMd),
          border: Border.all(color: t.hairline, width: t.borderWidth),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.foodName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  tooltip: '移除',
                  onPressed: onDelete,
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: t.inkTertiary,
                  ),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 4,
              children: [
                MethodChip(item.method),
                Text(
                  '${item.gramsP50.round()} g · ${formatGramRange(grams)}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                Text(
                  formatKcalRange(kcal),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                Text(
                  '置信度 ${confidenceLabel(item.confidence)}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: confidenceColor(t, item.confidence),
                  ),
                ),
                const Spacer(),
                Text('点一下改份量', style: Theme.of(context).textTheme.labelSmall),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: t.inkTertiary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
