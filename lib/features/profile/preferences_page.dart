import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/enums.dart';
import '../../core/models/preference.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_widgets.dart';
import '../settings/widgets/settings_widgets.dart';

class PreferencesPage extends ConsumerStatefulWidget {
  const PreferencesPage({super.key});

  @override
  ConsumerState<PreferencesPage> createState() => _PreferencesPageState();
}

class _PreferencesPageState extends ConsumerState<PreferencesPage> {
  final _searchController = TextEditingController();
  PreferenceEntityType? _filter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final data = ref.watch(dataProvider);
    final all = data?.activePreferences ?? const <Preference>[];
    final query = _searchController.text.trim().toLowerCase();
    final filtered = all.where((preference) {
      if (_filter != null && preference.entityType != _filter) return false;
      if (query.isEmpty) return true;
      final haystack = '${preference.label} ${preference.tags.join(' ')}'.toLowerCase();
      return haystack.contains(query);
    }).toList();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            PageHeader(
              title: '食物偏好',
              subtitle: '偏好影响计划；过敏是安全硬约束',
              showBack: true,
              actions: [
                IconButton(
                  tooltip: '添加偏好',
                  onPressed: _openAdd,
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 28),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _searchController,
                          onChanged: (_) => setState(() {}),
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            hintText: '搜索食物、菜品或标签',
                            prefixIcon: const Icon(Icons.search_rounded, size: 20),
                            suffixIcon: _searchController.text.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: '清空搜索',
                                    icon: const Icon(Icons.close_rounded, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {});
                                    },
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _filterChip(
                                label: '全部',
                                count: all.length,
                                selected: _filter == null,
                                onTap: () => setState(() => _filter = null),
                              ),
                              for (final type in PreferenceEntityType.values) ...[
                                const SizedBox(width: 8),
                                _filterChip(
                                  label: type.label,
                                  count: all.where((e) => e.entityType == type).length,
                                  selected: _filter == type,
                                  onTap: () => setState(() => _filter = type),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        const InfoNote(
                          icon: Icons.auto_awesome_outlined,
                          title: '星级怎么来的',
                          text: '一次提及只记 3 星；重复出现才升级；你可以手动改。'
                              '「过敏」是安全硬约束，计划和替换会直接排除；「不吃」只是不再推荐。',
                        ),
                        const SizedBox(height: 16),
                        if (all.isEmpty)
                          SizedBox(
                            height: 330,
                            child: EmptyState(
                              icon: Icons.restaurant_menu_rounded,
                              title: '还没有偏好',
                              body: '比如「辣」「香菜」「奶茶」「油炸」。\n'
                                  '记下喜欢的和不喜欢的，计划会更像你。',
                              action: FilledButton(
                                onPressed: _openAdd,
                                child: const Text('添加第一条'),
                              ),
                            ),
                          )
                        else if (filtered.isEmpty)
                          SizedBox(
                            height: 260,
                            child: EmptyState(
                              icon: Icons.search_off_rounded,
                              title: '没有匹配的偏好',
                              body: '换个关键词，或把筛选切回「全部」。',
                              action: TextButton(
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _filter = null);
                                },
                                child: const Text('清空筛选'),
                              ),
                            ),
                          )
                        else ...[
                          Text(
                            '${filtered.length} 条 · 点任意一项可编辑',
                            style: textTheme.bodySmall?.copyWith(color: t.inkTertiary),
                          ),
                          const SizedBox(height: 10),
                          for (final preference in filtered)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _preferenceRow(preference),
                            ),
                        ],
                      ],
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

  Widget _filterChip({
    required String label,
    required int count,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final t = context.tokens;
    return ChoiceChip(
      label: Text('$label $count'),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onTap(),
      selectedColor: t.accent,
      backgroundColor: t.surface,
      side: BorderSide(
        color: selected ? t.accent : t.hairline,
        width: t.borderWidth,
      ),
      labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: selected ? t.accentInk : t.ink,
          ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(t.isQ ? t.pillRadius : t.radiusSm),
      ),
    );
  }

  Widget _preferenceRow(Preference preference) {
    final t = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    return PressableScale(
      onTap: () => _openEdit(preference),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          preference.label,
                          style: textTheme.titleSmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (preference.allergy) ...[
                        const SizedBox(width: 6),
                        Pill('过敏', color: t.veryHigh, filled: true),
                      ],
                      if (preference.avoid) ...[
                        const SizedBox(width: 6),
                        Pill('不吃', color: t.high, filled: true),
                      ],
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      _Stars(value: preference.stars),
                      const SizedBox(width: 5),
                      Text(
                        '${preference.stars} 星 · ${preference.entityType.label}',
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${_sourceLabel(preference.source)} · 证据 ${preference.evidenceCount} 次',
                    style: textTheme.bodySmall?.copyWith(color: t.inkTertiary),
                  ),
                  if (preference.tags.isNotEmpty) ...[
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final tag in preference.tags)
                          Pill(tag, color: t.inkSecondary, filled: true),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: '更多操作',
              icon: Icon(Icons.more_vert_rounded, size: 20, color: t.inkTertiary),
              onSelected: (value) {
                if (value == 'edit') {
                  _openEdit(preference);
                } else if (value == 'delete') {
                  _confirmDelete(preference);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('编辑')),
                PopupMenuItem(
                  value: 'delete',
                  child: Text('删除', style: TextStyle(color: t.veryHigh)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAdd() async {
    if (ref.read(profileProvider) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先填写健康档案，再添加偏好。')),
      );
      return;
    }
    await _openSheet();
  }

  Future<void> _openEdit(Preference preference) => _openSheet(existing: preference);

  Future<void> _openSheet({Preference? existing}) async {
    final draft = await showModalBottomSheet<_PreferenceDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _PreferenceSheet(existing: existing),
    );
    if (draft == null || !mounted) return;
    try {
      final notifier = ref.read(appStateProvider.notifier);
      if (existing == null) {
        await notifier.upsertPreference(
          label: draft.label,
          type: draft.type,
          stars: draft.stars,
          avoid: draft.avoid,
          allergy: draft.allergy,
          tags: draft.tags,
        );
      } else {
        await notifier.savePreference(
          Preference(
            id: existing.id,
            profileId: existing.profileId,
            entityType: draft.type,
            entityId: draft.label,
            label: draft.label,
            stars: draft.stars,
            avoid: draft.avoid,
            allergy: draft.allergy,
            tags: draft.tags,
            evidenceCount: existing.evidenceCount,
            source: existing.source,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(existing == null ? '已添加偏好' : '已更新偏好')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败：$error')),
      );
    }
  }

  Future<void> _confirmDelete(Preference preference) async {
    final t = context.tokens;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除这条偏好？'),
        content: Text('「${preference.label}」会从计划和替换建议中移除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: t.veryHigh,
              foregroundColor: t.surface,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(appStateProvider.notifier).deletePreference(preference.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已删除')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('删除失败：$error')),
      );
    }
  }

  static String _sourceLabel(String source) {
    return switch (source) {
      'explicit' => '手动添加',
      'ai' => 'AI 抽取',
      'behavior' => '行为推断',
      'implicit' => '对话推断',
      _ => source,
    };
  }
}

class _Stars extends StatelessWidget {
  final int value;
  const _Stars({required this.value});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 5; i++)
          Icon(
            i < value ? Icons.star_rounded : Icons.star_outline_rounded,
            size: 15,
            color: i < value ? t.high : t.inkTertiary,
          ),
      ],
    );
  }
}

class _PreferenceDraft {
  final PreferenceEntityType type;
  final String label;
  final int stars;
  final bool avoid;
  final bool allergy;
  final List<String> tags;

  const _PreferenceDraft({
    required this.type,
    required this.label,
    required this.stars,
    required this.avoid,
    required this.allergy,
    required this.tags,
  });
}

class _PreferenceSheet extends StatefulWidget {
  final Preference? existing;

  const _PreferenceSheet({this.existing});

  @override
  State<_PreferenceSheet> createState() => _PreferenceSheetState();
}

class _PreferenceSheetState extends State<_PreferenceSheet> {
  late final TextEditingController _labelController;
  late final TextEditingController _tagsController;
  late PreferenceEntityType _type;
  late int _stars;
  late bool _avoid;
  late bool _allergy;
  String? _error;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _labelController = TextEditingController(text: existing?.label ?? '');
    _tagsController = TextEditingController(text: existing?.tags.join('、') ?? '');
    _type = existing?.entityType ?? PreferenceEntityType.food;
    _stars = existing?.stars ?? 3;
    _avoid = existing?.avoid ?? false;
    _allergy = existing?.allergy ?? false;
  }

  @override
  void dispose() {
    _labelController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  List<String> _parseTags() {
    return _tagsController.text
        .split(RegExp(r'[,，、;；\s]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
  }

  void _submit() {
    final label = _labelController.text.trim();
    if (label.isEmpty) {
      setState(() => _error = '先写一个名称，比如「香菜」。');
      return;
    }
    Navigator.of(context).pop(
      _PreferenceDraft(
        type: _type,
        label: label,
        stars: _stars,
        avoid: _avoid,
        allergy: _allergy,
        tags: _parseTags(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.existing == null ? '新增偏好' : '编辑偏好',
                      style: textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('类型', style: textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final type in PreferenceEntityType.values)
                    ChoiceChip(
                      label: Text(type.label),
                      selected: _type == type,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _type = type),
                      selectedColor: t.accent,
                      backgroundColor: t.surface,
                      side: BorderSide(
                        color: _type == type ? t.accent : t.hairline,
                        width: t.borderWidth,
                      ),
                      labelStyle: textTheme.labelMedium?.copyWith(
                        color: _type == type ? t.accentInk : t.ink,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          t.isQ ? t.pillRadius : t.radiusSm,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _labelController,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: '名称',
                  hintText: _type == PreferenceEntityType.trait ? '如：辣、油炸' : '如：香菜、奶茶',
                  errorText: _error,
                ),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
              ),
              const SizedBox(height: 16),
              Text('喜欢程度', style: textTheme.titleSmall),
              const SizedBox(height: 6),
              Row(
                children: [
                  for (var i = 1; i <= 5; i++)
                    IconButton(
                      tooltip: '$i 星',
                      onPressed: () => setState(() => _stars = i),
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        i <= _stars ? Icons.star_rounded : Icons.star_outline_rounded,
                        size: 26,
                        color: i <= _stars ? t.high : t.inkTertiary,
                      ),
                    ),
                  const SizedBox(width: 4),
                  Text('$_stars 星', style: textTheme.bodySmall),
                ],
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('不吃（avoid）', style: textTheme.titleSmall),
                subtitle: Text('不再推荐，但不等同于过敏', style: textTheme.bodySmall),
                value: _avoid,
                onChanged: (value) => setState(() => _avoid = value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('过敏（allergy）', style: textTheme.titleSmall),
                subtitle: Text('安全硬约束：计划与替换直接排除', style: textTheme.bodySmall),
                value: _allergy,
                onChanged: (value) => setState(() => _allergy = value),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _tagsController,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: '标签（可选）',
                  hintText: '逗号分隔，如：重口、外卖、夜宵',
                ),
              ),
              const SizedBox(height: 14),
              const InfoNote(
                icon: Icons.auto_awesome_outlined,
                text: '新增默认 3 星。一次提及只记 3 星；重复出现才升级；你可以随时手动改。',
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _submit,
                child: Text(widget.existing == null ? '添加' : '保存修改'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
