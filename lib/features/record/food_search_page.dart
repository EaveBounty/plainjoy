import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/food.dart';
import '../../core/models/nutrients.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_widgets.dart';
import 'widgets/record_common.dart';

/// 搜索页只负责选食物；份量与保存交给调用方，避免两套流程。
class FoodSearchPage extends ConsumerStatefulWidget {
  const FoodSearchPage({super.key});

  @override
  ConsumerState<FoodSearchPage> createState() => _FoodSearchPageState();
}

class _FoodSearchPageState extends ConsumerState<FoodSearchPage> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';
  int _tab = 0;
  List<Food> _indexedFoods = const [];
  List<String> _haystack = const [];
  List<String> _lowerNames = const [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 1800 条食物只在列表变化时重建一次检索串，避免每次按键重复 toLowerCase。
  void _syncIndex(List<Food> foods) {
    if (identical(_indexedFoods, foods)) return;
    _indexedFoods = foods;
    _haystack = [for (final food in foods) food.searchText];
    _lowerNames = [for (final food in foods) food.name.toLowerCase()];
  }

  List<Food> _search() {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final matches = <int>[];
    for (var i = 0; i < _haystack.length; i++) {
      if (_haystack[i].contains(q)) matches.add(i);
    }
    matches.sort((a, b) {
      final aStarts = _lowerNames[a].startsWith(q) ? 0 : 1;
      final bStarts = _lowerNames[b].startsWith(q) ? 0 : 1;
      if (aStarts != bStarts) return aStarts.compareTo(bStarts);
      final an = _lowerNames[a];
      final bn = _lowerNames[b];
      if (an.length != bn.length) return an.length.compareTo(bn.length);
      return an.compareTo(bn);
    });
    return [for (final i in matches) _indexedFoods[i]];
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final data = ref.watch(dataProvider);
    final foods = data?.foods ?? const <Food>[];
    final byId = data?.foodById ?? const <String, Food>{};
    final entries = data?.entries ?? const [];
    final recent = recentFoods(entries, byId, limit: 12);
    final frequent = frequentFoods(entries, byId, limit: 12);
    _syncIndex(foods);
    final results = _search();
    final showingSearch = _query.trim().isNotEmpty;
    final visible = showingSearch
        ? results
        : switch (_tab) {
            0 => recent,
            1 => frequent,
            _ => foods,
          };

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              title: '搜索食物',
              subtitle: showingSearch ? '找到 ${results.length} 条' : '名称、别名或标签都行',
              showBack: true,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: TextField(
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: '例如：米饭 / 番茄 / 高蛋白',
                  prefixIcon: Icon(Icons.search_rounded, color: t.inkTertiary),
                  suffixIcon: showingSearch
                      ? IconButton(
                          tooltip: '清空',
                          icon: Icon(
                            Icons.close_rounded,
                            color: t.inkTertiary,
                            size: 18,
                          ),
                          onPressed: () {
                            _controller.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            if (!showingSearch)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: SegmentedChoice<int>(
                  values: const [0, 1, 2],
                  selected: _tab,
                  label: (value) => switch (value) {
                    0 => '最近',
                    1 => '常吃',
                    _ => '全部',
                  },
                  onChanged: (value) => setState(() => _tab = value),
                  dense: true,
                ),
              ),
            Expanded(
              child: visible.isEmpty
                  ? EmptyState(
                      icon: showingSearch
                          ? Icons.search_off_rounded
                          : Icons.history_rounded,
                      title: showingSearch ? '没搜到' : '还没有可复用的食物',
                      body: showingSearch
                          ? '换个叫法，或者回到记录页用一句话记下这餐。'
                          : '记录几次之后，最近和常吃会出现在这里。',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                      itemCount: visible.length,
                      separatorBuilder: (_, _) => Hairline(indent: 12),
                      itemBuilder: (context, index) {
                        final food = visible[index];
                        return _FoodRow(
                          food: food,
                          trailingHint: showingSearch
                              ? null
                              : _tab == 1
                              ? '常吃'
                              : '最近',
                          onTap: () => Navigator.of(context).pop(food),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FoodRow extends StatelessWidget {
  final Food food;
  final String? trailingHint;
  final VoidCallback onTap;

  const _FoodRow({required this.food, required this.onTap, this.trailingHint});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final kcal = food.nutrient(NutrientCode.energy);
    final serving = food.defaultServingGrams;
    final subtitle = <String>[
      categoryLabel(food.category),
      if (food.aliases.isNotEmpty) food.aliases.take(2).join(' / '),
      if (serving != null)
        '一份 ${food.defaultServingLabel ?? ''}${food.defaultServingLabel == null ? '' : ' '}${serving.round()} g',
    ].join(' · ');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(t.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          food.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      if (trailingHint != null) ...[
                        const SizedBox(width: 6),
                        Pill(trailingHint!, color: t.inkTertiary),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${kcal.round()}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  'kcal/100g',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
            const SizedBox(width: 2),
            Icon(Icons.chevron_right_rounded, size: 18, color: t.inkTertiary),
          ],
        ),
      ),
    );
  }
}
