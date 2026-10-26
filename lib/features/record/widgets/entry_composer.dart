import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/ai/ai_service.dart';
import '../../../core/db/app_repository.dart';
import '../../../core/models/entry.dart';
import '../../../core/models/enums.dart';
import '../../../core/models/food.dart';
import '../../../core/models/nutrients.dart';
import '../../../core/state/app_state.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/util/date_utils.dart';
import '../../../core/widgets/app_widgets.dart';
import '../food_search_page.dart';
import '../portion_sheet.dart';
import 'record_common.dart';

enum ComposerMode { text, photo, search }

/// 返回 true 表示已经保存。
Future<bool?> showEntryComposer(
  BuildContext context, {
  required String date,
  MealSlot? slot,
  ComposerMode? initialMode,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => EntryComposerSheet(
      date: date,
      initialSlot: slot,
      initialMode: initialMode ?? ComposerMode.text,
    ),
  );
}

/// 空状态三个入口需要直接落到对应模式。
Future<bool?> showTextComposer(BuildContext context, String date) =>
    showEntryComposer(context, date: date, initialMode: ComposerMode.text);

Future<bool?> showPhotoComposer(BuildContext context, String date) =>
    showEntryComposer(context, date: date, initialMode: ComposerMode.photo);

Future<bool?> showSearchComposer(BuildContext context, String date) =>
    showEntryComposer(context, date: date, initialMode: ComposerMode.search);

class _Draft {
  Food? food;
  String name;
  double gramsP10;
  double gramsP50;
  double gramsP90;
  EstimateMethod method;
  double confidence;
  String? containerId;
  String? referenceObjectId;
  String? explanation;
  PrecisionTier tier;

  _Draft({
    required this.food,
    required this.name,
    required this.gramsP10,
    required this.gramsP50,
    required this.gramsP90,
    required this.method,
    required this.confidence,
    this.containerId,
    this.referenceObjectId,
    this.explanation,
    required this.tier,
  });

  factory _Draft.fromChoice(Food food, PortionChoice choice) => _Draft(
    food: food,
    name: food.name,
    gramsP10: choice.gramsP10,
    gramsP50: choice.gramsP50,
    gramsP90: choice.gramsP90,
    method: choice.method,
    confidence: choice.confidence,
    containerId: choice.containerId,
    referenceObjectId: choice.referenceObjectId,
    explanation: choice.explanation,
    tier: choice.tier,
  );

  NutrientRange get grams => (p10: gramsP10, p50: gramsP50, p90: gramsP90);

  NutrientRange get kcal {
    final per100 = food?.nutrient(NutrientCode.energy) ?? 0;
    return (
      p10: per100 * gramsP10 / 100,
      p50: per100 * gramsP50 / 100,
      p90: per100 * gramsP90 / 100,
    );
  }

  void apply(PortionChoice choice) {
    gramsP10 = choice.gramsP10;
    gramsP50 = choice.gramsP50;
    gramsP90 = choice.gramsP90;
    method = choice.method;
    confidence = choice.confidence;
    containerId = choice.containerId;
    referenceObjectId = choice.referenceObjectId;
    explanation = choice.explanation;
    tier = choice.tier;
  }

  PortionChoice toChoice() => PortionChoice(
    gramsP10: gramsP10,
    gramsP50: gramsP50,
    gramsP90: gramsP90,
    method: method,
    confidence: confidence,
    explanation: explanation ?? '',
    tier: tier,
    containerId: containerId,
    referenceObjectId: referenceObjectId,
  );

  EntryItem toEntryItem(AppRepository repo, int position) {
    final food = this.food;
    if (food != null) {
      return EntryItem.fromFood(
        id: repo.newId(),
        food: food,
        gramsP10: gramsP10,
        gramsP50: gramsP50,
        gramsP90: gramsP90,
        method: method,
        confidence: confidence,
        containerId: containerId,
        referenceObjectId: referenceObjectId,
        position: position,
      );
    }
    return EntryItem(
      id: repo.newId(),
      foodName: name,
      gramsP10: gramsP10,
      gramsP50: gramsP50,
      gramsP90: gramsP90,
      method: method,
      confidence: confidence,
      containerId: containerId,
      referenceObjectId: referenceObjectId,
      position: position,
    );
  }
}

class EntryComposerSheet extends ConsumerStatefulWidget {
  final String date;
  final MealSlot? initialSlot;
  final ComposerMode initialMode;

  const EntryComposerSheet({
    super.key,
    required this.date,
    this.initialSlot,
    required this.initialMode,
  });

  @override
  ConsumerState<EntryComposerSheet> createState() => _EntryComposerSheetState();
}

class _EntryComposerSheetState extends ConsumerState<EntryComposerSheet> {
  late MealSlot _slot;
  late ComposerMode _mode;
  final TextEditingController _textCtrl = TextEditingController();
  final List<_Draft> _drafts = <_Draft>[];
  bool _parsing = false;
  bool _saving = false;
  bool _usedPhoto = false;
  String? _error;
  String? _note;
  String? _aiMeta;
  Uint8List? _photoBytes;
  String? _photoMime;
  String? _photoName;

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _slot =
        widget.initialSlot ??
        MealSlot.values.firstWhere(
          (slot) => slot.name == slotForTime(DateTime.now()),
          orElse: () => MealSlot.snack,
        );
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  // ---------- 解析 ----------

  Future<void> _parseText() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) {
      setState(() => _error = '先写一句吃了什么，例如「番茄炒蛋 200g + 米饭一碗」。');
      return;
    }
    setState(() {
      _parsing = true;
      _error = null;
      _note = null;
      _aiMeta = null;
    });
    final settings = ref.read(settingsProvider);
    final foods = ref.read(foodsProvider);
    final result = await AiService(
      settings: settings,
      foods: foods,
    ).parseText(text);
    if (!mounted) return;
    setState(() {
      _parsing = false;
      if (result.ok) {
        for (final item in result.items) {
          _drafts.add(_draftFromAi(item, usedAi: result.usedAi));
        }
        _error = null;
        _note =
            result.error ?? (result.usedAi ? null : '本地规则匹配完成；没匹配到的食物可以搜索补充。');
        if (result.usedAi) {
          final inTokens = result.inputTokens;
          final outTokens = result.outputTokens;
          _aiMeta = [
            if (inTokens != null || outTokens != null)
              'tokens ${inTokens ?? '?'} / ${outTokens ?? '?'}',
            '约 ¥0.003',
          ].join(' · ');
        }
      } else {
        _error = result.error ?? '没解析出食物。换一种说法，或直接搜索。';
      }
    });
  }

  Future<void> _parsePhoto() async {
    final bytes = _photoBytes;
    if (bytes == null) return;
    final settings = ref.read(settingsProvider);
    if (!(settings.aiEnabled && settings.hasAiKey && !settings.localOnly)) {
      setState(() {
        _error = '照片识别需要 AI key。照片不会上传；可以改用文字或搜索记录。';
        _note = null;
      });
      return;
    }
    setState(() {
      _parsing = true;
      _error = null;
      _note = null;
      _aiMeta = null;
    });
    final result = await AiService(
      settings: settings,
      foods: ref.read(foodsProvider),
    ).parseImage(bytes: bytes, mimeType: _photoMime ?? 'image/jpeg');
    if (!mounted) return;
    setState(() {
      _parsing = false;
      _usedPhoto = true;
      if (result.ok) {
        for (final item in result.items) {
          _drafts.add(_draftFromAi(item, usedAi: true));
        }
        _error = null;
        _note = '照片里识别出 ${result.items.length} 项，份量请再确认。';
        final inTokens = result.inputTokens;
        final outTokens = result.outputTokens;
        if (inTokens != null || outTokens != null) {
          _aiMeta =
              'tokens ${inTokens ?? '?'} / ${outTokens ?? '?'} · 约 ¥0.003';
        }
      } else {
        _error = result.error ?? '照片没识别出食物。可以改用文字或搜索。';
      }
    });
  }

  _Draft _draftFromAi(AiParseItem item, {required bool usedAi}) {
    final byId = ref.read(dataProvider)?.foodById ?? const <String, Food>{};
    Food? food = item.food;
    food ??= item.foodId == null ? null : byId[item.foodId];
    food ??= _fuzzyFood(item.name);
    return _Draft(
      food: food,
      name: food?.name ?? item.name,
      gramsP10: item.gramsP10,
      gramsP50: item.gramsP50,
      gramsP90: item.gramsP90,
      method: usedAi ? EstimateMethod.ai : EstimateMethod.visual,
      confidence: item.confidence,
      explanation: !usedAi
          ? null
          : item.nutrientSource == 'ai_estimate'
              ? '本地库没有这道菜：营养为 AI 估算，已过值域校验，按「AI 估算」记账。'
              : 'AI 只给份量与菜名，营养数字来自本地成分表。',
      tier: PrecisionTier.quick,
    );
  }

  Food? _fuzzyFood(String name) {
    final normalized = name.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    if (normalized.isEmpty) return null;
    final foods = ref.read(foodsProvider);
    Food? best;
    var bestScore = 0;
    for (final food in foods) {
      for (final candidate in [food.name, ...food.aliases]) {
        final c = candidate.toLowerCase().replaceAll(RegExp(r'\s+'), '');
        if (c.isEmpty) continue;
        if (normalized.contains(c) || c.contains(normalized)) {
          if (c.length > bestScore) {
            best = food;
            bestScore = c.length;
          }
        }
      }
    }
    return best;
  }

  // ---------- 选图 ----------

  Future<void> _pickPhoto({bool camera = false}) async {
    try {
      if (_isAndroid) {
        final file = await ImagePicker().pickImage(
          source: camera ? ImageSource.camera : ImageSource.gallery,
          imageQuality: 85,
          maxWidth: 1600,
        );
        if (file == null) return;
        final bytes = await file.readAsBytes();
        _applyPhoto(
          bytes,
          file.mimeType ?? _mimeFromName(file.name),
          file.name,
        );
        return;
      }
      final picked = await FilePicker.pickFile(
        type: FileType.image,
        dialogTitle: '选择餐食照片',
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (bytes.isEmpty) {
        setState(() => _error = '读不到图片数据，换一张试试。');
        return;
      }
      _applyPhoto(bytes, _mimeFromName(picked.name), picked.name);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '选图失败：$error');
    }
  }

  void _applyPhoto(Uint8List bytes, String mime, String name) {
    if (!mounted) return;
    setState(() {
      _photoBytes = bytes;
      _photoMime = mime;
      _photoName = name;
      _mode = ComposerMode.photo;
      _usedPhoto = true;
      _error = null;
      _note = '照片只用于本次识别，本版不保存原图。';
    });
  }

  String _mimeFromName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }

  // ---------- 份量 / 食物 ----------

  double? _personalMedian(Food food) {
    final entries = ref.read(dataProvider)?.entries ?? const <FoodEntry>[];
    return historyMedianGrams(entries, food.id);
  }

  Future<void> _addFood(Food food) async {
    final choice = await showPortionSheet(
      context,
      food: food,
      initialTier: ref.read(settingsProvider).precision,
      personalMedian: _personalMedian(food),
    );
    if (choice == null || !mounted) return;
    setState(() {
      _drafts.add(_Draft.fromChoice(food, choice));
      _error = null;
      if (_mode == ComposerMode.search) _note = '已加入 ${food.name}，还可以继续加。';
    });
  }

  Future<void> _openSearch() async {
    final food = await Navigator.of(
      context,
    ).push<Food>(MaterialPageRoute(builder: (_) => const FoodSearchPage()));
    if (food == null || !mounted) return;
    await _addFood(food);
  }

  Future<void> _editDraft(_Draft draft) async {
    final food = draft.food ?? _snapshotFood(draft);
    final choice = await showPortionSheet(
      context,
      food: food,
      initial: draft.toChoice(),
      initialTier: draft.tier,
      personalMedian: _personalMedian(food),
    );
    if (choice == null || !mounted) return;
    setState(() {
      draft.apply(choice);
      _error = null;
    });
  }

  Food _snapshotFood(_Draft draft) => Food(
    id: 'draft:${draft.name}',
    name: draft.name,
    category: 'other',
    source: 'draft',
    nutrientsPer100g: const {},
    groupsPer100g: const {},
    defaultServingGrams: draft.gramsP50 > 0 ? draft.gramsP50 : null,
    createdAt: 0,
    updatedAt: 0,
  );

  Future<void> _associate(_Draft draft) async {
    final food = await Navigator.of(
      context,
    ).push<Food>(MaterialPageRoute(builder: (_) => const FoodSearchPage()));
    if (food == null || !mounted) return;
    setState(() {
      draft.food = food;
      draft.name = food.name;
    });
  }

  // ---------- 保存 ----------

  NutrientRange get _totalKcal {
    var p10 = 0.0;
    var p50 = 0.0;
    var p90 = 0.0;
    for (final draft in _drafts) {
      final range = draft.kcal;
      p10 += range.p10;
      p50 += range.p50;
      p90 += range.p90;
    }
    return (p10: p10, p50: p50, p90: p90);
  }

  Future<bool?> _confirmUnmatched(int count) {
    final t = context.tokens;
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: t.surface,
        title: const Text('有食物还没关联'),
        content: Text('$count 项不在食物库里，营养不会计入这一餐。可以先关联，或仍然保存份量。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('返回关联'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('仍然保存'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final drafts = _drafts.where((d) => d.gramsP50 > 0).toList();
    if (drafts.isEmpty || _saving) return;
    final unmatched = drafts.where((d) => d.food == null).length;
    if (unmatched > 0) {
      final ok = await _confirmUnmatched(unmatched);
      if (ok != true) return;
    }
    if (!mounted) return;
    setState(() => _saving = true);
    final data = ref.read(dataProvider);
    final repo = ref.read(repositoryProvider);
    final now = DateTime.now().millisecondsSinceEpoch;
    final entry = FoodEntry(
      id: repo.newId(),
      profileId: data?.profile?.id ?? 'default',
      eatenAtMs: now,
      localDate: widget.date,
      slot: _slot,
      inputMode: _usedPhoto
          ? InputMode.photo
          : _mode == ComposerMode.text
          ? InputMode.text
          : InputMode.quick,
      items: [
        for (var i = 0; i < drafts.length; i++) drafts[i].toEntryItem(repo, i),
      ],
      createdAt: now,
      updatedAt: now,
    );
    final firstOfDay = data?.entriesForDate(widget.date).isEmpty ?? true;
    await ref.read(appStateProvider.notifier).saveEntry(entry);
    if (firstOfDay) {
      await ref.read(appStateProvider.notifier).addCoins(5);
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final settings = ref.read(settingsProvider);
    final aiReady =
        settings.aiEnabled && settings.hasAiKey && !settings.localOnly;
    final data = ref.watch(dataProvider);
    final recent = recentFoods(
      data?.entries ?? const [],
      data?.foodById ?? const {},
      limit: 8,
    );
    final total = _totalKcal;
    final maxHeight = MediaQuery.of(context).size.height * 0.94;

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
                          '记一餐',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          '${relativeDayLabel(widget.date)} · ${formatDateWithWeekday(widget.date)}',
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SegmentedChoice<ComposerMode>(
                      values: const [
                        ComposerMode.text,
                        ComposerMode.photo,
                        ComposerMode.search,
                      ],
                      selected: _mode,
                      label: (mode) => switch (mode) {
                        ComposerMode.text => '文字',
                        ComposerMode.photo => '拍照',
                        ComposerMode.search => '搜索',
                      },
                      onChanged: (mode) => setState(() => _mode = mode),
                    ),
                    const SizedBox(height: 14),
                    if (_mode == ComposerMode.text)
                      _buildTextMode(context, aiReady),
                    if (_mode == ComposerMode.photo)
                      _buildPhotoMode(context, aiReady),
                    if (_mode == ComposerMode.search)
                      _buildSearchMode(context, recent),
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      _MessageCard(
                        icon: Icons.error_outline_rounded,
                        color: t.high,
                        text: _error!,
                      ),
                    ],
                    if (_note != null) ...[
                      const SizedBox(height: 10),
                      _MessageCard(
                        icon: Icons.info_outline_rounded,
                        color: t.inkSecondary,
                        text: _note!,
                      ),
                    ],
                    if (_aiMeta != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'AI 解析 · $_aiMeta',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '这一餐 · ${_drafts.length} 项',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        Text(
                          _drafts.isEmpty
                              ? '区间估算'
                              : '合计 ${formatKcalRange(total)}',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_drafts.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: t.surfaceAlt,
                          borderRadius: BorderRadius.circular(t.radiusMd),
                        ),
                        child: Text(
                          '还没有食物。说一句、拍一张，或者搜一个常吃的。'
                          '份量会先给区间，不用称。',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      )
                    else
                      for (final draft in _drafts)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _DraftTile(
                            draft: draft,
                            onEdit: () => _editDraft(draft),
                            onDelete: () =>
                                setState(() => _drafts.remove(draft)),
                            onAssociate: draft.food == null
                                ? () => _associate(draft)
                                : null,
                          ),
                        ),
                    if (_drafts.isNotEmpty && _mode != ComposerMode.search)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '保存后只回「已记录 ✓」；份量之后随时能改。',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${_slot.label} · ${_drafts.length} 项',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          Text(
                            _drafts.isEmpty ? '先加一项' : formatKcalRange(total),
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _drafts.isEmpty || _saving || _parsing
                          ? null
                          : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('保存'),
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

  Widget _buildTextMode(BuildContext context, bool aiReady) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _textCtrl,
          minLines: 3,
          maxLines: 5,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          decoration: const InputDecoration(
            hintText: '例如：番茄炒蛋 200g + 米饭一碗\n也可以写「楼下麻辣烫，吃了七成」',
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _parsing ? null : _parseText,
                icon: _parsing
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome_outlined, size: 18),
                label: Text(_parsing ? '解析中…' : '解析'),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () => _textCtrl.text = '番茄炒蛋 200g + 米饭一碗',
              child: const Text('示例'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          aiReady
              ? '将调用 DeepSeek（BYOK，你的 key），单次约 ¥0.003；失败自动回退本地规则。'
              : '本地规则模式：按食物别名匹配，不需要 key。识别不到时可以搜索补充。',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: aiReady ? t.inkSecondary : t.inkTertiary,
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoMode(BuildContext context, bool aiReady) {
    final t = context.tokens;
    final bytes = _photoBytes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (bytes == null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
            decoration: BoxDecoration(
              color: t.surfaceAlt,
              borderRadius: BorderRadius.circular(t.radiusLg),
              border: Border.all(color: t.hairline, width: t.borderWidth),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.photo_camera_outlined,
                  size: 30,
                  color: t.inkTertiary,
                ),
                const SizedBox(height: 8),
                Text('拍一张餐食照片', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  '照片只用于本次识别，不上传到相册，也不保存原图。',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          )
        else
          ClipRRect(
            borderRadius: BorderRadius.circular(t.radiusLg),
            child: Image.memory(
              bytes,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
          ),
        const SizedBox(height: 10),
        Row(
          children: [
            if (_isAndroid) ...[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _parsing ? null : () => _pickPhoto(camera: true),
                  icon: const Icon(Icons.photo_camera_outlined, size: 18),
                  label: const Text('拍照'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _parsing ? null : () => _pickPhoto(),
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: const Text('相册'),
                ),
              ),
            ] else
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _parsing ? null : () => _pickPhoto(),
                  icon: const Icon(Icons.image_outlined, size: 18),
                  label: Text(bytes == null ? '选择图片' : '换一张'),
                ),
              ),
          ],
        ),
        if (bytes != null) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _parsing ? null : _parsePhoto,
              icon: _parsing
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome_outlined, size: 18),
              label: Text(_parsing ? '识别中…' : '识别这张'),
            ),
          ),
          if (_photoName != null) ...[
            const SizedBox(height: 6),
            Text(
              _photoName!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ],
        const SizedBox(height: 8),
        if (!aiReady)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  '未启用 AI 或没有 key：照片识别不可用，但不会挡住记录。'
                  '可以回到「文字」，或直接「搜索」。',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _mode = ComposerMode.text),
                child: const Text('改用文字'),
              ),
            ],
          )
        else
          Text(
            '将调用 DeepSeek 视觉模型（BYOK），单次约 ¥0.003；识别失败会退回文字流程。',
            style: Theme.of(context).textTheme.labelSmall,
          ),
      ],
    );
  }

  Widget _buildSearchMode(BuildContext context, List<Food> recent) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _openSearch,
            icon: const Icon(Icons.search_rounded, size: 18),
            label: const Text('打开食物库搜索'),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '按名称、别名、标签搜索；点选后进入份量弹层，不会直接问克数。',
          style: Theme.of(context).textTheme.labelSmall,
        ),
        if (recent.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('最近吃过', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final food in recent)
                ChoicePill(
                  label: food.name,
                  hint:
                      '${food.nutrient(NutrientCode.energy).round()} kcal/100g',
                  onTap: () => _addFood(food),
                ),
            ],
          ),
        ],
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: t.surfaceAlt,
            borderRadius: BorderRadius.circular(t.radiusMd),
          ),
          child: Text(
            '搜索适合「知道吃什么、只是懒得描述」的场景；'
            '炒菜、混合菜建议还是走文字或拍照，份量差异更大。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _DraftTile extends StatelessWidget {
  final _Draft draft;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onAssociate;

  const _DraftTile({
    required this.draft,
    required this.onEdit,
    required this.onDelete,
    this.onAssociate,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final kcal = draft.kcal;
    return Container(
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
                  draft.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              IconButton(
                tooltip: '改份量',
                onPressed: onEdit,
                icon: Icon(Icons.tune_rounded, size: 18, color: t.inkSecondary),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              IconButton(
                tooltip: '移除',
                onPressed: onDelete,
                icon: Icon(Icons.close_rounded, size: 18, color: t.inkTertiary),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              MethodChip(draft.method),
              Pill(
                '置信度 ${confidenceLabel(draft.confidence)}',
                color: confidenceColor(t, draft.confidence),
              ),
              Text(
                '${draft.gramsP50.round()} g · ${formatGramRange(draft.grams)}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                '${formatKcalRange(kcal)} · ${draft.tier.label}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Spacer(),
              if (draft.food != null)
                Text(
                  '${formatKcal(draft.kcal.p50)} kcal',
                  style: Theme.of(context).textTheme.labelMedium,
                )
              else
                Text(
                  '营养不计入',
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: t.high),
                ),
            ],
          ),
          if (onAssociate != null) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.link_off_rounded, size: 14, color: t.high),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '食物库未收录',
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: t.high),
                  ),
                ),
                TextButton(
                  onPressed: onAssociate,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text('关联'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _MessageCard({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(t.radiusMd),
        border: Border.all(
          color: color.withValues(alpha: 0.35),
          width: t.borderWidth,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: t.inkSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
