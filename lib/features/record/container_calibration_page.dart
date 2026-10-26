import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/container.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_widgets.dart';
import 'widgets/record_common.dart';

class ContainerCalibrationPage extends ConsumerWidget {
  const ContainerCalibrationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final data = ref.watch(dataProvider);
    final containers = data?.containers ?? const <FoodContainer>[];
    final builtin = containers.where((e) => e.builtin).toList();
    final mine = containers.where((e) => !e.builtin).toList();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            PageHeader(
              title: '容器标定',
              subtitle: '一次标定，复用几个月',
              showBack: true,
              actions: [
                IconButton(
                  tooltip: '新增容器',
                  onPressed: () => _openForm(context, ref),
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                children: [
                  const _CalibrationGuide(),
                  const SizedBox(height: 18),
                  SectionTitle(
                    '内置容器',
                    subtitle: '${builtin.length} 只，可直接用于 L2 份量',
                    trailing: Pill('只读', color: t.inkTertiary),
                  ),
                  if (builtin.isEmpty)
                    Text(
                      '内置容器数据未加载。',
                      style: Theme.of(context).textTheme.bodySmall,
                    )
                  else
                    for (final container in builtin)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _ContainerTile(container: container),
                      ),
                  const SizedBox(height: 18),
                  SectionTitle(
                    '我的容器',
                    subtitle: mine.isEmpty ? '还没有标定过' : '${mine.length} 只',
                    trailing: TextButton(
                      onPressed: () => _openForm(context, ref),
                      child: const Text('新增'),
                    ),
                  ),
                  if (mine.isEmpty)
                    AppCard(
                      padding: const EdgeInsets.all(14),
                      child: Text(
                        '下次盛饭前花 30 秒：空碗去皮 → 倒水到常用刻度 → 记下水量。'
                        '之后 L2 选这只碗，只调「盛到多满」。',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    )
                  else
                    for (final container in mine)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _ContainerTile(
                          container: container,
                          onTap: () =>
                              _openForm(context, ref, existing: container),
                        ),
                      ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: t.surfaceAlt,
                      borderRadius: BorderRadius.circular(t.radiusMd),
                    ),
                    child: Text(
                      '本版不做 AR/相机体积测量。容量只用来把「一碗」换算成克重，'
                      '仍会以区间输出；容器误差通常小于人对体积的目测误差。',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openForm(
    BuildContext context,
    WidgetRef ref, {
    FoodContainer? existing,
  }) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ContainerFormSheet(existing: existing),
    );
    if (saved == true && context.mounted) {
      showToast(context, existing == null ? '容器已保存 ✓' : '容器已更新 ✓');
    }
  }
}

class _CalibrationGuide extends StatelessWidget {
  const _CalibrationGuide();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    const steps = [
      (title: '空容器去皮', body: '有秤就称一下空碗，记 tare；没秤就填 0，不影响容量换算。'),
      (title: '加水到常用刻度', body: '倒到你平时盛饭/盛汤的那条线，不是齐边；弯月面按略低算。'),
      (title: '记下水量', body: '用 500 ml 矿泉水最省事：倒了两瓶就是 1000 ml。有量杯直接读数。'),
      (title: '保存后复用', body: '以后只选这只碗 + 调「盛到多满」；换碗了再标一次。'),
    ];
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timer_outlined, size: 16, color: t.inkSecondary),
              const SizedBox(width: 6),
              Text('30 秒标定', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              Pill('可跳过', color: t.inkTertiary),
            ],
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: t.surfaceAlt,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: t.hairline,
                        width: t.borderWidth,
                      ),
                    ),
                    child: Text(
                      '${i + 1}',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          steps[i].title,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(
                          steps[i].body,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ContainerTile extends StatelessWidget {
  final FoodContainer container;
  final VoidCallback? onTap;

  const _ContainerTile({required this.container, this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final defaultGrams = container.estimateGrams();
    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: t.surfaceAlt,
              borderRadius: BorderRadius.circular(t.radiusMd),
            ),
            child: Icon(
              _shapeIcon(container.shape),
              size: 20,
              color: t.inkSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        container.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    if (container.builtin) ...[
                      const SizedBox(width: 6),
                      Pill('内置', color: t.inkTertiary),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '容量 ${container.capacityMl.round()} ml · '
                  '去皮 ${container.tareG.round()} g · '
                  '默认装满 ${(container.fillRatio * 100).round()}% · '
                  '一份约 ${defaultGrams.round()} g',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (onTap != null)
            Icon(Icons.edit_outlined, size: 18, color: t.inkTertiary),
        ],
      ),
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
}

class _ContainerFormSheet extends ConsumerStatefulWidget {
  final FoodContainer? existing;

  const _ContainerFormSheet({this.existing});

  @override
  ConsumerState<_ContainerFormSheet> createState() =>
      _ContainerFormSheetState();
}

class _ContainerFormSheetState extends ConsumerState<_ContainerFormSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _capacityCtrl;
  late final TextEditingController _tareCtrl;
  late String _shape;
  late double _fill;
  bool _saving = false;
  String? _error;

  static const _shapes = <(String, String)>[
    ('bowl', '碗'),
    ('cup', '杯'),
    ('box', '盒'),
    ('plate', '盘'),
    ('spoon', '勺'),
  ];

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameCtrl = TextEditingController(text: existing?.name ?? '');
    _capacityCtrl = TextEditingController(
      text: existing == null ? '' : existing.capacityMl.round().toString(),
    );
    _tareCtrl = TextEditingController(
      text: existing == null || existing.tareG == 0
          ? ''
          : existing.tareG.round().toString(),
    );
    _shape = existing?.shape ?? 'bowl';
    _fill = existing?.fillRatio ?? 0.8;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _capacityCtrl.dispose();
    _tareCtrl.dispose();
    super.dispose();
  }

  double get _capacity => double.tryParse(_capacityCtrl.text.trim()) ?? 0;

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = '给这只容器起个名字，例如「我的饭碗」。');
      return;
    }
    if (_capacity <= 0) {
      setState(() => _error = '容量要大于 0 ml。可以用矿泉水瓶计数后填写。');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final repo = ref.read(repositoryProvider);
    final container = FoodContainer(
      id: widget.existing?.id ?? repo.newId(),
      name: name,
      capacityMl: _capacity,
      tareG: double.tryParse(_tareCtrl.text.trim()) ?? 0,
      fillRatio: _fill,
      shape: _shape,
      densityHint: widget.existing?.densityHint ?? 0.8,
      builtin: false,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await ref.read(appStateProvider.notifier).saveContainer(container);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final estimate = _capacity * _fill * 0.8;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.existing == null ? '新增容器' : '编辑容器',
                      style: Theme.of(context).textTheme.titleLarge,
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
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _nameCtrl,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: '名称',
                        hintText: '例如：我的饭碗 / 外卖汤盒',
                      ),
                      onChanged: (_) => setState(() => _error = null),
                    ),
                    const SizedBox(height: 12),
                    Text('形状', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 6),
                    SegmentedChoice<String>(
                      values: [for (final shape in _shapes) shape.$1],
                      selected: _shape,
                      label: (shape) =>
                          _shapes.firstWhere((item) => item.$1 == shape).$2,
                      onChanged: (shape) => setState(() => _shape = shape),
                      dense: true,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _capacityCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: '容量',
                              suffixText: 'ml',
                              hintText: '例如 250',
                            ),
                            onChanged: (_) => setState(() => _error = null),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _tareCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: '去皮',
                              suffixText: 'g',
                              hintText: '没秤填 0',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final ml in const [150, 250, 350, 500, 750, 1000])
                          ChoicePill(
                            label: '$ml ml',
                            selected:
                                _capacityCtrl.text.trim() == ml.toString(),
                            onTap: () => setState(() {
                              _capacityCtrl.text = ml.toString();
                              _error = null;
                            }),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text(
                          '默认装满',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const Spacer(),
                        Text(
                          '${(_fill * 100).round()}% · 约 ${estimate.round()} g',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ],
                    ),
                    Slider(
                      value: _fill.clamp(0.4, 1.0),
                      min: 0.4,
                      max: 1.0,
                      divisions: 12,
                      label: '${(_fill * 100).round()}%',
                      onChanged: (value) => setState(() => _fill = value),
                    ),
                    Row(
                      children: [
                        Text(
                          '半碗',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        const Spacer(),
                        Text(
                          '平碗',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        const Spacer(),
                        Text(
                          '冒尖',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '「装满比例」是你的常用刻度，不是容器的物理上限；'
                      '之后仍可按这一餐再调。',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: t.high.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(t.radiusMd),
                          border: Border.all(
                            color: t.high.withValues(alpha: 0.35),
                            width: t.borderWidth,
                          ),
                        ),
                        child: Text(
                          _error!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
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
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('保存容器'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
