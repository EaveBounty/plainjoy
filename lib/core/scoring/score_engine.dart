import 'dart:math';

import '../models/entry.dart';
import '../models/enums.dart';
import '../models/nutrients.dart';
import '../models/profile.dart';
import '../models/score.dart';
import 'nutrient_targets.dart';

class ScoreEngine {
  static const int algoVersion = 2;

  static const _weights = <String, double>{
    'A1': 8, 'A2': 7, 'A3': 8, 'A4': 6, 'A5': 5, 'A6': 6,
    'B1': 5, 'B2': 7, 'B3': 6, 'B4': 5, 'B5': 3, 'B6': 3, 'B7': 3,
    'C1': 12, 'C2': 8, 'C3': 8, 'C4': 6, 'C5': 5,
  };

  static const _domainWeights = <ScoreDomain, double>{
    ScoreDomain.foodGroups: 40,
    ScoreDomain.nutrients: 32,
    ScoreDomain.limits: 28,
  };

  static double _ramp(double x, double x0, double x1) {
    if (x1 <= x0) return x >= x1 ? 100 : 0;
    return (100 * ((x - x0) / (x1 - x0)).clamp(0.0, 1.0)).toDouble();
  }

  static double _linearDown(double x, double x0, double x1, double y0, double y1) {
    if (x <= x0) return y0;
    if (x >= x1) return y1;
    return y0 + (y1 - y0) * ((x - x0) / (x1 - x0));
  }

  static String gradeFor(double score) {
    if (score >= 85) return 'A';
    if (score >= 70) return 'B';
    if (score >= 55) return 'C';
    return 'D';
  }

  static DayScore computeDay({
    required String date,
    required List<FoodEntry> entries,
    required HealthProfile? profile,
    bool monteCarlo = true,
    int iterations = 320,
    int seed = 20261026,
  }) {
    final targets = NutrientTargets.fromProfile(profile);
    final totals = <String, double>{};
    final groupTotals = <String, double>{};
    var itemCount = 0;
    var upfEnergy = 0.0;
    final slots = <MealSlot>{};
    final groupsCovered = <String>{};

    for (final entry in entries) {
      if (entry.deletedAt != null) continue;
      if (entry.items.isNotEmpty) slots.add(entry.slot);
      for (final item in entry.items) {
        itemCount++;
        for (final e in item.nutrientSnapshot.entries) {
          totals[e.key] = (totals[e.key] ?? 0) + e.value;
        }
        for (final e in item.groupSnapshot.entries) {
          groupTotals[e.key] = (groupTotals[e.key] ?? 0) + e.value;
          if (e.value > 0.5) groupsCovered.add(e.key);
        }
        final itemEnergy = item.nutrient(NutrientCode.energy);
        upfEnergy += itemEnergy * (item.nutrient(NutrientCode.upf) / 100).clamp(0.0, 1.0);
      }
    }

    // 数据覆盖率：按能量加权，判断某个营养素/食物组是否有足够条目支撑。
    // 缺失 ≠ 0；覆盖率不足的项直接退出评分，而不是给满分。
    final coverage = _coverage(entries, NutrientCode.all);
    final groupCoverage = _coverage(entries, FoodGroupCode.all, groups: true);
    final reasons = <String>[];
    final energy = totals[NutrientCode.energy] ?? 0;
    if (energy < targets.energy * 0.7) {
      reasons.add('能量记录不足 70%');
    }
    if (slots.length < 2) reasons.add('少于 2 个进食场合');
    if (itemCount < 5) reasons.add('少于 5 个食物条目');
    if (groupsCovered.length < 3) reasons.add('少于 3 个食物组');
    final estimableLimits = [
      (coverage[NutrientCode.sodium] ?? 0) >= 0.6,
      (coverage[NutrientCode.sugar] ?? 0) >= 0.6,
      (coverage[NutrientCode.sfa] ?? 0) >= 0.6,
    ].where((e) => e).length;
    if (estimableLimits < 2) reasons.add('限制项数据不足');

    final eligible = reasons.isEmpty;
    final upfPercent = energy > 0 ? (upfEnergy / energy * 100).clamp(0.0, 100.0) : 0.0;
    final raw = _computeScore(
      totals: totals,
      groupTotals: groupTotals,
      targets: targets,
      entryCount: itemCount,
      upfPercent: upfPercent,
      coverage: coverage,
      groupCoverage: groupCoverage,
    );

    Interval? interval;
    if (monteCarlo && itemCount > 0) {
      final random = Random(seed);
      final scores = <double>[];
      for (var i = 0; i < iterations; i++) {
        final sampledTotals = <String, double>{};
        final sampledGroups = <String, double>{};
        var sampledUpfEnergy = 0.0;
        for (final entry in entries) {
          for (final item in entry.items) {
            final factor = _sampleFactor(item, random);
            for (final e in item.nutrientSnapshot.entries) {
              sampledTotals[e.key] = (sampledTotals[e.key] ?? 0) + e.value * factor;
            }
            for (final e in item.groupSnapshot.entries) {
              sampledGroups[e.key] = (sampledGroups[e.key] ?? 0) + e.value * factor;
            }
            sampledUpfEnergy += item.nutrient(NutrientCode.energy) * factor *
                (item.nutrient(NutrientCode.upf) / 100).clamp(0.0, 1.0);
          }
        }
        final sampledEnergy = sampledTotals[NutrientCode.energy] ?? 0;
        final s = _computeScore(
          totals: sampledTotals,
          groupTotals: sampledGroups,
          targets: targets,
          entryCount: itemCount,
          upfPercent: sampledEnergy > 0
              ? (sampledUpfEnergy / sampledEnergy * 100).clamp(0.0, 100.0)
              : 0.0,
          coverage: coverage,
          groupCoverage: groupCoverage,
        );
        scores.add(s.total);
      }
      if (scores.length >= 20) {
        scores.sort();
        interval = Interval(
          p10: scores[(scores.length * 0.10).floor()],
          p50: scores[(scores.length * 0.50).floor()],
          p90: scores[(scores.length * 0.90).floor()],
        );
      }
    }

    return DayScore(
      date: date,
      total: eligible ? raw.total : null,
      interval: eligible ? interval : null,
      items: raw.items,
      domains: raw.domains,
      eligible: eligible,
      eligibilityReasons: reasons,
      totals: totals,
      groupTotals: groupTotals,
      gates: raw.gates,
      topAction: eligible ? _topAction(raw.items) : '再记一餐，就能给出完整评分。',
      entryCount: itemCount,
      algoVersion: algoVersion,
    );
  }

  static double _sampleFactor(EntryItem item, Random random) {
    final a = item.gramsP10;
    final b = item.gramsP50;
    final c = item.gramsP90;
    if (b <= 0) return 0;
    if (c <= a || (c - a) < 0.01) return 1;
    final u = random.nextDouble();
    final fc = ((b - a) / (c - a)).clamp(0.0, 1.0);
    final sample = u < fc
        ? a + sqrt(u * (c - a) * (b - a))
        : c - sqrt((1 - u) * (c - a) * (c - b));
    return (sample / b).clamp(0.2, 3.0);
  }

  /// 返回每个营养代码的「能量加权已知比例」。
  /// 0.6 以下视为数据不足：该项退出评分，而不是按 0 计。
  static Map<String, double> _coverage(
    List<FoodEntry> entries,
    List<String> codes, {
    bool groups = false,
  }) {
    final known = <String, double>{};
    var total = 0.0;
    for (final entry in entries) {
      for (final item in entry.items) {
        final energy = item.nutrient(NutrientCode.energy);
        final weight = energy > 0 ? energy : 1.0;
        total += weight;
        final map = groups ? item.groupSnapshot : item.nutrientSnapshot;
        for (final code in codes) {
          if (map.containsKey(code)) {
            known[code] = (known[code] ?? 0) + weight;
          }
        }
      }
    }
    if (total <= 0) return const {};
    return {for (final e in known.entries) e.key: e.value / total};
  }

  static _RawScore _computeScore({
    required Map<String, double> totals,
    required Map<String, double> groupTotals,
    required NutrientTargets targets,
    required int entryCount,
    double upfPercent = 0,
    Map<String, double> coverage = const {},
    Map<String, double> groupCoverage = const {},
  }) {
    final items = <ScoreItemResult>[];
    final energy = totals[NutrientCode.energy] ?? 0;

    void add({
      required String code,
      required String label,
      required ScoreDomain domain,
      required double intake,
      required double targetMin,
      required double targetMax,
      required String unit,
      required double score,
      required ScoreStatus status,
      String note = '',
      required bool known,
    }) {
      final weight = known ? (_weights[code] ?? 0) * targets.weightFor(code) : 0.0;
      items.add(ScoreItemResult(
        code: code,
        label: label,
        domain: domain,
        score: known ? score.clamp(0, 100).toDouble() : 0,
        weight: weight,
        intake: intake,
        targetMin: targetMin,
        targetMax: targetMax,
        unit: unit,
        status: known ? status : ScoreStatus.unknown,
        note: known ? note : '数据不足，本项不计分',
      ));
    }

    bool known(String key, [Map<String, double>? map]) =>
        ((map ?? coverage)[key] ?? 0) >= 0.6;

    final veg = groupTotals[FoodGroupCode.vegetable] ?? 0;
    add(
      code: 'A1',
      label: '蔬菜',
      domain: ScoreDomain.foodGroups,
      intake: veg,
      targetMin: targets.vegetable,
      targetMax: targets.vegetable * 1.5,
      unit: 'g',
      score: _ramp(veg, 0, targets.vegetable),
      status: _statusFor(veg, targets.vegetable, targets.vegetable * 1.5),
      note: veg < targets.vegetable ? '深色蔬菜占一半更好' : '',
      known: known(FoodGroupCode.vegetable, groupCoverage),
    );

    final fruit = groupTotals[FoodGroupCode.fruit] ?? 0;
    add(
      code: 'A2',
      label: '水果',
      domain: ScoreDomain.foodGroups,
      intake: fruit,
      targetMin: 200,
      targetMax: 350,
      unit: 'g',
      score: _ramp(fruit, 0, 200),
      status: _statusFor(fruit, 200, 500),
      known: known(FoodGroupCode.fruit, groupCoverage),
    );

    final wg = groupTotals[FoodGroupCode.wholeGrain] ?? 0;
    final tuber = groupTotals[FoodGroupCode.tuber] ?? 0;
    final a3 = 0.7 * _ramp(wg, 0, targets.wholeGrain) + 0.3 * _ramp(tuber, 0, targets.tuber);
    add(
      code: 'A3',
      label: '全谷杂豆 + 薯类',
      domain: ScoreDomain.foodGroups,
      intake: wg + tuber,
      targetMin: targets.wholeGrain + targets.tuber,
      targetMax: (targets.wholeGrain + targets.tuber) * 1.6,
      unit: 'g',
      score: a3,
      status: _statusFor(a3, 60, 120, isScore: true),
      note: wg < targets.wholeGrain ? '白米饭可以换半碗糙米/燕麦' : '',
      known: known(FoodGroupCode.wholeGrain, groupCoverage) || known(FoodGroupCode.tuber, groupCoverage),
    );

    final dairy = groupTotals[FoodGroupCode.dairy] ?? 0;
    add(
      code: 'A4',
      label: '奶及奶制品',
      domain: ScoreDomain.foodGroups,
      intake: dairy,
      targetMin: targets.dairy,
      targetMax: targets.dairy * 1.5,
      unit: 'g',
      score: _ramp(dairy, 0, targets.dairy),
      status: _statusFor(dairy, targets.dairy, targets.dairy * 1.5),
      note: targets.lactoseIntolerance ? '无乳糖奶/酸奶/奶酪同样计分' : '',
      known: known(FoodGroupCode.dairy, groupCoverage),
    );

    final soy = groupTotals[FoodGroupCode.soyNut] ?? 0;
    add(
      code: 'A5',
      label: '大豆及坚果',
      domain: ScoreDomain.foodGroups,
      intake: soy,
      targetMin: targets.soyNut,
      targetMax: 35,
      unit: 'g',
      score: _ramp(soy, 0, targets.soyNut),
      status: _statusFor(soy, targets.soyNut, 45),
      known: known(FoodGroupCode.soyNut, groupCoverage),
    );

    final animal = groupTotals[FoodGroupCode.animalProtein] ?? 0;
    final fish = groupTotals[FoodGroupCode.fish] ?? 0;
    final a6 = targets.vegetarian
        ? 100.0
        : 0.6 * _ramp(animal, 0, targets.animalProtein) + 0.4 * _ramp(fish, 0, targets.fish);
    add(
      code: 'A6',
      label: '鱼禽蛋瘦肉',
      domain: ScoreDomain.foodGroups,
      intake: animal,
      targetMin: targets.animalProtein,
      targetMax: targets.animalProtein * 1.6,
      unit: 'g',
      score: a6,
      status: targets.vegetarian ? ScoreStatus.ok : _statusFor(a6, 60, 120, isScore: true),
      note: targets.vegetarian ? '素食模式：以豆制品替代' : (fish < targets.fish ? '优先选鱼，一周 2 次' : ''),
      known: known(FoodGroupCode.animalProtein, groupCoverage),
    );

    final protein = totals[NutrientCode.protein] ?? 0;
    add(
      code: 'B1',
      label: '蛋白质',
      domain: ScoreDomain.nutrients,
      intake: protein,
      targetMin: targets.protein,
      targetMax: targets.protein * 2,
      unit: 'g',
      score: _ramp(protein, 0, targets.protein),
      status: _statusFor(protein, targets.protein, targets.protein * 2),
      known: known(NutrientCode.protein),
    );

    final fiber = totals[NutrientCode.fiber] ?? 0;
    add(
      code: 'B2',
      label: '膳食纤维',
      domain: ScoreDomain.nutrients,
      intake: fiber,
      targetMin: targets.fiber,
      targetMax: 40,
      unit: 'g',
      score: _ramp(fiber, 0, targets.fiber),
      status: _statusFor(fiber, targets.fiber, 40),
      known: known(NutrientCode.fiber),
    );

    final calcium = totals[NutrientCode.calcium] ?? 0;
    add(
      code: 'B3',
      label: '钙',
      domain: ScoreDomain.nutrients,
      intake: calcium,
      targetMin: targets.calcium,
      targetMax: 2000,
      unit: 'mg',
      score: _ramp(calcium, 0, targets.calcium),
      status: _statusFor(calcium, targets.calcium, 2000),
      known: known(NutrientCode.calcium),
    );

    final iron = totals[NutrientCode.iron] ?? 0;
    add(
      code: 'B4',
      label: '铁',
      domain: ScoreDomain.nutrients,
      intake: iron,
      targetMin: targets.iron,
      targetMax: 42,
      unit: 'mg',
      score: _ramp(iron, 0, targets.iron),
      status: _statusFor(iron, targets.iron, 42),
      known: known(NutrientCode.iron),
    );

    final va = totals[NutrientCode.vitaminA] ?? 0;
    add(
      code: 'B5',
      label: '维生素 A',
      domain: ScoreDomain.nutrients,
      intake: va,
      targetMin: targets.vitaminA,
      targetMax: 3000,
      unit: 'μgRAE',
      score: _ramp(va, 0, targets.vitaminA),
      status: _statusFor(va, targets.vitaminA, 3000),
      known: known(NutrientCode.vitaminA),
    );

    final vc = totals[NutrientCode.vitaminC] ?? 0;
    add(
      code: 'B6',
      label: '维生素 C',
      domain: ScoreDomain.nutrients,
      intake: vc,
      targetMin: targets.vitaminC,
      targetMax: 2000,
      unit: 'mg',
      score: _ramp(vc, 0, targets.vitaminC),
      status: _statusFor(vc, targets.vitaminC, 2000),
      known: known(NutrientCode.vitaminC),
    );

    final folate = totals[NutrientCode.folate] ?? 0;
    final b12 = totals[NutrientCode.vitaminB12] ?? 0;
    final b7 = 0.6 * _ramp(folate, 0, targets.folate) + 0.4 * _ramp(b12, 0, targets.vitaminB12);
    add(
      code: 'B7',
      label: '叶酸 + B12',
      domain: ScoreDomain.nutrients,
      intake: folate,
      targetMin: targets.folate,
      targetMax: 1000,
      unit: 'μgDFE',
      score: b7,
      status: _statusFor(b7, 60, 120, isScore: true),
      note: targets.vegetarian ? '素食尤其注意 B12 强化/补充' : '',
      known: known(NutrientCode.folate) || known(NutrientCode.vitaminB12),
    );

    final sodium = totals[NutrientCode.sodium] ?? 0;
    final sodiumScore = _sodiumScore(sodium, targets);
    final sodiumStatus = sodium <= targets.sodiumOk
        ? ScoreStatus.ok
        : (sodium <= targets.sodiumZero ? ScoreStatus.high : ScoreStatus.veryHigh);
    add(
      code: 'C1',
      label: '钠',
      domain: ScoreDomain.limits,
      intake: sodium,
      targetMin: targets.sodiumIdeal,
      targetMax: targets.sodiumOk,
      unit: 'mg',
      score: sodiumScore,
      status: sodiumStatus,
      note: sodium > targets.sodiumOk ? '≈盐 ${(sodium / 393.7).toStringAsFixed(1)} g' : '',
      known: known(NutrientCode.sodium),
    );

    final sugar = totals[NutrientCode.sugar] ?? 0;
    final sugarScore = _sugarScore(sugar, targets.sugarLimit);
    final sugarStatus = sugar <= targets.sugarLimit
        ? ScoreStatus.ok
        : (sugar <= targets.sugarLimit * 2 ? ScoreStatus.high : ScoreStatus.veryHigh);
    add(
      code: 'C2',
      label: '添加糖',
      domain: ScoreDomain.limits,
      intake: sugar,
      targetMin: 0,
      targetMax: targets.sugarLimit,
      unit: 'g',
      score: sugarScore,
      status: sugarStatus,
      note: sugar > targets.sugarLimit ? '甜饮/酱料是主要来源' : '',
      known: known(NutrientCode.sugar),
    );

    final sfa = totals[NutrientCode.sfa] ?? 0;
    final tfa = totals[NutrientCode.tfa] ?? 0;
    final sfaPct = energy > 0 ? 100 * sfa * 9 / energy : 0.0;
    final tfaPct = energy > 0 ? 100 * tfa * 9 / energy : 0.0;
    final sfaScore = _linearDown(sfaPct, 7, 20, 100, 0);
    final tfaScore = _linearDown(tfaPct, 1, 2, 100, 0);
    final fatScore = 0.7 * sfaScore + 0.3 * tfaScore;
    add(
      code: 'C3',
      label: '脂肪质量',
      domain: ScoreDomain.limits,
      intake: sfa,
      targetMin: 0,
      targetMax: targets.sfaLimitG,
      unit: 'g',
      score: fatScore,
      status: sfaPct <= 10 && tfaPct <= 1
          ? ScoreStatus.ok
          : (sfaPct <= 20 ? ScoreStatus.high : ScoreStatus.veryHigh),
      note: '饱和脂肪 ${sfaPct.toStringAsFixed(1)}%E · 反式 ${tfaPct.toStringAsFixed(1)}%E',
      known: known(NutrientCode.sfa),
    );

    // CKD 专属限制项：血钾/血磷。只在 target 明确设为上限时纳入，
    // 普通人群不因「钾高」扣分（高钾食物通常是好事）。
    if (targets.limitPotassium && targets.potassium != null) {
      final k = totals[NutrientCode.potassium] ?? 0;
      final cap = targets.potassium!;
      final kScore = k <= cap ? 100.0 : _linearDown(k, cap, cap * 1.5, 100, 0);
      add(
        code: 'C4',
        label: '钾（肾病上限）',
        domain: ScoreDomain.limits,
        intake: k,
        targetMin: 0,
        targetMax: cap,
        unit: 'mg',
        score: kScore,
        status: k <= cap ? ScoreStatus.ok : (k <= cap * 1.2 ? ScoreStatus.high : ScoreStatus.veryHigh),
        note: '上限需按血钾调整；低钠盐、代盐常含钾',
        known: known(NutrientCode.potassium),
      );
    }
    if (targets.limitPhosphorus && targets.phosphorus != null) {
      final ph = totals[NutrientCode.phosphorus] ?? 0;
      final cap = targets.phosphorus!;
      final phScore = ph <= cap ? 100.0 : _linearDown(ph, cap, cap * 1.4, 100, 0);
      add(
        code: 'C5',
        label: '磷（肾病上限）',
        domain: ScoreDomain.limits,
        intake: ph,
        targetMin: 0,
        targetMax: cap,
        unit: 'mg',
        score: phScore,
        status: ph <= cap ? ScoreStatus.ok : (ph <= cap * 1.2 ? ScoreStatus.high : ScoreStatus.veryHigh),
        note: '加工食品的磷酸盐添加剂吸收率更高',
        known: known(NutrientCode.phosphorus),
      );
    }

    final domains = <DomainScore>[];
    for (final domain in ScoreDomain.values) {
      final domainItems = items.where((e) => e.domain == domain).toList();
      final weightSum = domainItems.fold<double>(0, (a, b) => a + b.weight);
      final weighted = domainItems.fold<double>(0, (a, b) => a + b.score * b.weight);
      domains.add(DomainScore(
        domain: domain,
        score: weightSum == 0 ? 0 : weighted / weightSum,
        // 全项无数据时把域权重置 0，总分按剩余域重新归一化
        weight: weightSum == 0 ? 0 : (_domainWeights[domain] ?? 0),
      ));
    }

    final activeWeight = domains.fold<double>(0, (a, b) => a + b.weight);
    final totalRaw = activeWeight == 0
        ? 0.0
        : domains.fold<double>(0, (a, b) => a + b.score * b.weight) / activeWeight;

    final gates = <ScoreGate>[
      ScoreGate(
        code: 'low_food_groups',
        label: '食物结构偏弱',
        cap: domains[0].score < 25 ? 45 : 55,
        triggered: domains[0].weight > 0 && domains[0].score < 40,
      ),
      ScoreGate(
        code: 'sodium_high',
        label: '钠过高',
        cap: 70,
        triggered: known(NutrientCode.sodium) && sodiumScore < 30,
      ),
      ScoreGate(
        code: 'limits_high',
        label: '限制项整体失控',
        cap: 60,
        triggered: domains[2].weight > 0 && domains[2].score < 30,
      ),
      ScoreGate(
        code: 'upf_50',
        label: '超加工食品供能 >50%',
        cap: 75,
        triggered: upfPercent > 50,
      ),
      ScoreGate(
        code: 'upf_70',
        label: '超加工食品供能 >70%',
        cap: 60,
        triggered: upfPercent > 70,
      ),
    ].where((gate) => gate.triggered).toList();

    var total = totalRaw;
    for (final gate in gates) {
      total = min(total, gate.cap);
    }

    return _RawScore(
      items: items,
      domains: domains,
      total: total.clamp(0, 100).toDouble(),
      gates: gates,
      upfPercent: upfPercent,
    );
  }

  static double _sodiumScore(double sodium, NutrientTargets t) {
    if (sodium <= t.sodiumIdeal) return 100;
    if (sodium <= t.sodiumOk) {
      return _linearDown(sodium, t.sodiumIdeal, t.sodiumOk, 100, 85);
    }
    if (sodium <= t.sodiumZero) {
      return _linearDown(sodium, t.sodiumOk, t.sodiumZero, 85, 0);
    }
    return 0;
  }

  static double _sugarScore(double sugar, double limit) {
    if (sugar <= limit * 0.5) return 100;
    if (sugar <= limit) return _linearDown(sugar, limit * 0.5, limit, 100, 60);
    if (sugar <= limit * 2) return _linearDown(sugar, limit, limit * 2, 60, 0);
    return 0;
  }

  static ScoreStatus _statusFor(
    double value,
    double good,
    double high, {
    bool isScore = false,
  }) {
    if (isScore) {
      if (value >= 80) return ScoreStatus.ok;
      if (value >= 50) return ScoreStatus.low;
      return ScoreStatus.low;
    }
    if (value < good * 0.85) return ScoreStatus.low;
    if (value > high * 1.3) return ScoreStatus.veryHigh;
    if (value > high) return ScoreStatus.high;
    return ScoreStatus.ok;
  }

  static String _topAction(List<ScoreItemResult> items) {
    final candidates = items.where((e) => e.weight > 0 && e.score < 85).toList()
      ..sort((a, b) => b.lostPoints.compareTo(a.lostPoints));
    if (candidates.isEmpty) {
      return '今天结构不错。可以提前准备明天的早餐，别让缺口从早上开始。';
    }
    final item = candidates.first;
    final action = switch (item.code) {
      'A1' => '加一拳绿叶菜（约 100–150 g），蔬菜分就上来了。',
      'A2' => '加一个苹果或一小碗莓果（约 150 g），别用果汁替代。',
      'A3' => '白米饭换半碗糙米/燕麦，或加一小块红薯。',
      'A4' => '加一杯无糖酸奶或 200 ml 奶；乳糖不耐换无乳糖奶。',
      'A5' => '加一小把坚果（约 10 g）或一块豆腐。',
      'A6' => '加一掌心鱼/鸡胸/瘦肉（约 75–100 g），优先选鱼。',
      'B1' => '加一个鸡蛋或 100 g 鸡胸，蛋白质大约 +12–25 g。',
      'B2' => '加一份绿叶菜 + 半碗杂粮饭，纤维大约 +6–9 g。',
      'B3' => '加 200 ml 奶/无糖酸奶，或一块北豆腐，钙大约 +200–300 mg。',
      'B4' => '加 50 g 瘦牛肉/猪肝（每周一次）+ 一份 VC 水果，帮助铁吸收。',
      'B5' => '加一份胡萝卜/南瓜/深绿叶菜，VA 大约 +200–400 μgRAE。',
      'B6' => '加一个猕猴桃/半个彩椒，VC 大约 +60–100 mg。',
      'B7' => '加一份深绿叶菜 + 一个鸡蛋；素食者注意 B12 强化。',
      'C1' => '下一餐少喝汤/少放酱；一勺酱油约等于 1.6 g 盐。',
      'C2' => '把甜饮换成无糖茶/白水；一瓶甜饮约 30–50 g 糖。',
      'C3' => '少一次煎炸，换蒸/煮/烤；肥肉和酥皮是饱和脂肪大户。',
      'C4' => '钾已超保守上限：先停低钠盐/代盐，把水果和汤的分量交给医生确认。',
      'C5' => '磷偏高：少加工肉、可乐、火锅底料；优先新鲜肉蛋和米饭。',
      _ => '把下一餐的蔬菜和蛋白质补上，比纠结总分更有用。',
    };
    return '${item.label}：$action';
  }
}

class _RawScore {
  final List<ScoreItemResult> items;
  final List<DomainScore> domains;
  final double total;
  final List<ScoreGate> gates;
  final double upfPercent;

  const _RawScore({
    required this.items,
    required this.domains,
    required this.total,
    required this.gates,
    required this.upfPercent,
  });
}
