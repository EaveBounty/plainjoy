import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/health/health_rules.dart';
import '../../core/models/app_data.dart';
import '../../core/models/enums.dart';
import '../../core/models/plan.dart';
import '../../core/plan/plan_engine.dart';
import '../../core/state/app_state.dart';
import '../../core/state/score_providers.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/util/date_utils.dart';
import '../../core/widgets/app_widgets.dart';
import 'plan_widgets.dart';

class PlanConditionsResult {
  const PlanConditionsResult({required this.notes, required this.relaxed});

  final List<String> notes;
  final bool relaxed;
}

class PlanConditionsPage extends ConsumerStatefulWidget {
  const PlanConditionsPage({super.key, this.initial});

  final MealPlan? initial;

  @override
  ConsumerState<PlanConditionsPage> createState() => _PlanConditionsPageState();
}

class _PlanConditionsPageState extends ConsumerState<PlanConditionsPage> {
  static const _timeSteps = <num>[10, 20, 30, 45, 60];
  static const _budgetSteps = <num>[10, 20, 30, 40, 50, 60];

  late Set<String> _equipment;
  late int _minutes;
  late double _budget;
  late String _taste;
  late String _laziness;
  late Set<String> _excludeTags;
  late Set<String> _allergyTerms;

  late String _range;
  late String _startDate;
  late int _days;
  MealSlot? _onlySlot;

  final _allergyController = TextEditingController();

  Timer? _debounce;
  PlanGenerationResult? _preview;
  bool _previewing = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    final profile = ref.read(profileProvider);
    final constraints = initial?.constraints ?? const PlanConstraints();
    _equipment = Set.of(
      initial?.constraints.equipment ??
          (profile != null && profile.equipment.isNotEmpty
              ? profile.equipment
              : const PlanConstraints().equipment),
    );
    _minutes = _timeSteps[_closestIndex(_timeSteps, constraints.maxMinutes)].round();
    _budget = _budgetSteps[_closestIndex(_budgetSteps, constraints.maxCost)].toDouble();
    _taste = tastePriorityLabels.containsKey(constraints.tastePriority)
        ? constraints.tastePriority
        : 'balanced';
    _laziness = lazinessLabels.containsKey(constraints.laziness)
        ? constraints.laziness
        : 'canPrep';
    _excludeTags = Set.of(constraints.excludeTags);
    _allergyTerms = Set.of(profile?.allergies ?? const <String>{});

    final now = DateTime.now();
    if (initial == null) {
      _range = 'next';
      _startDate = todayKey(now);
      _days = 1;
      _onlySlot = PlanEngine.nextSlot(now);
    } else {
      final length = dateRange(initial.startDate, initial.endDate).length;
      _days = length.clamp(1, 7);
      _startDate = initial.startDate;
      _onlySlot = null;
      if (initial.startDate == addDaysKey(todayKey(now), 1)) {
        _range = 'tomorrow';
      } else if (_days >= 4) {
        _range = 'week';
      } else if (_days >= 2) {
        _range = 'threeDays';
      } else {
        _range = 'next';
        _onlySlot = PlanEngine.nextSlot(now);
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _allergyController.dispose();
    super.dispose();
  }

  // ---------- 条件状态 ----------

  void _selectRange(String range) {
    final now = DateTime.now();
    setState(() {
      _range = range;
      switch (range) {
        case 'next':
          _startDate = todayKey(now);
          _days = 1;
          _onlySlot = PlanEngine.nextSlot(now);
        case 'tomorrow':
          _startDate = addDaysKey(todayKey(now), 1);
          _days = 1;
          _onlySlot = null;
        case 'threeDays':
          _startDate = todayKey(now);
          _days = 3;
          _onlySlot = null;
        case 'week':
          _startDate = todayKey(now);
          _days = (8 - now.weekday).clamp(1, 7);
          _onlySlot = null;
      }
    });
    _markDirty();
  }

  void _toggleEquipment(String id) {
    setState(() {
      if (id == 'none') {
        _equipment = <String>{};
        _laziness = 'noCook';
      } else {
        if (_equipment.contains(id)) {
          _equipment.remove(id);
        } else {
          _equipment.add(id);
        }
        if (_equipment.isEmpty) {
          _laziness = 'noCook';
        } else if (_laziness == 'noCook') {
          _laziness = 'canPrep';
        }
      }
    });
    _markDirty();
  }

  void _toggleTag(String tag) {
    setState(() {
      if (!_excludeTags.remove(tag)) _excludeTags.add(tag);
    });
    _markDirty();
  }

  void _addAllergyTerm(String raw) {
    final term = raw.trim();
    if (term.isEmpty) return;
    setState(() {
      _allergyTerms.add(term);
      _allergyController.clear();
    });
    _markDirty();
  }

  void _removeAllergyTerm(String term) {
    setState(() => _allergyTerms.remove(term));
    _markDirty();
  }

  PlanConstraints _buildConstraints(AppData data) {
    // 忌口文本 → 食物 id：只要食物名/别名/标签包含关键词就排除。
    final excludeFoodIds = <String>{
      ...?widget.initial?.constraints.excludeFoodIds,
    };
    for (final term in _allergyTerms) {
      final needle = term.trim().toLowerCase();
      if (needle.isEmpty) continue;
      for (final food in data.foods) {
        final haystack =
            '${food.name} ${food.aliases.join(' ')} ${food.tags.join(' ')}'.toLowerCase();
        if (haystack.contains(needle)) excludeFoodIds.add(food.id);
      }
    }
    final excludeTags = <String>{..._excludeTags};
    // 油炸没有对应食谱标签时，用食物标签兜底（fried → 含油炸食材的菜整道排除）。
    if (_excludeTags.contains('油炸')) {
      for (final food in data.foods) {
        if (food.tags.contains('fried') || food.name.contains('炸')) {
          excludeFoodIds.add(food.id);
        }
      }
      excludeTags.remove('油炸');
    }
    return PlanConstraints(
      equipment: Set.of(_equipment),
      maxMinutes: _minutes,
      maxCost: _budget,
      tastePriority: _taste,
      laziness: _equipment.isEmpty ? 'noCook' : _laziness,
      useLeftovers: true,
      excludeFoodIds: excludeFoodIds,
      excludeTags: excludeTags,
    );
  }

  /// 改动后 3 秒内自动重算一次预览，避免每次拖动都刷结果。
  void _markDirty() {
    _debounce?.cancel();
    setState(() {
      _preview = null;
      _previewing = true;
      _error = null;
    });
    _debounce = Timer(const Duration(seconds: 3), _recomputePreview);
  }

  void _recomputePreview() {
    if (!mounted) return;
    final data = ref.read(appStateProvider).value;
    if (data == null) {
      setState(() => _previewing = false);
      return;
    }
    final result = PlanEngine.generate(
      data: data,
      todayScore: ref.read(todayScoreProvider),
      constraints: _buildConstraints(data),
      planId: 'preview',
      startDate: _startDate,
      days: _days,
      onlySlot: _onlySlot,
    );
    setState(() {
      _preview = result;
      _previewing = false;
    });
  }

  Future<void> _generate() async {
    if (_saving) return;
    final data = ref.read(appStateProvider).value;
    if (data == null) return;
    _debounce?.cancel();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repo = ref.read(repositoryProvider);
      final notifier = ref.read(appStateProvider.notifier);
      final result = PlanEngine.generate(
        data: data,
        todayScore: ref.read(todayScoreProvider),
        constraints: _buildConstraints(data),
        planId: repo.newId(),
        startDate: _startDate,
        days: _days,
        onlySlot: _onlySlot,
      );
      if (result.plan.meals.isEmpty) {
        setState(() {
          _error = '没有可执行的菜：先把食谱导入，或放宽设备/时间/预算/排除条件。';
          _saving = false;
        });
        return;
      }
      final previous = data.activePlan;
      if (previous != null && previous.status == PlanStatus.active) {
        await notifier.savePlan(previous.copyWith(
          status: PlanStatus.archived,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ));
      }
      await notifier.savePlan(result.plan);
      if (!mounted) return;
      Navigator.of(context).pop(
        PlanConditionsResult(notes: result.notes, relaxed: result.relaxed),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final data = ref.watch(appStateProvider).value;
    final rules = HealthRules.forProfile(data?.profile);
    final mealCount = _preview?.plan.meals.length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('调整条件'),
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            Text(
              '条件只影响「补哪几口」的排序和过滤；营养数字来自食物库，健康规则来自本机规则表，不走 LLM。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.55),
            ),
            const SizedBox(height: 14),
            _Panel(
              title: '时间范围',
              subtitle: _rangeHint(),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final item in const [
                    ('next', '下一餐'),
                    ('tomorrow', '明天'),
                    ('threeDays', '未来 3 天'),
                    ('week', '本周'),
                  ])
                    PlanChoiceChip(
                      label: item.$2,
                      selected: _range == item.$1,
                      onTap: () => _selectRange(item.$1),
                    ),
                ],
              ),
            ),
            _Panel(
              title: '设备',
              subtitle: '食谱必须只用勾选的设备；都不勾等于「不做饭」。',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final id in equipmentOrder)
                    PlanChoiceChip(
                      label: equipmentLabel(id),
                      icon: _equipmentIcon(id),
                      selected: _equipment.contains(id),
                      onTap: () => _toggleEquipment(id),
                    ),
                  PlanChoiceChip(
                    label: '不做饭',
                    icon: Icons.no_meals_outlined,
                    selected: _equipment.isEmpty,
                    onTap: () => _toggleEquipment('none'),
                  ),
                ],
              ),
            ),
            _Panel(
              title: '可用时间',
              subtitle: '单道菜从开火到上桌的上限。',
              child: PlanStepSlider(
                values: _timeSteps,
                index: _timeIndex(),
                formatValue: (value) => '${value.round()} 分钟',
                hint: '包括洗切',
                onChanged: (index) {
                  setState(() => _minutes = _timeSteps[index].round());
                  _markDirty();
                },
              ),
            ),
            _Panel(
              title: '预算',
              subtitle: '单餐食材成本，不含外卖配送费。',
              child: PlanStepSlider(
                values: _budgetSteps,
                index: _budgetIndex(),
                formatValue: (value) => '¥${value.round()}',
                hint: '每餐',
                onChanged: (index) {
                  setState(() => _budget = _budgetSteps[index].toDouble());
                  _markDirty();
                },
              ),
            ),
            _Panel(
              title: '味道优先级',
              subtitle: '味道优先会放宽健康排序；健康优先会压钠/糖/超加工。',
              child: _Segmented(
                segments: const [
                  ButtonSegment(value: 'taste', label: Text('味道优先')),
                  ButtonSegment(value: 'balanced', label: Text('均衡')),
                  ButtonSegment(value: 'health', label: Text('健康优先')),
                ],
                selected: _taste,
                onChanged: (value) {
                  setState(() => _taste = value);
                  _markDirty();
                },
              ),
            ),
            _Panel(
              title: '懒度',
              subtitle: '不想切菜只留免煮/外卖/≤10 分钟的菜。',
              child: _Segmented(
                segments: const [
                  ButtonSegment(value: 'noCook', label: Text('不想切菜')),
                  ButtonSegment(value: 'canPrep', label: Text('可以洗切')),
                  ButtonSegment(value: 'mealPrep', label: Text('愿意备餐')),
                ],
                selected: _laziness,
                onChanged: (value) {
                  setState(() {
                    _laziness = value;
                    // 没有设备还要洗切/备餐是自相矛盾：默认补一个电磁炉。
                    if (value != 'noCook' && _equipment.isEmpty) {
                      _equipment = {'induction'};
                    }
                  });
                  _markDirty();
                },
              ),
            ),
            _Panel(
              title: '过敏 / 忌口',
              subtitle: '按食物名、别名、标签排除整道菜；健康档案里的过敏始终生效，删掉这里也不会被放回。',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_allergyTerms.isEmpty)
                    Text('没有额外忌口', style: Theme.of(context).textTheme.bodySmall)
                  else
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final term in _allergyTerms)
                          InputChip(
                            label: Text(term),
                            onDeleted: () => _removeAllergyTerm(term),
                            deleteIcon: const Icon(Icons.close_rounded, size: 14),
                            labelStyle: Theme.of(context).textTheme.labelSmall,
                            visualDensity: VisualDensity.compact,
                            side: BorderSide(color: t.hairline, width: t.borderWidth),
                            backgroundColor: t.surface,
                            deleteIconColor: t.inkTertiary,
                          ),
                      ],
                    ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _allergyController,
                          textInputAction: TextInputAction.done,
                          onSubmitted: _addAllergyTerm,
                          style: Theme.of(context).textTheme.bodyMedium,
                          decoration: const InputDecoration(
                            hintText: '例如：花生、虾、香菜',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => _addAllergyTerm(_allergyController.text),
                        icon: const Icon(Icons.add_rounded),
                        tooltip: '添加忌口',
                        style: IconButton.styleFrom(
                          backgroundColor: t.surfaceAlt,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(t.radiusMd),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            _Panel(
              title: '排除口感',
              subtitle: '按食谱标签精确过滤；油炸会额外排除含油炸食材的菜。',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in exclusionTagOptions)
                    PlanChoiceChip(
                      label: tag,
                      selected: _excludeTags.contains(tag),
                      onTap: () => _toggleTag(tag),
                    ),
                ],
              ),
            ),
            if (rules.isNotEmpty)
              _Panel(
                title: '健康档案规则',
                subtitle: '避免类做硬过滤，限制类进入钠/糖/饱和脂肪惩罚，推荐类参与缺口打分。',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final rule in rules
                        .where((r) =>
                            r.category == HealthRuleCategory.avoid ||
                            r.category == HealthRuleCategory.limit ||
                            r.category == HealthRuleCategory.recommend)
                        .take(4))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          '· ${rule.title}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.45),
                        ),
                      ),
                    Text(
                      '这不是医疗诊断；用药、化验与症状请找医生。',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            _PreviewBanner(
              previewing: _previewing,
              preview: _preview,
              error: _error,
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _saving ? null : _generate,
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              label: Text(
                _saving
                    ? '正在生成…'
                    : (mealCount == null || mealCount == 0
                        ? '生成计划'
                        : '应用这个计划（$mealCount 餐）'),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '目标日期 ${formatDateWithWeekday(_startDate)}'
              '${_days > 1 ? ' 起 $_days 天' : ''}'
              '${_onlySlot != null ? ' · ${_onlySlot!.label}' : ''}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }

  String _rangeHint() {
    switch (_range) {
      case 'next':
        return '只排${_onlySlot?.label ?? '下一餐'}的 1 个主方案，最省决策。';
      case 'tomorrow':
        return '明天的 3 餐里挑补丁，按缺口排序。';
      case 'threeDays':
        return '未来 3 天最多 5 个补丁餐，避免天天吃同一道。';
      case 'week':
        return '本周剩余 $_days 天，只补最缺的 3–5 项，不做 21 餐全计划。';
      default:
        return '';
    }
  }

  int _timeIndex() => _closestIndex(_timeSteps, _minutes);

  int _budgetIndex() => _closestIndex(_budgetSteps, _budget);

  static int _closestIndex(List<num> steps, num value) {
    var best = 0;
    for (var i = 0; i < steps.length; i++) {
      if ((steps[i] - value).abs() < (steps[best] - value).abs()) best = i;
    }
    return best;
  }

  IconData _equipmentIcon(String id) => switch (id) {
        'induction' => Icons.local_fire_department_outlined,
        'microwave' => Icons.microwave_outlined,
        'riceCooker' => Icons.rice_bowl_outlined,
        'oven' => Icons.bakery_dining_outlined,
        'airFryer' => Icons.blender_outlined,
        _ => Icons.kitchen_outlined,
      };
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, this.subtitle, required this.child});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            if (subtitle != null) ...[
              const SizedBox(height: 3),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.45),
              ),
            ],
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  final List<ButtonSegment<String>> segments;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<String>(
        showSelectedIcon: false,
        segments: segments,
        selected: {selected},
        onSelectionChanged: (values) {
          if (values.isEmpty) return;
          onChanged(values.first);
        },
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          ),
          textStyle: WidgetStatePropertyAll(Theme.of(context).textTheme.labelMedium),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected) ? t.accent : t.surface;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected) ? t.accentInk : t.inkSecondary;
          }),
          side: WidgetStateProperty.resolveWith((states) {
            return BorderSide(
              color: states.contains(WidgetState.selected) ? t.accent : t.hairline,
              width: t.borderWidth,
            );
          }),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(t.radiusMd),
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewBanner extends StatelessWidget {
  const _PreviewBanner({
    required this.previewing,
    required this.preview,
    required this.error,
  });

  final bool previewing;
  final PlanGenerationResult? preview;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (error != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: t.veryHigh.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(t.radiusMd),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline_rounded, size: 16, color: t.veryHigh),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                error!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.veryHigh),
              ),
            ),
          ],
        ),
      );
    }
    if (previewing) {
      return Row(
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.6,
              color: t.inkTertiary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '条件已改动，3 秒内自动重算预览…',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ],
      );
    }
    final result = preview;
    if (result == null) return const SizedBox.shrink();
    final meals = result.plan.meals;
    final titles = meals.take(3).map((e) => e.title).join('、');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: t.surfaceAlt,
        borderRadius: BorderRadius.circular(t.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt_rounded, size: 16, color: t.inkSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  meals.isEmpty
                      ? '按当前条件没有可执行的菜'
                      : '预览：${meals.length} 餐${titles.isEmpty ? '' : ' · $titles'}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: t.ink,
                        height: 1.45,
                      ),
                ),
              ),
            ],
          ),
          if (result.relaxed)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '条件偏紧，已自动放宽并标注取舍。',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: t.high),
              ),
            ),
        ],
      ),
    );
  }
}
