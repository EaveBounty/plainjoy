import '../health/condition_policy.dart';
import '../models/enums.dart';
import '../models/profile.dart';
import '../models/nutrients.dart';

class NutrientTargets {
  final double energy;
  final double protein;
  final double fiber;
  final double calcium;
  final double iron;
  final double vitaminA;
  final double vitaminC;
  final double folate;
  final double vitaminB12;
  final double sodiumIdeal;
  final double sodiumOk;
  final double sodiumZero;
  final double sugarExcellent;
  final double sugarLimit;
  final double sfaLimitG;
  final double tfaLimitG;
  final double vegetable;
  final double fruit;
  final double wholeGrain;
  final double tuber;
  final double dairy;
  final double soyNut;
  final double animalProtein;
  final double fish;
  final bool hypertension;
  final bool vegetarian;
  final bool lactoseIntolerance;

  // 个性化扩展目标（缺失时为 null，表示「不适用/未知」）
  final double? potassium;
  final double? phosphorus;
  final double? magnesium;
  final double? iodine;
  final double? cholesterolLimit;
  final double? water;
  final bool limitPotassium;
  final bool limitPhosphorus;
  final bool purineSensitive;
  final List<ConditionPolicy> policies;
  final Map<String, double> weightMultipliers;

  const NutrientTargets({
    required this.energy,
    required this.protein,
    required this.fiber,
    required this.calcium,
    required this.iron,
    required this.vitaminA,
    required this.vitaminC,
    required this.folate,
    required this.vitaminB12,
    required this.sodiumIdeal,
    required this.sodiumOk,
    required this.sodiumZero,
    required this.sugarExcellent,
    required this.sugarLimit,
    required this.sfaLimitG,
    required this.tfaLimitG,
    required this.vegetable,
    required this.fruit,
    required this.wholeGrain,
    required this.tuber,
    required this.dairy,
    required this.soyNut,
    required this.animalProtein,
    required this.fish,
    required this.hypertension,
    required this.vegetarian,
    required this.lactoseIntolerance,
    this.potassium,
    this.phosphorus,
    this.magnesium,
    this.iodine,
    this.cholesterolLimit,
    this.water,
    this.limitPotassium = false,
    this.limitPhosphorus = false,
    this.purineSensitive = false,
    this.policies = const [],
    this.weightMultipliers = const {},
  });

  /// 病况叠加后的目标覆盖；没有病况时返回基础目标。
  double weightFor(String code) => weightMultipliers[code] ?? 1.0;

  NutrientGoal? goalFor(String code) {
    for (final policy in policies) {
      final goal = policy.goals[code];
      if (goal != null) return goal;
    }
    return null;
  }

  factory NutrientTargets.fromProfile(HealthProfile? profile) {
    final p = profile ??
        const HealthProfile(
          id: 'default',
          nickname: '我',
          sex: Sex.preferNot,
          activity: ActivityLevel.light,
          goal: Goal.maintain,
        );
    final age = p.age ?? 25;
    final isMale = p.sex == Sex.male;
    final height = p.heightCm ?? (isMale ? 172.0 : 160.0);
    final weight = p.weightKg ?? (isMale ? 68.0 : 56.0);
    final bmr = isMale
        ? 10 * weight + 6.25 * height - 5 * age + 5
        : 10 * weight + 6.25 * height - 5 * age - 161;
    var energy = bmr * p.activity.pal;
    if (p.goal == Goal.lose) energy *= 0.85;
    if (p.goal == Goal.gain) energy *= 1.10;
    if (p.pregnant) energy += 300;
    if (p.lactating) energy += 500;
    energy = energy.clamp(1200, 4000).toDouble();

    final proteinBase = isMale ? 65.0 : 55.0;
    final proteinByWeight = weight * (p.goal == Goal.gain ? 1.4 : 1.1);
    final protein = (p.targetProteinOverride ?? [proteinBase, proteinByWeight].reduce((a, b) => a > b ? a : b))
        .clamp(40, 180)
        .toDouble();

    final hypertension = p.has(Condition.hypertension);
    final policies = ConditionPolicies.forProfile(p);
    final goals = ConditionPolicies.mergeGoals(policies);
    final weights = ConditionPolicies.mergeWeights(policies);

    var sodiumOk = p.targetSodiumOverride ?? (hypertension ? 2000.0 : 2000.0);
    var sodiumIdeal = hypertension ? 1500.0 : 1500.0;
    var sodiumZero = hypertension ? 3000.0 : 4000.0;
    var fiber = 25.0;
    var calcium = 800.0;
    var iron = (isMale ? 12.0 : (age >= 50 ? 10.0 : 18.0));
    var folate = p.pregnant ? 600.0 : 400.0;
    var vitaminC = 100.0;
    var vitaminB12 = 2.4;
    var proteinTarget = protein;
    var sugarLimit = (0.10 * energy / 4).clamp(20.0, 50.0).toDouble();
    var potassium = 2000.0;
    var phosphorus = 720.0;
    var magnesium = isMale ? 330.0 : 270.0;
    var iodine = p.pregnant ? 230.0 : (p.lactating ? 240.0 : 120.0);
    var cholesterolLimit = 300.0;
    var water = p.lactating ? 2500.0 : 1700.0;

    void applyGoal(String code, void Function(NutrientGoal) apply) {
      final goal = goals[code];
      if (goal != null) apply(goal);
    }

    applyGoal(NutrientCode.sodium, (g) {
      if (g.max != null) sodiumOk = g.max!;
      if (g.min != null && g.min! > 0) sodiumIdeal = g.min!;
      sodiumIdeal = sodiumIdeal.clamp(0, sodiumOk).toDouble();
      sodiumZero = sodiumOk * 1.5;
    });
    applyGoal(NutrientCode.fiber, (g) => fiber = g.min ?? fiber);
    applyGoal(NutrientCode.calcium, (g) => calcium = g.min ?? calcium);
    applyGoal(NutrientCode.iron, (g) => iron = g.min ?? iron);
    applyGoal(NutrientCode.folate, (g) => folate = g.min ?? folate);
    applyGoal(NutrientCode.vitaminC, (g) => vitaminC = g.min ?? vitaminC);
    applyGoal(NutrientCode.vitaminB12, (g) => vitaminB12 = g.min ?? vitaminB12);
    applyGoal(NutrientCode.protein, (g) {
      // 肾病给的是保守区间；下限不高于基础值，避免把蛋白压得过低
      if (g.max != null) proteinTarget = (proteinTarget).clamp(0, g.max!);
      if (g.min != null) proteinTarget = proteinTarget < g.min! ? g.min! : proteinTarget;
    });
    applyGoal(NutrientCode.sugar, (g) => sugarLimit = g.max ?? sugarLimit);
    applyGoal(NutrientCode.potassium, (g) => potassium = g.max ?? g.min ?? potassium);
    applyGoal(NutrientCode.phosphorus, (g) => phosphorus = g.max ?? g.min ?? phosphorus);
    applyGoal(NutrientCode.iodine, (g) => iodine = g.min ?? iodine);
    applyGoal(NutrientCode.water, (g) => water = g.min ?? water);

    // 孕期/哺乳先加量，CKD 再按体重与透析状态覆盖（肾病优先，避免叠加后越界）
    if (p.pregnant) proteinTarget += 20;
    if (p.lactating) proteinTarget = proteinTarget < 80 ? 80 : proteinTarget;
    if (p.has(Condition.ckd)) {
      proteinTarget = p.ckdDialysis ? 1.1 * weight : 0.8 * weight;
    }

    final sfaLimitG = 0.10 * energy / 9;
    final tfaLimitG = 0.01 * energy / 9;

    final scale = (energy / 2000).clamp(0.8, 1.2).toDouble();
    final vegetarian = p.isVegetarian;
    final sodiumIdealFinal = sodiumIdeal;
    final sodiumOkFinal = sodiumOk;
    final sodiumZeroFinal = sodiumZero;
    final proteinFinal = proteinTarget;
    final fiberFinal = fiber;
    final calciumFinal = calcium;
    final ironFinal = iron;
    final folateFinal = folate;
    final vitaminCFinal = vitaminC;
    final vitaminB12Final = vitaminB12;
    final sugarLimitFinal = sugarLimit;

    return NutrientTargets(
      energy: energy,
      protein: proteinFinal,
      fiber: fiberFinal,
      calcium: calciumFinal,
      iron: ironFinal,
      vitaminA: isMale ? 770 : 660,
      vitaminC: vitaminCFinal,
      folate: folateFinal,
      vitaminB12: vitaminB12Final,
      sodiumIdeal: sodiumIdealFinal,
      sodiumOk: sodiumOkFinal,
      sodiumZero: sodiumZeroFinal,
      sugarExcellent: sugarLimitFinal * 0.5,
      sugarLimit: sugarLimitFinal,
      sfaLimitG: sfaLimitG,
      tfaLimitG: tfaLimitG,
      vegetable: 300,
      fruit: 250,
      wholeGrain: 50 * scale,
      tuber: 50 * scale,
      dairy: 300,
      soyNut: 25,
      animalProtein: vegetarian ? 0 : 120 * scale,
      fish: vegetarian ? 0 : 40 * scale,
      hypertension: hypertension,
      vegetarian: vegetarian,
      lactoseIntolerance: p.has(Condition.lactoseIntolerance),
      potassium: potassium,
      phosphorus: phosphorus,
      magnesium: magnesium,
      iodine: iodine,
      cholesterolLimit: cholesterolLimit,
      water: water,
      limitPotassium: ConditionPolicies.any(policies, (e) => e.limitPotassium),
      limitPhosphorus: ConditionPolicies.any(policies, (e) => e.limitPhosphorus),
      purineSensitive: ConditionPolicies.any(policies, (e) => e.purineSensitive),
      policies: policies,
      weightMultipliers: weights,
    );
  }

  Map<String, double> get asMap {
    final map = <String, double>{
      NutrientCode.energy: energy,
      NutrientCode.protein: protein,
      NutrientCode.fiber: fiber,
      NutrientCode.calcium: calcium,
      NutrientCode.iron: iron,
      NutrientCode.vitaminA: vitaminA,
      NutrientCode.vitaminC: vitaminC,
      NutrientCode.folate: folate,
      NutrientCode.vitaminB12: vitaminB12,
      NutrientCode.sodium: sodiumOk,
      NutrientCode.sugar: sugarLimit,
      NutrientCode.sfa: sfaLimitG,
    };
    void put(String code, double? value) {
      if (value != null) map[code] = value;
    }

    put(NutrientCode.potassium, potassium);
    put(NutrientCode.phosphorus, phosphorus);
    put(NutrientCode.magnesium, magnesium);
    put(NutrientCode.iodine, iodine);
    put(NutrientCode.cholesterol, cholesterolLimit);
    put(NutrientCode.water, water);
    return map;
  }
}
