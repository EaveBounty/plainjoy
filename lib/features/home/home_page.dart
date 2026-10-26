import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/enums.dart';
import '../../core/models/pet.dart';
import '../../core/pet/pet_state_service.dart';
import '../../core/state/app_state.dart';
import '../../core/state/score_providers.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/util/date_utils.dart';
import '../../core/widgets/app_widgets.dart';
import '../nutrition/nutrition_page.dart';
import '../pet/pet_shop_page.dart';
import '../pet/pet_stage.dart';
import '../plan/plan_page.dart';
import '../record/record_page.dart';
import '../settings/settings_page.dart';
import 'widgets/home_cards.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final score = ref.watch(todayScoreProvider);
    final entries = ref.watch(todayEntriesProvider);
    final petState = ref.watch(petStateProvider);
    final pet = ref.watch(activePetProvider);
    final streak = ref.watch(streakProvider);
    final reduceMotion = ref.watch(settingsProvider).reduceMotion;
    final coins = pet?.coins ?? 0;

    void open(Widget page) {
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
    }

    return Scaffold(
      backgroundColor: t.background,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
          children: [
            _HomeHeader(
              greeting: _greeting(DateTime.now().hour),
              date: formatDateWithWeekday(todayKey()),
              streak: streak,
              coins: coins,
              onSettings: () => open(const SettingsPage()),
            ),
            const SizedBox(height: 14),
            _PetCard(
              pet: pet,
              state: petState,
              animated: !reduceMotion,
              onTap: () => showPetSheet(context, pet: pet, state: petState),
            ),
            const SizedBox(height: 22),
            const SectionTitle('今日分数', subtitle: '区间比单点更诚实'),
            TodayScoreCard(
              score: score,
              entryCount: entries.length,
              onRecord: () => open(const RecordPage()),
            ),
            const SizedBox(height: 22),
            const SectionTitle('快速记录', subtitle: '三种输入都落在同一份记录里'),
            HomeQuickActions(
              onRecord: () => open(const RecordPage()),
              onPlan: () => open(const PlanPage()),
              onNutrition: () => open(const NutritionPage()),
            ),
            const SizedBox(height: 22),
            const SectionTitle('今日建议'),
            SuggestionCard(action: score.topAction),
            const SizedBox(height: 22),
            const SectionTitle('今日时间线', subtitle: '按早餐、午餐、晚餐、加餐归档'),
            TodayTimeline(
              entries: entries,
              onRecord: () => open(const RecordPage()),
            ),
            const SizedBox(height: 20),
            PetShopEntryCard(
              pet: pet,
              coins: coins,
              onTap: () => open(const PetShopPage()),
            ),
          ],
        ),
      ),
    );
  }

  static String _greeting(int hour) {
    if (hour < 5) return '夜深了';
    if (hour < 11) return '早上好';
    if (hour < 14) return '中午好';
    if (hour < 18) return '下午好';
    return '晚上好';
  }
}

class _HomeHeader extends StatelessWidget {
  final String greeting;
  final String date;
  final int streak;
  final int coins;
  final VoidCallback onSettings;

  const _HomeHeader({
    required this.greeting,
    required this.date,
    required this.streak,
    required this.coins,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(date, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 3),
                  Text(
                    greeting,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: '设置',
              onPressed: onSettings,
              icon: const Icon(Icons.settings_outlined),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Pill(
              '连续 $streak 天',
              icon: Icons.local_fire_department_outlined,
              color: streak > 0 ? t.good : null,
              filled: streak > 0,
            ),
            const SizedBox(width: 8),
            Pill('爪印 $coins', icon: Icons.pets_outlined),
          ],
        ),
      ],
    );
  }
}

class _PetCard extends StatelessWidget {
  final Pet? pet;
  final PetStateResult state;
  final bool animated;
  final VoidCallback onTap;

  const _PetCard({
    required this.pet,
    required this.state,
    required this.animated,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      onTap: onTap,
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        pet?.name ?? '你的伙伴',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Pill(petSignalLabel(state.signal)),
                  ],
                ),
              ),
              Text('点一下', style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
          PetStage(
            species: pet?.species ?? PetSpecies.calicoCat,
            signal: state.signal,
            axes: state.axes,
            height: 236,
            animated: animated,
            onTap: onTap,
          ),
          Text(
            state.message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          PetAxisBars(axes: state.axes),
        ],
      ),
    );
  }
}
