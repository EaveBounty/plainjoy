import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:plainjoy/core/ai/ai_service.dart';
import 'package:plainjoy/core/health/health_rules.dart';
import 'package:plainjoy/core/models/app_data.dart';
import 'package:plainjoy/core/models/container.dart';
import 'package:plainjoy/core/models/entry.dart';
import 'package:plainjoy/core/models/enums.dart';
import 'package:plainjoy/core/models/food.dart';
import 'package:plainjoy/core/models/plan.dart';
import 'package:plainjoy/core/models/profile.dart';
import 'package:plainjoy/core/models/settings.dart';
import 'package:plainjoy/core/db/app_repository.dart';
import 'package:plainjoy/core/health/advice_engine.dart';
import 'package:plainjoy/core/plan/plan_engine.dart';
import 'package:plainjoy/core/portion/portion_estimator.dart';
import 'package:plainjoy/core/scoring/nutrient_targets.dart';
import 'package:plainjoy/core/scoring/score_engine.dart';

Food food(
  String id,
  String name, {
  String category = 'other',
  double kcal = 100,
  double protein = 5,
  double fat = 2,
  double carb = 10,
  double fiber = 2,
  double sodium = 50,
  double calcium = 50,
  double iron = 1,
  double va = 100,
  double vc = 20,
  double folate = 50,
  double b12 = 0.5,
  double sugar = 0,
  double sfa = 1,
  double tfa = 0,
  double upf = 0,
  Map<String, double> groups = const {},
  List<String> aliases = const [],
  List<String> tags = const [],
}) {
  return Food(
    id: id,
    name: name,
    category: category,
    source: 'test',
    nutrientsPer100g: {
      'energy_kcal': kcal,
      'protein_g': protein,
      'fat_g': fat,
      'carb_g': carb,
      'fiber_g': fiber,
      'sodium_mg': sodium,
      'calcium_mg': calcium,
      'iron_mg': iron,
      'va_ug': va,
      'vc_mg': vc,
      'folate_ug': folate,
      'vb12_ug': b12,
      'sugar_g': sugar,
      'sfa_g': sfa,
      'tfa_g': tfa,
      'upf_pct': upf,
    },
    groupsPer100g: groups,
    aliases: aliases,
    tags: tags,
    createdAt: 0,
    updatedAt: 0,
  );
}

EntryItem item(Food f, double grams, {EstimateMethod method = EstimateMethod.weighed}) {
  return EntryItem.fromFood(
    id: '${f.id}-$grams',
    food: f,
    gramsP10: grams * 0.9,
    gramsP50: grams,
    gramsP90: grams * 1.1,
    method: method,
    confidence: 0.8,
  );
}

FoodEntry entry(
  String id,
  String date,
  MealSlot slot,
  List<EntryItem> items,
) {
  return FoodEntry(
    id: id,
    profileId: 'p',
    eatenAtMs: 0,
    localDate: date,
    slot: slot,
    inputMode: InputMode.manual,
    items: items,
    createdAt: 0,
    updatedAt: 0,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const profile = HealthProfile(
    id: 'p',
    nickname: '测试',
    sex: Sex.female,
    activity: ActivityLevel.light,
    goal: Goal.maintain,
  );

  final rice = food('rice', '米饭', category: 'staple', kcal: 116, protein: 2.6, carb: 25.9,
      fiber: 0.3, sodium: 2, groups: {'refined_grain': 100});
  final chicken = food('chicken', '鸡胸肉', category: 'meat', kcal: 133, protein: 24, fat: 3.5,
      sodium: 60, iron: 0.7, b12: 0.3, groups: {'animal_protein': 100}, aliases: ['鸡肉']);
  final broccoli = food('broccoli', '西兰花', category: 'vegetable', kcal: 34, protein: 2.8,
      fiber: 2.6, sodium: 33, calcium: 47, iron: 0.7, vc: 89, va: 31, folate: 63,
      groups: {'vegetable': 100});
  final milk = food('milk', '牛奶', category: 'dairy', kcal: 54, protein: 3, fat: 3.2,
      sodium: 37, calcium: 104, b12: 0.4, groups: {'dairy': 100}, aliases: ['奶']);
  final apple = food('apple', '苹果', category: 'fruit', kcal: 52, protein: 0.3,
      fiber: 2.4, sodium: 1, vc: 4.6, groups: {'fruit': 100});
  final beef = food('beef', '瘦牛肉', category: 'meat', kcal: 250, protein: 26,
      fat: 15, sodium: 72, iron: 2.6, b12: 1.5, groups: {'animal_protein': 100},
      aliases: ['牛肉']);
  final salt = food('salt', '盐', category: 'condiment', kcal: 0, protein: 0, fat: 0,
      carb: 0, fiber: 0, sodium: 39300, calcium: 0, iron: 0, va: 0, vc: 0, folate: 0,
      b12: 0, sugar: 0, sfa: 0, tags: ['high_sodium']);

  final foods = {rice.id: rice, chicken.id: chicken, broccoli.id: broccoli, milk.id: milk, apple.id: apple, beef.id: beef, salt.id: salt};

  test('day score is eligible and bounded', () {
    final entries = [
      entry('e1', '2026-10-26', MealSlot.breakfast, [item(milk, 300), item(apple, 200)]),
      entry('e2', '2026-10-26', MealSlot.lunch, [item(rice, 300), item(chicken, 200), item(broccoli, 200)]),
      entry('e3', '2026-10-26', MealSlot.snack, [item(rice, 200), item(apple, 200)]),
    ];
    final score = ScoreEngine.computeDay(date: '2026-10-26', entries: entries, profile: profile);
    expect(score.eligible, isTrue, reason: score.eligibilityReasons.join(','));
    expect(score.total, isNotNull);
    expect(score.total!, inInclusiveRange(0, 100));
    expect(score.items.length, 16);
    expect(score.domains.length, 3);
    expect(score.interval, isNotNull);
    expect(score.interval!.p10, lessThanOrEqualTo(score.interval!.p90));
  });

  test('sodium gate caps total', () {
    final entries = [
      entry('e1', '2026-10-26', MealSlot.breakfast, [item(milk, 300), item(apple, 200)]),
      entry('e2', '2026-10-26', MealSlot.lunch, [item(rice, 300), item(chicken, 200), item(broccoli, 200), item(salt, 10)]),
      entry('e3', '2026-10-26', MealSlot.snack, [item(rice, 200), item(apple, 200)]),
    ];
    final score = ScoreEngine.computeDay(date: '2026-10-26', entries: entries, profile: profile);
    final sodium = score.items.firstWhere((e) => e.code == 'C1');
    expect(sodium.score, 0);
    expect(score.gates.any((g) => g.code == 'sodium_high'), isTrue);
    expect(score.total!, lessThanOrEqualTo(70));
  });

  test('insufficient records are not scored', () {
    final entries = [entry('e1', '2026-10-26', MealSlot.snack, [item(apple, 100)])];
    final score = ScoreEngine.computeDay(date: '2026-10-26', entries: entries, profile: profile);
    expect(score.eligible, isFalse);
    expect(score.total, isNull);
    expect(score.eligibilityReasons, isNotEmpty);
  });

  test('container and ordinal estimates keep ranges', () {
    const container = FoodContainer(id: 'c', name: '碗', capacityMl: 250, fillRatio: 0.8);
    final containerEstimate = PortionEstimator.fromContainer(food: rice, container: container);
    expect(containerEstimate.gramsP50, closeTo(170, 1));
    expect(containerEstimate.gramsP10, lessThan(containerEstimate.gramsP50));
    expect(containerEstimate.gramsP90, greaterThan(containerEstimate.gramsP50));

    final quick = PortionEstimator.fromOrdinal(
      food: rice,
      tier: PrecisionTier.quick,
      ordinal: 2,
      leftover: 0.5,
    );
    expect(quick.gramsP50, closeTo(75, 1));
    expect(quick.gramsP10, lessThan(quick.gramsP50));
    expect(quick.gramsP90, greaterThan(quick.gramsP50));
  });

  test('local parser matches aliases and grams', () async {
    final service = AiService(settings: const AppSettings(aiEnabled: false), foods: foods.values.toList());
    final result = await service.parseText('牛肉 100g + 米饭 200g');
    expect(result.items.length, 2);
    expect(result.items.any((e) => e.foodId == 'beef'), isTrue);
    expect(result.items.any((e) => e.name == '米饭'), isTrue);
  });

  test('health rules cover hypertension', () {
    const p = HealthProfile(
      id: 'p',
      nickname: '测试',
      sex: Sex.male,
      activity: ActivityLevel.light,
      goal: Goal.maintain,
      conditions: {Condition.hypertension},
    );
    final rules = HealthRules.forProfile(p);
    expect(rules.any((e) => e.category == HealthRuleCategory.limit), isTrue);
    expect(rules.any((e) => e.category == HealthRuleCategory.recommend), isTrue);
    expect(rules.any((e) => e.category == HealthRuleCategory.seeDoctor), isTrue);
  });

  test('plan engine produces distinct patch meals', () {
    final recipes = [
      Recipe(
        id: 'r1',
        name: '鸡胸西兰花',
        category: 'lunch',
        ingredients: [RecipeIngredient(foodId: 'chicken', grams: 120), RecipeIngredient(foodId: 'broccoli', grams: 150)],
        equipment: const ['induction'],
        minutes: 15,
        costYuan: 15,
        steps: const ['炒'],
        tasteTags: const ['清淡'],
      ),
      Recipe(
        id: 'r2',
        name: '牛奶燕麦',
        category: 'breakfast',
        ingredients: [RecipeIngredient(foodId: 'milk', grams: 250), RecipeIngredient(foodId: 'rice', grams: 50)],
        equipment: const ['microwave'],
        minutes: 5,
        costYuan: 8,
        steps: const ['微波'],
        tasteTags: const ['清淡'],
      ),
      Recipe(
        id: 'r3',
        name: '苹果酸奶',
        category: 'snack',
        ingredients: [RecipeIngredient(foodId: 'apple', grams: 150), RecipeIngredient(foodId: 'milk', grams: 150)],
        equipment: const [],
        minutes: 2,
        costYuan: 8,
        steps: const ['混合'],
        tasteTags: const ['免煮'],
        isNoCook: true,
      ),
    ];
    final data = AppData(
      foods: foods.values.toList(),
      recipes: recipes,
      profile: profile,
    );
    final entries = [
      entry('e1', '2026-10-26', MealSlot.breakfast, [item(milk, 250), item(apple, 150)]),
      entry('e2', '2026-10-26', MealSlot.lunch, [item(rice, 200), item(chicken, 120), item(broccoli, 150)]),
    ];
    final score = ScoreEngine.computeDay(date: '2026-10-26', entries: entries, profile: profile);
    final result = PlanEngine.generate(
      data: data,
      todayScore: score,
      constraints: const PlanConstraints(maxMinutes: 30, maxCost: 30),
      planId: 'plan',
      startDate: '2026-10-27',
      days: 1,
      maxMeals: 3,
    );
    expect(result.plan.meals, isNotEmpty);
    final ids = result.plan.meals.map((e) => e.recipeId).toList();
    expect(ids.toSet().length, ids.length);
    expect(result.plan.meals.every((e) => e.reasons.isNotEmpty), isTrue);
  });

  test('seed bundle always has condiments and seed foods', () async {
    final bundle = await SeedLoader.load();
    final hasFull = File('assets/private/cn_food_full.json').existsSync();
    expect(
      bundle.foods.length,
      hasFull ? greaterThan(1600) : greaterThanOrEqualTo(100),
    );
    expect(bundle.foods.any((e) => e.id == 'cond_salt_iodized'), isTrue);
    expect(bundle.foods.any((e) => e.id == 'rice_cooked'), isTrue);
  });

  test('every recipe ingredient resolves against the merged food library', () async {
    final bundle = await SeedLoader.load();
    final byId = {for (final f in bundle.foods) f.id: f};
    final missing = <String>{};
    for (final recipe in bundle.recipes) {
      for (final ingredient in recipe.ingredients) {
        if (!byId.containsKey(ingredient.foodId)) {
          missing.add('${recipe.id}:${ingredient.foodId}');
        }
      }
    }
    expect(missing, isEmpty, reason: 'missing ingredients: $missing');
  });

  test('condition policies override targets and weights', () {
    const hypertension = HealthProfile(
      id: 'h',
      nickname: '测试',
      sex: Sex.male,
      activity: ActivityLevel.light,
      goal: Goal.maintain,
      conditions: {Condition.hypertension},
    );
    final h = NutrientTargets.fromProfile(hypertension);
    expect(h.sodiumOk, 2000);
    expect(h.sodiumIdeal, 1500);
    expect(h.sodiumIdeal, lessThanOrEqualTo(h.sodiumOk));
    expect(h.weightFor('C1'), greaterThan(1));
    expect(h.potassium, greaterThanOrEqualTo(3600));

    const ckd = HealthProfile(
      id: 'c',
      nickname: '测试',
      sex: Sex.male,
      activity: ActivityLevel.light,
      goal: Goal.maintain,
      conditions: {Condition.ckd},
    );
    final c = NutrientTargets.fromProfile(ckd);
    expect(c.limitPotassium, isTrue);
    expect(c.limitPhosphorus, isTrue);
    expect(c.phosphorus, lessThanOrEqualTo(1000));
    expect(c.protein, lessThanOrEqualTo(60));

    const pregnant = HealthProfile(
      id: 'p',
      nickname: '测试',
      sex: Sex.female,
      activity: ActivityLevel.light,
      goal: Goal.maintain,
      pregnant: true,
    );
    final pr = NutrientTargets.fromProfile(pregnant);
    expect(pr.folate, 600);
    expect(pr.iodine, 230);
  });

  test('advice engine prioritizes condition-specific sodium advice', () {
    const hypertension = HealthProfile(
      id: 'h',
      nickname: '测试',
      sex: Sex.male,
      activity: ActivityLevel.light,
      goal: Goal.maintain,
      conditions: {Condition.hypertension},
    );
    final advice = AdviceEngine.forDay(
      profile: hypertension,
      totals: const {'sodium_mg': 3200, 'fiber_g': 10, 'protein_g': 40},
      entries: const [],
    );
    expect(advice, isNotEmpty);
    expect(advice.first.title.contains('钠'), isTrue);
    expect(advice.first.evidence.isNotEmpty, isTrue);
  });

  test('missing nutrients are unknown, not zero-scored', () {
    final sparse = Food(
      id: 'sparse',
      name: '只有能量和蛋白',
      category: 'staple',
      source: 'test',
      createdAt: 0,
      updatedAt: 0,
      nutrientsPer100g: const {
        'energy_kcal': 200,
        'protein_g': 10,
        'sodium_mg': 100,
      },
      groupsPer100g: const {'refined_grain': 100},
    );
    final entry = FoodEntry(
      id: 'e1',
      profileId: 'p',
      localDate: '2026-10-27',
      slot: MealSlot.lunch,
      eatenAtMs: DateTime(2026, 10, 27, 12).millisecondsSinceEpoch,
      inputMode: InputMode.manual,
      createdAt: 0,
      updatedAt: 0,
      items: [
        EntryItem.fromFood(
          id: 'i1',
          food: sparse,
          gramsP10: 180,
          gramsP50: 200,
          gramsP90: 220,
          method: EstimateMethod.visual,
        ),
      ],
    );
    final day = ScoreEngine.computeDay(
      date: '2026-10-27',
      entries: [entry],
      profile: profile,
      monteCarlo: false,
    );
    final sugar = day.items.firstWhere((e) => e.code == 'C2');
    expect(sugar.status, ScoreStatus.unknown);
    expect(sugar.weight, 0);
    final fiber = day.items.firstWhere((e) => e.code == 'B2');
    expect(fiber.status, ScoreStatus.unknown);
  });

  test('CKD protein scales with body weight and dialysis', () {
    const base = HealthProfile(
      id: 'c',
      nickname: '测试',
      sex: Sex.male,
      activity: ActivityLevel.light,
      goal: Goal.maintain,
      weightKg: 70,
      conditions: {Condition.ckd},
    );
    final nonDialysis = NutrientTargets.fromProfile(base);
    expect(nonDialysis.protein, closeTo(56, 0.1));
    final dialysis = NutrientTargets.fromProfile(base.copyWith(ckdDialysis: true));
    expect(dialysis.protein, closeTo(77, 0.1));
  });

  test('conflicting condition goals keep the stricter upper bound', () {
    const both = HealthProfile(
      id: 'x',
      nickname: '测试',
      sex: Sex.male,
      activity: ActivityLevel.light,
      goal: Goal.maintain,
      conditions: {Condition.hypertension, Condition.ckd},
    );
    final t = NutrientTargets.fromProfile(both);
    expect(t.potassium, lessThanOrEqualTo(2500));
  });

  test('targets reflect sex and sodium', () {
    final female = NutrientTargets.fromProfile(profile);
    const male = HealthProfile(
      id: 'm',
      nickname: '测试',
      sex: Sex.male,
      activity: ActivityLevel.light,
      goal: Goal.maintain,
    );
    final maleTargets = NutrientTargets.fromProfile(male);
    expect(female.iron, 18);
    expect(maleTargets.iron, 12);
    expect(female.sodiumOk, 2000);
    expect(female.vegetable, 300);
  });
}
