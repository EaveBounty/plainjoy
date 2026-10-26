import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/container.dart';
import '../../core/models/enums.dart';
import '../../core/models/food.dart';
import '../../core/portion/portion_estimator.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/app_tokens.dart';
import 'container_calibration_page.dart';
import 'widgets/record_common.dart';

/// 份量弹层的结果。只带估算结果，不负责落库。
class PortionChoice {
  final double gramsP10;
  final double gramsP50;
  final double gramsP90;
  final EstimateMethod method;
  final double confidence;
  final String explanation;
  final PrecisionTier tier;
  final String? containerId;
  final String? referenceObjectId;

  const PortionChoice({
    required this.gramsP10,
    required this.gramsP50,
    required this.gramsP90,
    required this.method,
    required this.confidence,
    required this.explanation,
    required this.tier,
    this.containerId,
    this.referenceObjectId,
  });

  NutrientRange get grams => (p10: gramsP10, p50: gramsP50, p90: gramsP90);

  PortionEstimate toEstimate() => PortionEstimate(
    gramsP10: gramsP10,
    gramsP50: gramsP50,
    gramsP90: gramsP90,
    method: method,
    confidence: confidence,
    explanation: explanation,
    containerId: containerId,
    referenceObjectId: referenceObjectId,
  );
}

Future<PortionChoice?> showPortionSheet(
  BuildContext context, {
  required Food food,
  PrecisionTier? initialTier,
  PortionChoice? initial,
  double? personalMedian,
}) {
  return showModalBottomSheet<PortionChoice>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => PortionSheet(
      food: food,
      initialTier: initialTier,
      initial: initial,
      personalMedian: personalMedian,
    ),
  );
}

class PortionSheet extends ConsumerStatefulWidget {
  final Food food;
  final PrecisionTier? initialTier;
  final PortionChoice? initial;
  final double? personalMedian;

  const PortionSheet({
    super.key,
    required this.food,
    this.initialTier,
    this.initial,
    this.personalMedian,
  });

  @override
  ConsumerState<PortionSheet> createState() => _PortionSheetState();
}

class _PortionSheetState extends ConsumerState<PortionSheet> {
  late PrecisionTier _tier;
  int _ordinal = 2;
  double _leftover = 0;
  bool _containerMode = true;
  String? _containerId;
  String? _referenceId;
  double _fill = 0.8;
  int _refCount = 1;
  final TextEditingController _gramsCtrl = TextEditingController();
  String? _note;

  Food get _food => widget.food;

  @override
  void initState() {
    super.initState();
    final data = ref.read(dataProvider);
    final containers = data?.containers ?? const <FoodContainer>[];
    final refs = data?.referenceObjects ?? const <ReferenceObject>[];
    final initial = widget.initial;
    _tier =
        initial?.tier ??
        widget.initialTier ??
        ref.read(settingsProvider).precision;

    _containerId = initial?.containerId ?? containers.firstOrNull?.id;
    _referenceId = initial?.referenceObjectId ?? refs.firstOrNull?.id;
    if (initial != null) {
      _gramsCtrl.text = initial.gramsP50.round().toString();
      if (initial.tier == PrecisionTier.standard) {
        _containerMode =
            initial.containerId != null || initial.referenceObjectId == null;
      }
      _leftover = 0;
    }
    final selected = containers.firstWhereOrNull((e) => e.id == _containerId);
    _fill = selected?.fillRatio ?? 0.8;
  }

  @override
  void dispose() {
    _gramsCtrl.dispose();
    super.dispose();
  }

  PortionEstimate _estimateWith(
    FoodContainer? container,
    ReferenceObject? reference,
  ) {
    switch (_tier) {
      case PrecisionTier.quick:
        return PortionEstimator.fromOrdinal(
          food: _food,
          tier: PrecisionTier.quick,
          ordinal: _ordinal,
          leftover: _leftover,
          personalMedian: widget.personalMedian,
        );
      case PrecisionTier.standard:
        if (_containerMode) {
          if (container == null) {
            return PortionEstimator.fromOrdinal(
              food: _food,
              tier: PrecisionTier.standard,
              ordinal: _ordinal,
              leftover: _leftover,
              personalMedian: widget.personalMedian,
            );
          }
          return PortionEstimator.fromContainer(
            food: _food,
            container: container,
            fillRatio: _fill,
          );
        }
        if (reference == null) {
          return PortionEstimator.fromOrdinal(
            food: _food,
            tier: PrecisionTier.standard,
            ordinal: _ordinal,
            leftover: _leftover,
            personalMedian: widget.personalMedian,
          );
        }
        return PortionEstimator.fromReference(
          food: _food,
          reference: reference,
          count: _refCount,
        );
      case PrecisionTier.precise:
        final raw =
            double.tryParse(_gramsCtrl.text.replaceAll(',', '').trim()) ?? 0;
        final grams = raw * (1 - _leftover);
        return PortionEstimator.fromWeighed(_food, grams);
    }
  }

  void _useUnknown() {
    setState(() {
      _tier = PrecisionTier.quick;
      _ordinal = 2;
      _leftover = 0;
      _note = '先按中份记，区间放宽；之后随时能改。';
    });
  }

  void _confirm(PortionEstimate estimate) {
    if (estimate.gramsP50 <= 0.2) return;
    Navigator.of(context).pop(
      PortionChoice(
        gramsP10: estimate.gramsP10,
        gramsP50: estimate.gramsP50,
        gramsP90: estimate.gramsP90,
        method: estimate.method,
        confidence: estimate.confidence,
        explanation: estimate.explanation,
        tier: _tier,
        containerId: estimate.containerId,
        referenceObjectId: estimate.referenceObjectId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final data = ref.watch(dataProvider);
    final containers = data?.containers ?? const <FoodContainer>[];
    final references = data?.referenceObjects ?? const <ReferenceObject>[];
    final container =
        containers.firstWhereOrNull((e) => e.id == _containerId) ??
        containers.firstOrNull;
    final reference =
        references.firstWhereOrNull((e) => e.id == _referenceId) ??
        references.firstOrNull;
    final estimate = _estimateWith(container, reference);
    final kcal = _food.nutrientsPer100g['energy_kcal'] ?? 0;
    final kcalRange = (
      p10: kcal * estimate.gramsP10 / 100,
      p50: kcal * estimate.gramsP50 / 100,
      p90: kcal * estimate.gramsP90 / 100,
    );
    final canSave = estimate.gramsP50 > 0.2;
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.92;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(context),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SegmentedChoice<PrecisionTier>(
                    values: const [
                      PrecisionTier.quick,
                      PrecisionTier.standard,
                      PrecisionTier.precise,
                    ],
                    selected: _tier,
                    label: (tier) => switch (tier) {
                      PrecisionTier.quick => 'L1 快速',
                      PrecisionTier.standard => 'L2 标准',
                      PrecisionTier.precise => 'L3 精确',
                    },
                    onChanged: (tier) => setState(() {
                      _tier = tier;
                      _note = null;
                    }),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _tier.hint,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: t.surfaceAlt,
                          borderRadius: BorderRadius.circular(t.pillRadius),
                        ),
                        child: Text(
                          '误差预算 ±${(_tier.relativeSpread * 100).round()}%',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildEstimateCard(context, estimate, kcalRange),
                    const SizedBox(height: 16),
                    if (_tier == PrecisionTier.quick)
                      _buildQuick(context)
                    else if (_tier == PrecisionTier.standard)
                      _buildStandard(
                        context,
                        containers,
                        references,
                        container,
                        reference,
                      )
                    else
                      _buildPrecise(context),
                    if (_note != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 15,
                            color: t.inkTertiary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _note!,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                  ],
                ),
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
                    if (_tier == PrecisionTier.quick) ...[
                      TextButton(
                        onPressed: _useUnknown,
                        child: const Text('不知道'),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
                      child: FilledButton(
                        onPressed: canSave ? () => _confirm(estimate) : null,
                        child: Text(
                          canSave
                              ? '完成 · 约 ${estimate.gramsP50.round()} g'
                              : '先给个大概份量',
                        ),
                      ),
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

  Widget _buildHeader(BuildContext context) {
    final t = context.tokens;
    final defaultLabel = _food.defaultServingLabel;
    final defaultGrams = _food.defaultServingGrams;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 12, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _food.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    categoryLabel(_food.category),
                    if (defaultGrams != null)
                      '常见一份 ${defaultLabel ?? ''}${defaultLabel == null ? '' : ' · '}${defaultGrams.round()} g',
                    if (widget.personalMedian != null)
                      '你常吃 ${widget.personalMedian!.round()} g',
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: Icon(Icons.close_rounded, color: t.inkSecondary, size: 20),
            visualDensity: VisualDensity.compact,
            tooltip: '关闭',
          ),
        ],
      ),
    );
  }

  Widget _buildEstimateCard(
    BuildContext context,
    PortionEstimate estimate,
    NutrientRange kcalRange,
  ) {
    final t = context.tokens;
    final confidence = estimate.confidence;
    final gramsText = estimate.gramsP50 > 0
        ? '${estimate.gramsP10.round()}–${estimate.gramsP90.round()} g'
        : '—';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.surfaceAlt,
        borderRadius: BorderRadius.circular(t.radiusLg),
        border: Border.all(color: t.hairline, width: t.borderWidth),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('我猜', style: Theme.of(context).textTheme.labelSmall),
              const Spacer(),
              MethodChip(estimate.method),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            gramsText,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            estimate.gramsP50 > 0
                ? '中位 ≈ ${estimate.gramsP50.round()} g · ${formatKcalRange(kcalRange)}'
                : '还没有可用的份量',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (estimate.gramsP50 > 0) ...[
            const SizedBox(height: 10),
            RangeBar(
              range: (
                p10: estimate.gramsP10,
                p50: estimate.gramsP50,
                p90: estimate.gramsP90,
              ),
              color: t.inkSecondary,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  'p10 ${estimate.gramsP10.round()} g',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const Spacer(),
                Text(
                  'p50 ${estimate.gramsP50.round()} g',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const Spacer(),
                Text(
                  'p90 ${estimate.gramsP90.round()} g',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.circle,
                size: 7,
                color: confidenceColor(t, confidence),
              ),
              const SizedBox(width: 5),
              Text(
                '置信度 ${confidenceLabel(confidence)}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: confidenceColor(t, confidence),
                ),
              ),
              const Spacer(),
              Text('区间不是承诺', style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
          if (estimate.explanation.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              estimate.explanation,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  Widget _heading(BuildContext context, String text, {String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(text, style: Theme.of(context).textTheme.titleSmall),
          if (hint != null) ...[
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuick(BuildContext context) {
    final base =
        widget.personalMedian ??
        _food.defaultServingGrams ??
        _defaultGrams(_food.category);
    final labels = <String>['少', '中', '多'];
    final factors = <double>[0.6, 1.0, 1.5];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(context, '这次吃了多少？', hint: '不用称，选一个就行'),
        Row(
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(context.tokens.radiusMd),
                  onTap: () => setState(() {
                    _ordinal = i + 1;
                    _note = null;
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _ordinal == i + 1
                          ? context.tokens.accent.withValues(alpha: 0.08)
                          : context.tokens.surface,
                      borderRadius: BorderRadius.circular(
                        context.tokens.radiusMd,
                      ),
                      border: Border.all(
                        color: _ordinal == i + 1
                            ? context.tokens.accent
                            : context.tokens.hairline,
                        width: _ordinal == i + 1
                            ? 1.5
                            : context.tokens.borderWidth,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          labels[i],
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: _ordinal == i + 1
                                    ? context.tokens.ink
                                    : context.tokens.inkSecondary,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '≈ ${(base * factors[i] * (1 - _leftover)).round()} g',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 18),
        _heading(context, '剩了多少？', hint: '按整份的比例'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in const [
              (label: '没剩', value: 0.0),
              (label: '剩 ¼', value: 0.25),
              (label: '剩 ½', value: 0.5),
              (label: '剩 ¾', value: 0.75),
              (label: '全剩', value: 1.0),
            ])
              ChoicePill(
                label: option.label,
                selected: _leftover == option.value,
                onTap: () => setState(() {
                  _leftover = option.value;
                  _note = option.value >= 0.99 ? '全剩就相当于没吃；也可以改成剩 ¾。' : null;
                }),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          '默认来自${widget.personalMedian != null ? '你自己的历史中位数' : '这类食物的常见份量'}。'
          '3 次点击内完成，不追问克数。',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildStandard(
    BuildContext context,
    List<FoodContainer> containers,
    List<ReferenceObject> references,
    FoodContainer? container,
    ReferenceObject? reference,
  ) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedChoice<String>(
          values: const ['容器', '参照物'],
          selected: _containerMode ? '容器' : '参照物',
          label: (value) => value,
          onChanged: (value) => setState(() {
            _containerMode = value == '容器';
            _note = null;
          }),
          dense: true,
        ),
        const SizedBox(height: 14),
        if (_containerMode) ...[
          _heading(context, '用哪只容器？', hint: '一次标定，长期复用'),
          if (containers.isEmpty)
            Row(
              children: [
                Expanded(
                  child: Text(
                    '还没有标定过的容器。可以先用参照物，或去标一只常用碗。',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ContainerCalibrationPage(),
                    ),
                  ),
                  child: const Text('去标定'),
                ),
              ],
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in containers)
                  ChoicePill(
                    label: item.name,
                    hint:
                        '${item.capacityMl.round()} ml · 默认 ${(item.fillRatio * 100).round()}%',
                    icon: _shapeIcon(item.shape),
                    selected: item.id == container?.id,
                    onTap: () => setState(() {
                      _containerId = item.id;
                      _fill = item.fillRatio;
                      _note = null;
                    }),
                  ),
              ],
            ),
          if (container != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Text('盛到多满', style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                Text(
                  '${(_fill * 100).round()}% · ≈ ${(container.capacityMl * _fill * _foodDensity()).round()} g',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
            Slider(
              value: _fill.clamp(0.2, 1.0),
              min: 0.2,
              max: 1.0,
              divisions: 16,
              label: '${(_fill * 100).round()}%',
              onChanged: (value) => setState(() => _fill = value),
            ),
            Row(
              children: [
                Text('半份', style: Theme.of(context).textTheme.labelSmall),
                const Spacer(),
                Text('平碗', style: Theme.of(context).textTheme.labelSmall),
                const Spacer(),
                Text('冒尖', style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ],
        ] else ...[
          _heading(context, '用什么参照？', hint: '参照物给体积，不是重量'),
          if (references.isEmpty)
            Text('参照物数据未加载。', style: Theme.of(context).textTheme.bodySmall)
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in references)
                  ChoicePill(
                    label: item.name,
                    hint: item.hint,
                    icon: item.category == 'hand'
                        ? Icons.back_hand_outlined
                        : Icons.crop_square_rounded,
                    selected: item.id == reference?.id,
                    onTap: () => setState(() {
                      _referenceId = item.id;
                      _note = null;
                    }),
                  ),
              ],
            ),
          if (reference != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Text('几份', style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                Text(
                  '$_refCount × ${reference.name}',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
            Slider(
              value: _refCount.toDouble(),
              min: 1,
              max: 4,
              divisions: 3,
              label: '$_refCount 份',
              onChanged: (value) => setState(() => _refCount = value.round()),
            ),
            Text(reference.hint, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: t.surfaceAlt,
            borderRadius: BorderRadius.circular(t.radiusMd),
          ),
          child: Text(
            '容器和参照物都会随食物类别换算成克重；炒菜、汤、堆叠食物本身差异大，'
            '所以只给区间。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  double _foodDensity() {
    return PortionEstimator.densityForFood(_food);
  }

  Widget _buildPrecise(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(context, '有秤就称一下', hint: '去皮后读数，误差最小'),
        TextField(
          controller: _gramsCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            hintText: '例如 212',
            suffixText: 'g',
            labelText: '可食部克重',
          ),
          onChanged: (_) => setState(() => _note = null),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final grams in const [50, 80, 100, 150, 200, 300])
              ChoicePill(
                label: '$grams g',
                selected: _gramsCtrl.text.trim() == grams.toString(),
                onTap: () => setState(() {
                  _gramsCtrl.text = grams.toString();
                  _gramsCtrl.selection = TextSelection.collapsed(
                    offset: _gramsCtrl.text.length,
                  );
                  _note = null;
                }),
              ),
          ],
        ),
        const SizedBox(height: 18),
        _heading(context, '剩了多少？', hint: '称过整体也可按比例扣'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in const [
              (label: '没剩', value: 0.0),
              (label: '剩 ¼', value: 0.25),
              (label: '剩 ½', value: 0.5),
              (label: '剩 ¾', value: 0.75),
            ])
              ChoicePill(
                label: option.label,
                selected: _leftover == option.value,
                onTap: () => setState(() => _leftover = option.value),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          '称重也有边界：漏记和「记录期少吃」造成的整体低报，比克重误差更大。'
          '所以这一档也只回区间。',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: t.inkSecondary),
        ),
      ],
    );
  }

  IconData _shapeIcon(String shape) => switch (shape) {
    'bowl' => Icons.rice_bowl_outlined,
    'cup' => Icons.local_cafe_outlined,
    'box' => Icons.inbox_outlined,
    'plate' => Icons.circle_outlined,
    'spoon' => Icons.restaurant_outlined,
    _ => Icons.straighten_rounded,
  };

  double _defaultGrams(String category) => switch (category) {
    'staple' => 150,
    'vegetable' => 100,
    'fruit' => 150,
    'meat' => 80,
    'fish' => 80,
    'egg' => 50,
    'dairy' => 200,
    'bean' => 100,
    'nut' => 10,
    'soup' => 300,
    'dish' => 200,
    'drink' => 250,
    'condiment' => 10,
    _ => 100,
  };
}
