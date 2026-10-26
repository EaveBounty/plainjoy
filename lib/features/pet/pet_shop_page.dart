import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/enums.dart';
import '../../core/models/pet.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_widgets.dart';
import 'pet_stage.dart';

/// 宠物商店：默认伙伴 + 爪印领养，无抽卡、无付费墙。
class PetShopPage extends ConsumerStatefulWidget {
  const PetShopPage({super.key});

  @override
  ConsumerState<PetShopPage> createState() => _PetShopPageState();
}

class _PetShopPageState extends ConsumerState<PetShopPage> {
  static const _order = <PetSpecies>[
    PetSpecies.calicoCat,
    PetSpecies.tuxedoDog,
    PetSpecies.tabbyCat,
    PetSpecies.orangeCat,
    PetSpecies.shibaInu,
    PetSpecies.tuxedoCat,
    PetSpecies.corgi,
  ];



  Future<void> _switchTo(Pet pet) async {
    await ref.read(appStateProvider.notifier).switchPet(pet.id);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('正在使用 ${pet.name}。')));
  }

  Future<void> _adopt(PetSpecies species) async {
    final notifier = ref.read(appStateProvider.notifier);
    final ok = await notifier.unlockPet(species, species.label);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('爪印还不够，再记几餐。')));
      return;
    }
    final data = ref.read(dataProvider);
    Pet? adopted;
    for (final pet in data?.pets ?? const <Pet>[]) {
      if (pet.species == species) {
        adopted = pet;
        break;
      }
    }
    if (adopted != null) {
      await notifier.switchPet(adopted.id);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已领养 ${species.label}。')));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final data = ref.watch(dataProvider);
    final pets = data?.pets ?? const <Pet>[];
    final coins = data?.activePet?.coins ?? 0;
    final ownedSpecies = pets.map((pet) => pet.species).toSet();
    final purchasable = _order
        .where((species) => !ownedSpecies.contains(species))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('宠物商店')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            AppCard(
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: t.surfaceAlt,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: t.hairline,
                        width: t.borderWidth,
                      ),
                    ),
                    child: Icon(Icons.pets_rounded, size: 21, color: t.ink),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '爪印余额',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$coins',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '不做抽卡\n直接领养',
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            SectionTitle('已拥有', subtitle: '共 ${pets.length} 位伙伴；切换不消耗爪印'),
            if (pets.isEmpty)
              AppCard(
                child: Text(
                  '还没有伙伴，先领养一只。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              )
            else
              for (final pet in pets) ...[
                _OwnedCard(
                  pet: pet,
                  active: pet.id == data?.activePet?.id,
                  onSwitch: () => _switchTo(pet),
                ),
                const SizedBox(height: 10),
              ],
            const SizedBox(height: 14),
            SectionTitle(
              '可以领养',
              subtitle: purchasable.isEmpty ? '已经收集齐了' : '价格只与爪印有关',
            ),
            for (final species in purchasable) ...[
              _AdoptCard(
                species: species,
                coins: coins,
                onAdopt: () => _adopt(species),
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 6),
            Text(
              '已领养的伙伴可以随时切换，不再消耗爪印。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _OwnedCard extends StatelessWidget {
  final Pet pet;
  final bool active;
  final VoidCallback onSwitch;

  const _OwnedCard({
    required this.pet,
    required this.active,
    required this.onSwitch,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AppCard(
      padding: const EdgeInsets.all(10),
      onTap: active ? null : onSwitch,
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: PetStage(
              species: pet.species,
              signal: PetSignal.idle,
              axes: const PetAxes(
                vitality: 72,
                coat: 70,
                mood: 74,
                hydration: 68,
              ),
              height: 92,
              animated: active,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pet.name, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  '${pet.species.label} · 等级 ${pet.level}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (active)
                      Pill(
                        '使用中',
                        color: t.good,
                        filled: true,
                        icon: Icons.check_rounded,
                      )
                    else
                      const Pill('已拥有'),
                    if (!active) ...[
                      const Spacer(),
                      Text(
                        '点按切换',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: t.inkTertiary,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdoptCard extends StatelessWidget {
  final PetSpecies species;
  final int coins;
  final VoidCallback onAdopt;

  const _AdoptCard({
    required this.species,
    required this.coins,
    required this.onAdopt,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final price = species.price;
    final affordable = coins >= price;
    return AppCard(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: PetStage(
              species: species,
              signal: PetSignal.idle,
              axes: const PetAxes(),
              height: 92,
              animated: false,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  species.label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  _hint(species),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      price > 0 ? '$price 爪印' : '免费',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: affordable ? t.ink : t.inkTertiary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const Spacer(),
                    if (affordable)
                      FilledButton(
                        onPressed: onAdopt,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                        child: const Text('领养'),
                      )
                    else
                      OutlinedButton(
                        onPressed: null,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        child: Text('还差 ${price - coins}'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _hint(PetSpecies species) => switch (species) {
    PetSpecies.calicoCat => '安静，喜欢在窗边待着。',
    PetSpecies.tuxedoDog => '稳当，吃饭很认真。',
    PetSpecies.tabbyCat => '短毛，爱趴在桌角。',
    PetSpecies.orangeCat => '胃口好，喜欢晒太阳。',
    PetSpecies.shibaInu => '独立，散步时走得快。',
    PetSpecies.tuxedoCat => '黑白分明，夜里最活跃。',
    PetSpecies.corgi => '腿短，跑起来很认真。',
  };
}
