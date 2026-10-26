import 'dart:math';

import '../models/container.dart';
import '../models/enums.dart';
import '../models/food.dart';

class PortionEstimate {
  final double gramsP10;
  final double gramsP50;
  final double gramsP90;
  final EstimateMethod method;
  final double confidence;
  final String explanation;
  final String? containerId;
  final String? referenceObjectId;

  const PortionEstimate({
    required this.gramsP10,
    required this.gramsP50,
    required this.gramsP90,
    required this.method,
    required this.confidence,
    required this.explanation,
    this.containerId,
    this.referenceObjectId,
  });

  String get display {
    if (gramsP50 >= 100) return '≈ ${gramsP50.round()} g（${gramsP10.round()}–${gramsP90.round()}）';
    return '≈ ${gramsP50.toStringAsFixed(0)} g（${gramsP10.toStringAsFixed(0)}–${gramsP90.toStringAsFixed(0)}）';
  }
}

class PortionEstimator {
  static double densityForFood(Food food) {
    return switch (food.category) {
      'staple' => 0.85,
      'vegetable' => 0.35,
      'fruit' => 0.65,
      'meat' => 0.95,
      'fish' => 0.95,
      'egg' => 1.0,
      'dairy' => 1.0,
      'bean' => 0.9,
      'nut' => 0.6,
      'soup' || 'dish' => 0.75,
      'drink' => 1.0,
      'condiment' => 1.0,
      _ => 0.8,
    };
  }

  static PortionEstimate fromWeighed(Food food, double grams) {
    final g = max(0.0, grams);
    return PortionEstimate(
      gramsP10: g * 0.97,
      gramsP50: g,
      gramsP90: g * 1.03,
      method: EstimateMethod.weighed,
      confidence: 0.95,
      explanation: '按秤重记录，误差主要来自剩饭和容器去皮。',
    );
  }

  static PortionEstimate fromContainer({
    required Food food,
    required FoodContainer container,
    double? fillRatio,
    double? density,
  }) {
    final fill = (fillRatio ?? container.fillRatio).clamp(0.05, 1.0);
    final d = density ?? densityForFood(food);
    final grams = container.capacityMl * fill * d;
    final spread = 0.18 + (1 - fill) * 0.08;
    return PortionEstimate(
      gramsP10: grams * (1 - spread),
      gramsP50: grams,
      gramsP90: grams * (1 + spread),
      method: EstimateMethod.container,
      confidence: 0.72,
      explanation: '按「${container.name}」${(fill * 100).round()}% 满、密度 ${d.toStringAsFixed(2)} g/ml 估算。换容器或换食物类别时误差会变大。',
      containerId: container.id,
    );
  }

  static PortionEstimate fromReference({
    required Food food,
    required ReferenceObject reference,
    int count = 1,
  }) {
    final base = referenceGrams(food, reference);
    final grams = base * count;
    return PortionEstimate(
      gramsP10: grams * 0.75,
      gramsP50: grams,
      gramsP90: grams * 1.3,
      method: EstimateMethod.reference,
      confidence: 0.55,
      explanation: '按「$count × ${reference.name}」估算：${reference.hint}。形状、厚度、压实程度都会影响结果。',
      referenceObjectId: reference.id,
    );
  }

  static double referenceGrams(Food food, ReferenceObject reference) {
    final name = reference.name;
    if (name.contains('手掌')) {
      return switch (food.category) {
        'meat' || 'fish' => 85,
        'vegetable' => 50,
        'staple' => 100,
        _ => 80,
      };
    }
    if (name.contains('拳头')) {
      return switch (food.category) {
        'vegetable' => 120,
        'fruit' => 150,
        'staple' => 150,
        _ => 100,
      };
    }
    if (name.contains('拇指')) {
      return switch (food.category) {
        'condiment' || 'nut' => 10,
        _ => 15,
      };
    }
    if (name.contains('扑克牌')) return 75;
    if (name.contains('手机')) return 100;
    if (name.contains('硬币')) return 5;
    if (name.contains('一次性')) return 250;
    return food.defaultServingGrams ?? 100;
  }

  static PortionEstimate fromOrdinal({
    required Food food,
    required PrecisionTier tier,
    required int ordinal, // 1=少, 2=中, 3=多
    double leftover = 0,
    double? personalMedian,
  }) {
    final base = personalMedian ?? food.defaultServingGrams ?? _defaultByCategory(food.category);
    final multiplier = switch (ordinal.clamp(1, 3)) {
      1 => 0.6,
      2 => 1.0,
      _ => 1.5,
    };
    final grams = base * multiplier * (1 - leftover.clamp(0.0, 1.0));
    final spread = switch (tier) {
      PrecisionTier.quick => 0.40,
      PrecisionTier.standard => 0.24,
      PrecisionTier.precise => 0.10,
    };
    return PortionEstimate(
      gramsP10: grams * (1 - spread),
      gramsP50: grams,
      gramsP90: grams * (1 + spread),
      method: switch (tier) {
        PrecisionTier.quick => EstimateMethod.visual,
        PrecisionTier.standard => EstimateMethod.reference,
        PrecisionTier.precise => EstimateMethod.weighed,
      },
      confidence: switch (tier) {
        PrecisionTier.quick => 0.35,
        PrecisionTier.standard => 0.6,
        PrecisionTier.precise => 0.85,
      },
      explanation: _ordinalExplanation(tier, ordinal, leftover),
    );
  }

  static PortionEstimate fromVisualGuess({
    required Food food,
    required double grams,
    required PrecisionTier tier,
  }) {
    final spread = tier == PrecisionTier.quick ? 0.35 : 0.22;
    return PortionEstimate(
      gramsP10: grams * (1 - spread),
      gramsP50: grams,
      gramsP90: grams * (1 + spread),
      method: EstimateMethod.visual,
      confidence: tier == PrecisionTier.quick ? 0.4 : 0.6,
      explanation: '按目测估算。可以在下一次用同一个碗对比，校准自己的眼睛。',
    );
  }

  static double _defaultByCategory(String category) {
    return switch (category) {
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

  static String _ordinalExplanation(PrecisionTier tier, int ordinal, double leftover) {
    final level = switch (ordinal.clamp(1, 3)) {
      1 => '少',
      2 => '中',
      _ => '多',
    };
    final left = leftover <= 0 ? '' : '，扣除剩饭 ${(leftover * 100).round()}%';
    return switch (tier) {
      PrecisionTier.quick => '按「$level」份估算$left。这是 10 秒档，误差约 ±35–45%。',
      PrecisionTier.standard => '按「$level」份 + 参照物估算$left。误差约 ±20–25%。',
      PrecisionTier.precise => '按精确份量$left。误差约 ±8–10%。',
    };
  }
}
