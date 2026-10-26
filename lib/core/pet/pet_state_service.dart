import 'dart:math';

import '../models/enums.dart';
import '../models/pet.dart';
import '../models/score.dart';

class PetStateResult {
  final PetAxes axes;
  final PetSignal signal;
  final String message;
  final String action;
  final Map<String, double> drivers;

  const PetStateResult({
    required this.axes,
    required this.signal,
    required this.message,
    required this.action,
    this.drivers = const {},
  });
}

class PetStateService {
  static PetStateResult compute({
    required List<DayScore> last7,
    required int streakDays,
    double waterMl = 0,
  }) {
    final eligible = last7.where((e) => e.eligible && e.total != null).toList();
    if (eligible.isEmpty) {
      return const PetStateResult(
        axes: PetAxes(),
        signal: PetSignal.idle,
        message: '它在窗边打盹，等你今天的第一餐。',
        action: '记一餐，我就能告诉你今天差哪一口。',
      );
    }

    double itemScore(String code) {
      double total = 0;
      var count = 0;
      for (final day in eligible) {
        final matches = day.items.where((e) => e.code == code);
        if (matches.isNotEmpty) {
          total += matches.first.score;
          count++;
        }
      }
      return count == 0 ? 60 : total / count;
    }

    final vitality = (0.35 * itemScore('B1') +
            0.25 * itemScore('B4') +
            0.20 * itemScore('B7') +
            0.20 * itemScore('A6')) *
        0.9 +
        min(10, streakDays.toDouble());
    final coat = (0.55 * itemScore('B1') + 0.25 * itemScore('B5') + 0.20 * itemScore('A5')) * 0.9 + 8;
    final moodBase = eligible
            .map((e) => (e.domainScore(ScoreDomain.foodGroups) +
                    e.domainScore(ScoreDomain.nutrients) +
                    e.domainScore(ScoreDomain.limits)) /
                3)
            .reduce((a, b) => a + b) /
        eligible.length;
    final mood = moodBase * 0.9 + min(10, eligible.length * 1.5);
    final hydration = (0.7 * itemScore('C1') + 0.3 * (waterMl > 0 ? min(100, waterMl / 17) : 60));

    final axes = PetAxes(
      vitality: vitality.round().clamp(0, 100),
      coat: coat.round().clamp(0, 100),
      mood: mood.round().clamp(0, 100),
      hydration: hydration.round().clamp(0, 100),
    );

    final lowest = axes.lowest;
    final gap = axes.secondLowest - lowest;
    final average = (axes.vitality + axes.coat + axes.mood + axes.hydration) / 4;

    if (average >= 85) {
      return PetStateResult(
        axes: axes,
        signal: PetSignal.celebrate,
        message: '它今天毛发光亮，绕着你转了两圈。',
        action: '保持这个结构，别为了分数吃得太单一。',
        drivers: axes.toJson().map((k, v) => MapEntry(k, v.toDouble())),
      );
    }

    if (lowest < 45 && gap >= 8) {
      final (signal, message, action) = switch (axes.lowestKey) {
        'vitality' => (
            PetSignal.lowEnergy,
            '它趴着不太想动，蛋白质和铁可能没跟上。',
            '下一餐加一掌心鱼/鸡胸或 50 g 瘦牛肉，再配一份 VC 水果。'
          ),
        'coat' => (
            PetSignal.sleepy,
            '它舔毛的次数变多了，皮毛状态一般。',
            '加一个鸡蛋/200 ml 奶，或一小把坚果，补蛋白质和 VA。'
          ),
        'mood' => (
            PetSignal.hungry,
            '它有点蔫，最近饮食多样性不太够。',
            '今天加一份没吃过的蔬菜或水果，别只吃同一种外卖。'
          ),
        _ => (
            PetSignal.thirsty,
            '它总望着水碗，钠可能偏高了。',
            '下一餐少喝汤、少放酱；一勺酱油约等于 1.6 g 盐。'
          ),
      };
      return PetStateResult(
        axes: axes,
        signal: signal,
        message: message,
        action: action,
        drivers: axes.toJson().map((k, v) => MapEntry(k, v.toDouble())),
      );
    }

    return PetStateResult(
      axes: axes,
      signal: PetSignal.idle,
      message: '它趴在你的桌边，尾巴慢慢晃。',
      action: '今天最值得改的一件事：${eligible.last.topAction}',
      drivers: axes.toJson().map((k, v) => MapEntry(k, v.toDouble())),
    );
  }
}
