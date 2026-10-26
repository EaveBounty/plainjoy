import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/health/condition_policy.dart';
import '../../core/health/health_rules.dart';
import '../../core/models/nutrients.dart';

import '../../core/models/enums.dart';
import '../../core/models/profile.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_widgets.dart';
import '../settings/widgets/settings_widgets.dart';

class HealthProfilePage extends ConsumerStatefulWidget {
  const HealthProfilePage({super.key});

  @override
  ConsumerState<HealthProfilePage> createState() => _HealthProfilePageState();
}

class _HealthProfilePageState extends ConsumerState<HealthProfilePage> {
  static const _dietOptions = <String, String>{
    'omnivore': '杂食',
    'vegetarian': '蛋奶素',
    'vegan': '纯素',
    'pescatarian': '鱼素',
  };

  static const _equipmentOptions = <String, String>{
    'induction': '电磁炉',
    'riceCooker': '电饭煲',
    'microwave': '微波炉',
    'oven': '烤箱',
    'airFryer': '空气炸锅',
    'none': '不做饭',
  };

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nickname;
  late final TextEditingController _birthYear;
  late final TextEditingController _height;
  late final TextEditingController _weight;
  late final TextEditingController _allergies;

  late Sex _sex;
  late ActivityLevel _activity;
  late Goal _goal;
  late String _dietaryPattern;
  late Set<Condition> _conditions;
  late Set<String> _equipment;
  late bool _pregnant;
  late bool _lactating;
  late bool _ckdDialysis;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(profileProvider) ?? _fallbackProfile();
    _nickname = TextEditingController(text: profile.nickname);
    _birthYear = TextEditingController(text: profile.birthYear?.toString() ?? '');
    _height = TextEditingController(text: _formatNumber(profile.heightCm));
    _weight = TextEditingController(text: _formatNumber(profile.weightKg));
    _allergies = TextEditingController(text: profile.allergies.join('、'));
    _sex = profile.sex;
    _activity = profile.activity;
    _goal = profile.goal;
    _dietaryPattern =
        _dietOptions.containsKey(profile.dietaryPattern) ? profile.dietaryPattern : 'omnivore';
    _conditions = {...profile.conditions}
      ..remove(Condition.pregnancy)
      ..remove(Condition.lactating);
    _equipment = {...profile.equipment};
    _pregnant = profile.pregnant || profile.conditions.contains(Condition.pregnancy);
    _lactating = !_pregnant &&
        (profile.lactating || profile.conditions.contains(Condition.lactating));
    _ckdDialysis = profile.ckdDialysis;
  }

  @override
  void dispose() {
    _nickname.dispose();
    _birthYear.dispose();
    _height.dispose();
    _weight.dispose();
    _allergies.dispose();
    super.dispose();
  }

  static HealthProfile _fallbackProfile() => const HealthProfile(
        id: 'default',
        nickname: '我',
        sex: Sex.preferNot,
        activity: ActivityLevel.light,
        goal: Goal.maintain,
      );

  static String _formatNumber(double? value) {
    if (value == null) return '';
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(1);
  }

  static Set<String> _parseList(String raw) {
    return raw
        .split(RegExp(r'[,，、;；\s]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
  }

  Set<Condition> _effectiveConditions() {
    final conditions = {..._conditions};
    if (_dietaryPattern == 'vegetarian' || _dietaryPattern == 'vegan') {
      conditions.add(Condition.vegetarian);
    }
    return conditions;
  }

  HealthProfile _buildProfile() {
    final base = ref.read(profileProvider) ?? _fallbackProfile();
    final nickname = _nickname.text.trim();
    return HealthProfile(
      id: base.id,
      nickname: nickname.isEmpty ? '我' : nickname,
      birthYear: int.tryParse(_birthYear.text.trim()),
      sex: _sex,
      heightCm: double.tryParse(_height.text.trim()),
      weightKg: double.tryParse(_weight.text.trim()),
      activity: _activity,
      goal: _goal,
      conditions: _effectiveConditions(),
      allergies: _parseList(_allergies.text),
      pregnant: _pregnant,
      lactating: _lactating,
      ckdDialysis: _ckdDialysis,
      dietaryPattern: _dietaryPattern,
      targetKcalOverride: base.targetKcalOverride,
      targetProteinOverride: base.targetProteinOverride,
      targetSodiumOverride: base.targetSodiumOverride,
      dayStartHour: base.dayStartHour,
      equipment: _equipment,
      updatedAt: base.updatedAt,
    );
  }

  bool _conditionSelected(Condition condition) {
    if (condition == Condition.vegetarian &&
        (_dietaryPattern == 'vegetarian' || _dietaryPattern == 'vegan')) {
      return true;
    }
    if (condition == Condition.pregnancy) return _pregnant || _conditions.contains(condition);
    if (condition == Condition.lactating) return _lactating || _conditions.contains(condition);
    return _conditions.contains(condition);
  }

  void _setPregnant(bool value) {
    setState(() {
      _pregnant = value;
      if (value) {
        _lactating = false;
        _conditions.remove(Condition.lactating);
      }
    });
  }

  void _setLactating(bool value) {
    setState(() {
      _lactating = value;
      if (value) {
        _pregnant = false;
        _conditions.remove(Condition.pregnancy);
      }
    });
  }

  void _toggleCondition(Condition condition) {
    if (condition == Condition.vegetarian &&
        (_dietaryPattern == 'vegetarian' || _dietaryPattern == 'vegan')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('「素食」由饮食模式自动带出；如需关闭，请先改饮食模式。')),
      );
      return;
    }
    if (condition == Condition.pregnancy) {
      _setPregnant(!_pregnant);
      return;
    }
    if (condition == Condition.lactating) {
      _setLactating(!_lactating);
      return;
    }
    setState(() {
      if (!_conditions.add(condition)) {
        _conditions.remove(condition);
      }
    });
  }

  void _toggleEquipment(String key) {
    setState(() {
      if (key == 'none') {
        _equipment = {'none'};
        return;
      }
      _equipment.remove('none');
      if (!_equipment.add(key)) {
        _equipment.remove(key);
      }
    });
  }

  String? _validateBirthYear(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return null;
    final year = int.tryParse(raw);
    final now = DateTime.now().year;
    if (year == null || year < 1900 || year > now) {
      return '请填 1900–$now 之间的年份';
    }
    return null;
  }

  String? _validateHeight(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return null;
    final number = double.tryParse(raw);
    if (number == null || number < 80 || number > 250) return '请填 80–250 cm';
    return null;
  }

  String? _validateWeight(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return null;
    final number = double.tryParse(raw);
    if (number == null || number < 20 || number > 300) return '请填 20–300 kg';
    return null;
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await ref.read(appStateProvider.notifier).saveProfile(_buildProfile());
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败：$error')),
      );
    }
  }

  List<HealthRule> _dedupe(List<HealthRule> rules) {
    final seen = <String>{};
    return rules
        .where((rule) => seen.add('${rule.condition.name}|${rule.title}'))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final profile = _buildProfile();
    final rules = _dedupe(HealthRules.forProfile(profile));
    final reduceMotion = ref.watch(settingsProvider).reduceMotion;
    final grouped = <HealthRuleCategory, List<HealthRule>>{
      for (final category in HealthRuleCategory.values) category: <HealthRule>[],
    };
    for (final rule in rules) {
      grouped[rule.category]!.add(rule);
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              const PageHeader(
                title: '健康档案',
                subtitle: '用于饮食提示与营养目标，可随时修改',
                showBack: true,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const InfoNote(
                      icon: Icons.medical_information_outlined,
                      title: '先说明',
                      text: '这里只生成饮食提示，不做诊断，也不计算疾病风险百分比；'
                          '「需就医」是就医提示，不是诊断结论。填写越完整，计划与提示越贴合；不确定的项目可以留空。',
                    ),
                    if (profile.conditions.isNotEmpty || profile.pregnant || profile.lactating) ...[
                      const SizedBox(height: 16),
                      _PersonalTargetsCard(profile: profile),
                    ],
                    const SizedBox(height: 20),
                    const SectionTitle('基本信息'),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _nickname,
                            textInputAction: TextInputAction.next,
                            maxLength: 20,
                            decoration: const InputDecoration(
                              labelText: '昵称',
                              hintText: '怎么称呼你',
                              counterText: '',
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _birthYear,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: '出生年（可选）',
                              hintText: '如 1998',
                            ),
                            validator: _validateBirthYear,
                          ),
                          const SizedBox(height: 16),
                          _fieldLabel(context, '性别'),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final sex in Sex.values)
                                _choiceChip(
                                  label: sex.label,
                                  selected: _sex == sex,
                                  onTap: () => setState(() => _sex = sex),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _height,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    labelText: '身高 cm（可选）',
                                    hintText: '165',
                                  ),
                                  validator: _validateHeight,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _weight,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  textInputAction: TextInputAction.done,
                                  decoration: const InputDecoration(
                                    labelText: '体重 kg（可选）',
                                    hintText: '55',
                                  ),
                                  validator: _validateWeight,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const SectionTitle('活动与目标'),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _fieldLabel(context, '活动量'),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final activity in ActivityLevel.values)
                                _choiceChip(
                                  label: activity.label,
                                  selected: _activity == activity,
                                  onTap: () => setState(() => _activity = activity),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _fieldLabel(context, '目标'),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final goal in Goal.values)
                                _choiceChip(
                                  label: goal.label,
                                  selected: _goal == goal,
                                  onTap: () => setState(() => _goal = goal),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const SectionTitle('饮食模式与特殊阶段'),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _fieldLabel(context, '饮食模式'),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final entry in _dietOptions.entries)
                                _choiceChip(
                                  label: entry.value,
                                  selected: _dietaryPattern == entry.key,
                                  onTap: () => setState(() => _dietaryPattern = entry.key),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '素食 / 纯素会自动带出 B12、铁、锌等提示。',
                            style: textTheme.bodySmall,
                          ),
                          const SizedBox(height: 8),
                          Material(
                            type: MaterialType.transparency,
                            child: SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text('孕期', style: textTheme.titleSmall),
                              subtitle: Text(
                                '带出孕期饮食提示；具体方案以产检医生为准',
                                style: textTheme.bodySmall,
                              ),
                              value: _pregnant,
                              onChanged: _setPregnant,
                            ),
                          ),
                          Material(
                            type: MaterialType.transparency,
                            child: SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text('哺乳期', style: textTheme.titleSmall),
                              subtitle: Text(
                                '关注能量、蛋白质、钙与水分',
                                style: textTheme.bodySmall,
                              ),
                              value: _lactating,
                              onChanged: _setLactating,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _allergies,
                            minLines: 1,
                            maxLines: 2,
                            textInputAction: TextInputAction.done,
                            decoration: const InputDecoration(
                              labelText: '过敏（逗号分隔）',
                              hintText: '如：花生、虾、牛奶',
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '过敏是安全硬约束：计划和替换会直接排除。',
                            style: textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const SectionTitle('设备'),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final entry in _equipmentOptions.entries)
                                _choiceChip(
                                  label: entry.value,
                                  selected: _equipment.contains(entry.key),
                                  onTap: () => _toggleEquipment(entry.key),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '用于筛选可行的补丁餐；「不做饭」会优先即食、外卖与简单组合。',
                            style: textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const SectionTitle(
                      '健康状况',
                      subtitle: '只用于饮食提示，不代表诊断',
                    ),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final condition in Condition.values)
                                _choiceChip(
                                  label: condition.label,
                                  selected: _conditionSelected(condition),
                                  onTap: () => _toggleCondition(condition),
                                ),
                            ],
                          ),
                          if (_conditions.contains(Condition.ckd)) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '已进入透析（血透/腹透）',
                                    style: textTheme.bodyMedium,
                                  ),
                                ),
                                Switch(
                                  value: _ckdDialysis,
                                  onChanged: (v) => setState(() => _ckdDialysis = v),
                                ),
                              ],
                            ),
                            Text(
                              _ckdDialysis
                                  ? '蛋白目标按 1.1 g/kg 计；透析日、残余肾功能不同，请让肾内科确认。'
                                  : '未透析按 0.8 g/kg 计；若已透析请打开上面的开关，否则蛋白会被低估。',
                              style: textTheme.bodySmall,
                            ),
                          ],
                          const SizedBox(height: 8),
                          Text(
                            '不确定的项目可以不选。慢性肾病、孕期、用药期间的营养目标请以医生或注册营养师为准。',
                            style: textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    SectionTitle(
                      '饮食提示',
                      subtitle: rules.isEmpty ? '尚未触发规则' : '共 ${rules.length} 条，点击展开依据',
                    ),
                    if (rules.isEmpty)
                      AppCard(
                        child: Text(
                          '还没有需要特别提示的健康状况。填写后，这里会按「避免 / 限制 / 推荐 / 需就医」四类显示提示；'
                          '没有提示也不等于没有健康风险。',
                          style: textTheme.bodySmall,
                        ),
                      )
                    else
                      for (final category in HealthRuleCategory.values)
                        if (grouped[category]!.isNotEmpty) ...[
                          _CategoryHeader(
                            category: category,
                            count: grouped[category]!.length,
                            color: _categoryColor(category, t),
                          ),
                          for (final rule in grouped[category]!)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _RuleCard(
                                rule: rule,
                                color: _categoryColor(category, t),
                                reduceMotion: reduceMotion,
                              ),
                            ),
                          const SizedBox(height: 8),
                        ],
                    const SizedBox(height: 8),
                    const InfoNote(
                      icon: Icons.local_hospital_outlined,
                      title: '「需就医」不是诊断',
                      text: '它只表示这类情况更适合由医生或注册营养师评估。'
                          '若出现胸痛、气促、意识改变、持续呕吐等急症，请立即就医。',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
          decoration: BoxDecoration(
            color: t.background,
            border: Border(top: BorderSide(color: t.hairline, width: t.borderWidth)),
          ),
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: t.accentInk,
                    ),
                  )
                : const Text('保存档案'),
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    );
  }

  Widget _choiceChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final t = context.tokens;
    return ChoiceChip(
      label: Text(label),
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

  static Color _categoryColor(HealthRuleCategory category, AppTokens t) {
    return switch (category) {
      HealthRuleCategory.avoid => t.veryHigh,
      HealthRuleCategory.limit => t.high,
      HealthRuleCategory.recommend => t.good,
      HealthRuleCategory.seeDoctor => t.low,
    };
  }
}

class _CategoryHeader extends StatelessWidget {
  final HealthRuleCategory category;
  final int count;
  final Color color;

  const _CategoryHeader({
    required this.category,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final description = switch (category) {
      HealthRuleCategory.avoid => '尽量避开',
      HealthRuleCategory.limit => '控制频率与份量',
      HealthRuleCategory.recommend => '优先安排',
      HealthRuleCategory.seeDoctor => '建议咨询医生',
    };
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(
            category.label,
            style: textTheme.titleSmall?.copyWith(color: color),
          ),
          const SizedBox(width: 6),
          Text('$count', style: textTheme.labelSmall),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              description,
              style: textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _RuleCard extends StatefulWidget {
  final HealthRule rule;
  final Color color;
  final bool reduceMotion;

  const _RuleCard({
    required this.rule,
    required this.color,
    required this.reduceMotion,
  });

  @override
  State<_RuleCard> createState() => _RuleCardState();
}

class _RuleCardState extends State<_RuleCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final duration = MediaQuery.of(context).disableAnimations || widget.reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 180);
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(t.radiusMd),
        border: Border.all(color: t.hairline, width: t.borderWidth),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(t.radiusMd),
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: widget.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.rule.title, style: textTheme.titleSmall),
                        const SizedBox(height: 2),
                        Text(
                          widget.rule.condition.label,
                          style: textTheme.labelSmall?.copyWith(color: widget.color),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: duration,
                    child: Icon(
                      Icons.expand_more_rounded,
                      size: 18,
                      color: t.inkTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(27, 0, 12, 12),
              child: Text(widget.rule.detail, style: textTheme.bodySmall),
            ),
            crossFadeState: _open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: duration,
          ),
        ],
      ),
    );
  }
}


class _PersonalTargetsCard extends StatelessWidget {
  const _PersonalTargetsCard({required this.profile});

  final HealthProfile profile;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final policies = ConditionPolicies.forProfile(profile);
    final goals = ConditionPolicies.mergeGoals(policies);
    if (goals.isEmpty) return const SizedBox.shrink();

    final order = [
      NutrientCode.sodium,
      NutrientCode.protein,
      NutrientCode.potassium,
      NutrientCode.phosphorus,
      NutrientCode.iodine,
      NutrientCode.folate,
      NutrientCode.iron,
      NutrientCode.calcium,
    ];
    final rows = <Widget>[];
    for (final code in order) {
      final goal = goals[code];
      if (goal == null) continue;
      final meta = nutrientMeta[code];
      final unit = meta?.unit ?? '';
      final value = _range(goal, unit);
      rows.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 64,
              child: Text(
                meta?.label ?? code,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
            SizedBox(
              width: 104,
              child: Text(
                value,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            Expanded(
              child: Text(
                goal.reason,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(height: 1.5),
              ),
            ),
          ],
        ),
      ));
    }
    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(t.radiusLg),
        border: Border.all(color: t.hairline, width: t.borderWidth),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune_rounded, size: 16, color: t.ink),
              const SizedBox(width: 6),
              Text('你的目标', style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              Text(
                '${policies.length} 项病况已纳入',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final row in rows) ...[
            row,
            if (row != rows.last) Hairline(),
          ],
          const SizedBox(height: 6),
          Text(
            '饮食目标，不是处方。肾病、孕期、痛风急性期请让医生确认；评分会按这些目标重新加权。',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: t.inkTertiary),
          ),
        ],
      ),
    );
  }

  String _range(NutrientGoal goal, String unit) {
    final min = goal.min;
    final max = goal.max;
    if (min != null && min > 0 && max != null) {
      return '${min.round()}–${max.round()} $unit';
    }
    if (max != null) return '≤ ${max.round()} $unit';
    if (min != null) return '≥ ${min.round()} $unit';
    return '—';
  }
}
