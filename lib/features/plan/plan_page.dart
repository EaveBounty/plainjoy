import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/app_data.dart';
import '../../core/models/entry.dart';
import '../../core/models/enums.dart';
import '../../core/models/plan.dart';
import '../../core/plan/plan_engine.dart';
import '../../core/state/app_state.dart';
import '../../core/state/score_providers.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/util/date_utils.dart';
import '../../core/widgets/app_widgets.dart';
import '../pet/feed_effect_sheet.dart';
import 'plan_card.dart';
import 'plan_conditions_page.dart';
import 'plan_widgets.dart';

class PlanPage extends ConsumerStatefulWidget {
  const PlanPage({super.key});

  @override
  ConsumerState<PlanPage> createState() => _PlanPageState();
}

class _PlanPageState extends ConsumerState<PlanPage> {
  List<String> _notes = const [];
  bool _busy = false;

  Future<void> _openConditions(MealPlan? plan) async {
    if (_busy) return;
    final result = await Navigator.of(context).push<PlanConditionsResult>(
      MaterialPageRoute(
        builder: (_) => PlanConditionsPage(initial: plan),
      ),
    );
    if (!mounted || result == null) return;
    setState(() => _notes = result.notes);
    _toast(
      result.notes.isEmpty
          ? '计划已更新'
          : (result.relaxed ? '条件太紧，已放宽后生成' : '已按新条件生成'),
    );
  }

  /// 直接用当前条件重算整份计划（不打开条件面板）。
  Future<void> _regenerate(MealPlan plan) async {
    final data = ref.read(appStateProvider).value;
    if (data == null || _busy) return;
    setState(() => _busy = true);
    try {
      final repo = ref.read(repositoryProvider);
      final notifier = ref.read(appStateProvider.notifier);
      final days = dateRange(plan.startDate, plan.endDate).length.clamp(1, 7);
      final result = PlanEngine.generate(
        data: data,
        todayScore: ref.read(todayScoreProvider),
        constraints: plan.constraints,
        planId: repo.newId(),
        startDate: plan.startDate,
        days: days,
      );
      if (result.plan.meals.isEmpty) {
        _toast('没有可执行的菜，先补食谱或放宽条件');
        return;
      }
      await _archive(notifier, data, keep: result.plan.id);
      await notifier.savePlan(result.plan);
      if (!mounted) return;
      setState(() => _notes = result.notes);
      _toast('已重新生成 ${result.plan.meals.length} 餐');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 计划 → 记录：按 recipe 生成 EntryItem，写入 FoodEntry，再回写 done/entryId。
  Future<void> _eat(MealPlan plan, PlanMeal meal) async {
    final data = ref.read(appStateProvider).value;
    if (data == null || _busy) return;
    final recipe = data.recipeById[meal.recipeId];
    if (recipe == null) {
      _toast('找不到这道菜的食谱，可能来自旧版本；可以「换一个」');
      return;
    }
    final repo = ref.read(repositoryProvider);
    final notifier = ref.read(appStateProvider.notifier);
    final foods = data.foodById;
    final items = <EntryItem>[];
    var position = 0;
    for (final ingredient in recipe.ingredients) {
      final food = foods[ingredient.foodId];
      if (food == null) continue;
      items.add(EntryItem.fromFood(
        id: repo.newId(),
        food: food,
        gramsP10: ingredient.grams * 0.9,
        gramsP50: ingredient.grams,
        gramsP90: ingredient.grams * 1.1,
        method: EstimateMethod.plan,
        confidence: 0.8,
        position: position,
      ));
      position++;
    }
    if (items.isEmpty) {
      _toast('这道菜的食材不在食物库里，无法写入记录');
      return;
    }

    setState(() => _busy = true);
    try {
      final now = DateTime.now();
      final entryId = repo.newId();
      final entry = FoodEntry(
        id: entryId,
        profileId: data.profile?.id ?? plan.profileId,
        eatenAtMs: _eatenAtMs(meal),
        localDate: meal.localDate,
        slot: meal.slot,
        note: '计划 · ${meal.title}',
        inputMode: InputMode.plan,
        items: items,
        createdAt: now.millisecondsSinceEpoch,
        updatedAt: now.millisecondsSinceEpoch,
      );
      await notifier.saveEntry(entry);
      final updated = plan.copyWith(
        meals: [
          for (final item in plan.meals)
            if (item.id == meal.id)
              item.copyWith(done: true, entryId: entryId)
            else
              item,
        ],
        updatedAt: now.millisecondsSinceEpoch,
      );
      await notifier.savePlan(updated);
      await notifier.addCoins(3);
      if (!mounted) return;
      await showFeedEffectSheet(context, meal: meal, coins: 3);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 换一个：同 slot、同日期，排除当前菜的第一个食材，重试避免撞同一道菜。
  Future<void> _swap(MealPlan plan, PlanMeal meal) async {
    final data = ref.read(appStateProvider).value;
    if (data == null || _busy) return;
    setState(() => _busy = true);
    try {
      final notifier = ref.read(appStateProvider.notifier);
      final todayScore = ref.read(todayScoreProvider);
      final exclude = <String>{...plan.constraints.excludeFoodIds};
      final current = data.recipeById[meal.recipeId];
      if (current != null && current.ingredients.isNotEmpty) {
        exclude.add(current.ingredients.first.foodId);
      }

      PlanMeal? replacement;
      PlanGenerationResult? last;
      for (var attempt = 0; attempt < 4 && replacement == null; attempt++) {
        final result = PlanEngine.generate(
          data: data,
          todayScore: todayScore,
          constraints: plan.constraints.copyWith(excludeFoodIds: exclude),
          planId: plan.id,
          startDate: meal.localDate,
          days: 1,
          onlySlot: meal.slot,
          maxMeals: 1,
        );
        last = result;
        PlanMeal? candidate;
        for (final generated in result.plan.meals) {
          if (generated.slot == meal.slot) candidate = generated;
        }
        if (candidate == null) break;
        if (candidate.recipeId != meal.recipeId) {
          replacement = candidate;
          break;
        }
        final recipe = data.recipeById[candidate.recipeId];
        if (recipe != null) {
          exclude.addAll(recipe.ingredients.map((e) => e.foodId));
        }
      }

      if (replacement == null) {
        final notes = last?.notes ?? const <String>[];
        _toast(notes.isEmpty ? '没有更合适的替换了，先保留这道' : notes.first);
        return;
      }

      // 保留原 meal.id / sortOrder，避免卡片状态和 UI key 抖动。
      final next = PlanMeal(
        id: meal.id,
        planId: plan.id,
        localDate: meal.localDate,
        slot: meal.slot,
        recipeId: replacement.recipeId,
        title: replacement.title,
        grams: replacement.grams,
        nutrients: replacement.nutrients,
        groups: replacement.groups,
        expectedDelta: replacement.expectedDelta,
        minutes: replacement.minutes,
        cost: replacement.cost,
        steps: replacement.steps,
        reasons: replacement.reasons,
        sortOrder: meal.sortOrder,
      );
      final updated = plan.copyWith(
        meals: [
          for (final item in plan.meals)
            if (item.id == meal.id) next else item,
        ],
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      await notifier.savePlan(updated);
      if (!mounted) return;
      _toast('已换成「${next.title}」');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _archive(
    AppStateNotifier notifier,
    AppData data, {
    required String keep,
  }) async {
    final previous = data.activePlan;
    if (previous == null || previous.id == keep) return;
    if (previous.status != PlanStatus.active) return;
    await notifier.savePlan(previous.copyWith(
      status: PlanStatus.archived,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  int _eatenAtMs(PlanMeal meal) {
    final now = DateTime.now();
    final today = todayKey(now);
    if (meal.localDate.compareTo(today) >= 0) {
      return now.millisecondsSinceEpoch;
    }
    final date = parseDateKey(meal.localDate);
    final hour = switch (meal.slot) {
      MealSlot.breakfast => 8,
      MealSlot.lunch => 12,
      MealSlot.dinner => 19,
      MealSlot.snack => 15,
    };
    return DateTime(date.year, date.month, date.day, hour).millisecondsSinceEpoch;
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 2200),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);
    final data = state.value;
    if (data == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final plan = data.activePlan;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            PageHeader(
              title: '计划',
              subtitle: '补本周缺口，不是 21 餐全计划',
              actions: [
                IconButton(
                  onPressed: () => _openConditions(plan),
                  tooltip: '调整条件',
                  icon: const Icon(Icons.tune_rounded),
                ),
              ],
            ),
            if (plan == null || plan.meals.isEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _EmptyPlan(
                  hasRecipes: data.recipes.isNotEmpty,
                  busy: _busy,
                  onGenerate: () => _openConditions(null),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: PlanHealthRulesCard(profile: data.profile),
              ),
            ] else ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _PlanSummaryCard(
                  plan: plan,
                  busy: _busy,
                  onEdit: () => _openConditions(plan),
                  onRegenerate: () => _regenerate(plan),
                ),
              ),
              if (_notes.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: PlanNotesCard(
                    notes: _notes,
                    onDismiss: () => setState(() => _notes = const []),
                  ),
                ),
              ..._buildMealSections(data, plan),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: PlanHealthRulesCard(profile: data.profile),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FilledButton.icon(
                      onPressed: _busy ? null : () => _regenerate(plan),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('按当前条件重新生成'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '每周 3–5 个补丁餐就够：一份计划里不会重复同一道菜，吃腻了就「换一个」。',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildMealSections(AppData data, MealPlan plan) {
    final byDate = <String, List<PlanMeal>>{};
    for (final meal in plan.meals) {
      byDate.putIfAbsent(meal.localDate, () => []).add(meal);
    }
    final dates = byDate.keys.toList()..sort();
    final widgets = <Widget>[];
    for (final date in dates) {
      final meals = byDate[date]!
        ..sort((a, b) {
          final bySlot = mealSlotOrderKey(a.slot).compareTo(mealSlotOrderKey(b.slot));
          return bySlot != 0 ? bySlot : a.sortOrder.compareTo(b.sortOrder);
        });
      widgets.add(Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              relativeDayLabel(date),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(width: 6),
            Text(
              formatDateWithWeekday(date),
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const Spacer(),
            Text(
              '${meals.length} 餐',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ));
      for (final meal in meals) {
        widgets.add(Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: PlanMealCard(
            key: ValueKey(meal.id),
            meal: meal,
            recipe: data.recipeById[meal.recipeId],
            foods: data.foodById,
            busy: _busy,
            onEat: () => _eat(plan, meal),
            onSwap: () => _swap(plan, meal),
          ),
        ));
      }
    }
    return widgets;
  }
}

class _PlanSummaryCard extends StatelessWidget {
  const _PlanSummaryCard({
    required this.plan,
    required this.busy,
    required this.onEdit,
    required this.onRegenerate,
  });

  final MealPlan plan;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onRegenerate;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = plan.constraints;
    final done = plan.meals.where((e) => e.done).length;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(planDisplayName(plan), style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 3),
                    Text(planRangeLabel(plan), style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Pill(
                done == 0 ? '${plan.meals.length} 餐' : '$done/${plan.meals.length} 已吃',
                color: done == plan.meals.length ? t.good : t.inkSecondary,
                filled: true,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              Pill(equipmentSummary(c.equipment), icon: Icons.kitchen_outlined),
              Pill('≤ ${c.maxMinutes} 分钟', icon: Icons.timer_outlined),
              Pill('≤ ¥${c.maxCost.round()}/餐', icon: Icons.payments_outlined),
              Pill(
                tastePriorityLabels[c.tastePriority] ?? '均衡',
                icon: Icons.restaurant_menu_rounded,
              ),
              Pill(
                lazinessLabels[c.laziness] ?? '可以洗切',
                icon: Icons.cut_outlined,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: busy ? null : onEdit,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  side: BorderSide(color: t.hairline, width: t.borderWidth),
                  foregroundColor: t.ink,
                  textStyle: Theme.of(context).textTheme.labelMedium,
                ),
                icon: const Icon(Icons.tune_rounded, size: 16),
                label: const Text('调整条件'),
              ),
              const SizedBox(width: 10),
              TextButton(
                onPressed: busy ? null : onRegenerate,
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  foregroundColor: t.inkSecondary,
                  textStyle: Theme.of(context).textTheme.labelMedium,
                ),
                child: const Text('重新生成'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyPlan extends StatelessWidget {
  const _EmptyPlan({
    required this.hasRecipes,
    required this.busy,
    required this.onGenerate,
  });

  final bool hasRecipes;
  final bool busy;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: t.surfaceAlt,
                  borderRadius: BorderRadius.circular(t.radiusMd),
                  border: Border.all(color: t.hairline, width: t.borderWidth),
                ),
                child: Icon(Icons.event_note_outlined, size: 20, color: t.inkSecondary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('还没有补丁餐', style: Theme.of(context).textTheme.titleMedium),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '补丁餐不是 21 餐全计划。它只挑本周缺口最大的 3–5 项（比如铁、纤维、钙），'
            '用一两顿把缺口补上，其余餐照常吃。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.6),
          ),
          const SizedBox(height: 8),
          Text(
            '先选时间范围/设备/预算/懒度，再按今天的评分缺口生成；每道菜都会写清「补什么」。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.6),
          ),
          if (!hasRecipes) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: t.surfaceAlt,
                borderRadius: BorderRadius.circular(t.radiusSm),
              ),
              child: Text(
                '食谱库还是空的：先确认内置食谱已加载，或稍后重试；没有食谱无法生成补丁餐。',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: t.high,
                      height: 1.5,
                    ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: busy ? null : onGenerate,
            icon: const Icon(Icons.auto_awesome_rounded, size: 18),
            label: const Text('生成补丁餐'),
          ),
        ],
      ),
    );
  }
}
