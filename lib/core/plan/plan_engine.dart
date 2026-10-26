import 'dart:math';

import '../health/health_rules.dart';
import '../models/app_data.dart';
import '../models/enums.dart';
import '../models/food.dart';
import '../models/nutrients.dart';
import '../models/plan.dart';
import '../models/preference.dart';
import '../models/profile.dart';
import '../models/score.dart';
import '../util/date_utils.dart';

class PlanGenerationResult {
  final MealPlan plan;
  final List<String> notes;
  final bool relaxed;

  const PlanGenerationResult({
    required this.plan,
    this.notes = const [],
    this.relaxed = false,
  });
}

class PlanEngine {
  static MealSlot nextSlot(DateTime now) {
    final hour = now.hour;
    if (hour < 10) return MealSlot.breakfast;
    if (hour < 15) return MealSlot.lunch;
    if (hour < 21) return MealSlot.dinner;
    return MealSlot.snack;
  }

  static PlanGenerationResult generate({
    required AppData data,
    required DayScore todayScore,
    required PlanConstraints constraints,
    required String planId,
    String? startDate,
    int days = 1,
    MealSlot? onlySlot,
    int maxMeals = 5,
  }) {
    final profile = data.profile;
    final foods = data.foodById;
    final preferences = data.activePreferences;
    final rules = HealthRules.forProfile(profile);
    final start = startDate ?? todayKey();
    final notes = <String>[];

    final candidateBase = data.recipes.where((recipe) {
      if (recipe.ingredients.isEmpty) return false;
      if (constraints.excludeTags.any(recipe.tasteTags.contains)) return false;
      if (recipe.ingredients.any((i) => constraints.excludeFoodIds.contains(i.foodId))) {
        return false;
      }
      if (profile != null && _hasAllergy(recipe, foods, profile)) return false;
      if (_hasAvoidRule(recipe, foods, rules)) return false;
      return true;
    }).toList();

    final active = _filterByConstraints(candidateBase, constraints, strict: true);
    var candidates = active;
    var relaxed = false;
    if (candidates.length < 3) {
      candidates = _filterByConstraints(candidateBase, constraints, strict: false);
      relaxed = true;
      notes.add('条件太紧，已放宽时间/预算/设备中的一项；你可以在计划页继续调整。');
    }
    if (candidates.isEmpty) {
      candidates = candidateBase;
      relaxed = true;
      notes.add('没有完全匹配的菜，先用现有食谱给你一个可执行的起点。');
    }

    final lowItems = todayScore.items.where((e) => e.score < 80).toList()
      ..sort((a, b) => b.lostPoints.compareTo(a.lostPoints));
    final focus = lowItems.take(5).toList();
    if (focus.isEmpty) {
      focus.addAll(todayScore.items.where((e) => e.domain != ScoreDomain.limits).take(3));
    }

    final slots = <MealSlot>[];
    if (onlySlot != null) {
      slots.add(onlySlot);
    } else if (days <= 1) {
      slots.addAll([MealSlot.breakfast, MealSlot.lunch, MealSlot.dinner]);
    } else {
      slots.addAll([
        MealSlot.lunch,
        MealSlot.dinner,
        MealSlot.lunch,
        MealSlot.dinner,
        MealSlot.lunch,
      ]);
    }

    final selected = <PlanMeal>[];
    final used = <String>{};
    for (var i = 0; i < min(slots.length, maxMeals); i++) {
      final slot = slots[i];
      final date = addDaysKey(start, days <= 1 ? 0 : min(days - 1, i ~/ 2));
      final ranked = candidates
          .where((r) => !used.contains(r.id))
          .map((r) => MapEntry(r, _scoreRecipe(
                recipe: r,
                foods: foods,
                focus: focus,
                preferences: preferences,
                profile: profile,
                constraints: constraints,
                slot: slot,
              )))
          .toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      if (ranked.isEmpty) break;
      final recipe = ranked.first.key;
      used.add(recipe.id);
      final nutrients = recipe.nutrientTotals(foods);
      final groups = recipe.groupTotals(foods);
      final reasons = _reasonsFor(focus, nutrients, groups, recipe);
      selected.add(PlanMeal(
        id: '$planId-${slot.name}-$i',
        planId: planId,
        localDate: date,
        slot: slot,
        recipeId: recipe.id,
        title: recipe.name,
        grams: recipe.totalGrams,
        nutrients: nutrients,
        groups: groups,
        expectedDelta: _deltaFor(focus, nutrients, groups),
        minutes: recipe.minutes,
        cost: recipe.costYuan,
        steps: recipe.steps,
        reasons: reasons,
        sortOrder: i,
      ));
    }

    final plan = MealPlan(
      id: planId,
      profileId: profile?.id ?? 'default',
      name: days <= 1 ? '明日补丁餐' : '未来 $days 天补丁餐',
      startDate: start,
      endDate: addDaysKey(start, max(0, days - 1)),
      status: PlanStatus.active,
      constraints: constraints,
      meals: selected,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );

    if (selected.isNotEmpty) {
      final top = focus.isEmpty ? null : focus.first;
      if (top != null) {
        notes.add('优先补「${top.label}」：计划里已安排 ${selected.length} 餐，具体缺口见每餐的理由。');
      }
    }
    return PlanGenerationResult(plan: plan, notes: notes, relaxed: relaxed);
  }

  static List<Recipe> _filterByConstraints(
    List<Recipe> recipes,
    PlanConstraints constraints, {
    required bool strict,
  }) {
    return recipes.where((recipe) {
      if (strict && recipe.minutes > constraints.maxMinutes) return false;
      if (strict && recipe.costYuan > constraints.maxCost) return false;
      if (strict && constraints.equipment.isNotEmpty) {
        final ok = recipe.equipment.isEmpty ||
            recipe.equipment.every((e) => constraints.equipment.contains(e));
        if (!ok) return false;
      }
      if (constraints.laziness == 'noCook' && !recipe.isNoCook && !recipe.isTakeout && recipe.minutes > 10) {
        return false;
      }
      return true;
    }).toList();
  }

  static bool _hasAllergy(Recipe recipe, Map<String, Food> foods, HealthProfile profile) {
    if (profile.allergies.isEmpty) return false;
    for (final ingredient in recipe.ingredients) {
      final food = foods[ingredient.foodId];
      if (food == null) continue;
      final haystack = '${food.name} ${food.aliases.join(' ')} ${food.tags.join(' ')}'.toLowerCase();
      for (final allergy in profile.allergies) {
        if (allergy.trim().isEmpty) continue;
        if (haystack.contains(allergy.toLowerCase())) return true;
      }
    }
    return false;
  }

  static bool _hasAvoidRule(Recipe recipe, Map<String, Food> foods, List<HealthRule> rules) {
    final avoidTags = rules
        .where((r) => r.category == HealthRuleCategory.avoid)
        .expand((r) => r.foodTags)
        .toSet();
    if (avoidTags.isEmpty) return false;
    for (final ingredient in recipe.ingredients) {
      final food = foods[ingredient.foodId];
      if (food == null) continue;
      if (food.tags.any(avoidTags.contains)) return true;
    }
    return false;
  }

  static double _scoreRecipe({
    required Recipe recipe,
    required Map<String, Food> foods,
    required List<ScoreItemResult> focus,
    required List<Preference> preferences,
    required HealthProfile? profile,
    required PlanConstraints constraints,
    required MealSlot slot,
  }) {
    final nutrients = recipe.nutrientTotals(foods);
    final groups = recipe.groupTotals(foods);
    var score = 0.0;

    for (final item in focus) {
      final amount = _amountFor(item.code, nutrients, groups);
      final target = max(1.0, item.targetMin);
      score += (amount / target).clamp(0.0, 2.0) * item.lostPoints;
    }

    final sodium = nutrients[NutrientCode.sodium] ?? 0;
    final sugar = nutrients[NutrientCode.sugar] ?? 0;
    final sfa = nutrients[NutrientCode.sfa] ?? 0;
    final upf = nutrients[NutrientCode.upf] ?? 0;
    final sodiumLimit = profile?.has(Condition.hypertension) == true ? 600.0 : 900.0;
    score -= max(0, sodium - sodiumLimit) / 100 * 3;
    score -= max(0, sugar - 15) * 0.8;
    score -= max(0, sfa - 12) * 0.4;
    score -= upf * 0.03;

    final prefScore = _preferenceScore(recipe, preferences);
    final tasteWeight = constraints.tastePriority == 'taste'
        ? 2.0
        : constraints.tastePriority == 'health'
            ? 0.6
            : 1.2;
    score += prefScore * tasteWeight;

    if (recipe.isTakeout) score -= constraints.tastePriority == 'health' ? 8 : 2;
    if (recipe.isNoCook && constraints.laziness == 'noCook') score += 5;
    if (_slotFit(recipe, slot)) score += 6;
    if (recipe.minutes <= 15) score += 2;
    if (recipe.costYuan <= constraints.maxCost) score += 2;
    return score;
  }

  static bool _slotFit(Recipe recipe, MealSlot slot) {
    if (slot == MealSlot.breakfast) {
      return recipe.category == 'breakfast' || recipe.tasteTags.contains('免煮');
    }
    if (slot == MealSlot.snack) {
      return recipe.category == 'snack' || recipe.tasteTags.contains('免煮');
    }
    return recipe.category == 'lunch' || recipe.category == 'dinner';
  }

  static double _preferenceScore(Recipe recipe, List<Preference> preferences) {
    if (preferences.isEmpty) return 0;
    var total = 0.0;
    var count = 0;
    for (final ingredient in recipe.ingredients) {
      final matches = preferences.where((p) =>
          p.entityId == ingredient.foodId ||
          p.label == ingredient.foodId ||
          p.label.contains(ingredient.foodId));
      for (final pref in matches) {
        total += (pref.stars - 3) * 2.0;
        count++;
      }
    }
    for (final tag in recipe.tasteTags) {
      final matches = preferences.where((p) => p.entityType == PreferenceEntityType.trait && p.label == tag);
      for (final pref in matches) {
        total += (pref.stars - 3) * 1.0;
        count++;
      }
    }
    return count == 0 ? 0 : total / count;
  }

  static double _amountFor(String code, Map<String, double> nutrients, Map<String, double> groups) {
    return switch (code) {
      'A1' => groups[FoodGroupCode.vegetable] ?? 0,
      'A2' => groups[FoodGroupCode.fruit] ?? 0,
      'A3' => (groups[FoodGroupCode.wholeGrain] ?? 0) + (groups[FoodGroupCode.tuber] ?? 0),
      'A4' => groups[FoodGroupCode.dairy] ?? 0,
      'A5' => groups[FoodGroupCode.soyNut] ?? 0,
      'A6' => (groups[FoodGroupCode.animalProtein] ?? 0) + (groups[FoodGroupCode.fish] ?? 0),
      'B1' => nutrients[NutrientCode.protein] ?? 0,
      'B2' => nutrients[NutrientCode.fiber] ?? 0,
      'B3' => nutrients[NutrientCode.calcium] ?? 0,
      'B4' => nutrients[NutrientCode.iron] ?? 0,
      'B5' => nutrients[NutrientCode.vitaminA] ?? 0,
      'B6' => nutrients[NutrientCode.vitaminC] ?? 0,
      'B7' => (nutrients[NutrientCode.folate] ?? 0) + (nutrients[NutrientCode.vitaminB12] ?? 0) * 100,
      _ => 0,
    };
  }

  static Map<String, double> _deltaFor(
    List<ScoreItemResult> focus,
    Map<String, double> nutrients,
    Map<String, double> groups,
  ) {
    final out = <String, double>{};
    for (final item in focus) {
      final amount = _amountFor(item.code, nutrients, groups);
      if (amount > 0) out[item.code] = amount;
    }
    return out;
  }

  static List<String> _reasonsFor(
    List<ScoreItemResult> focus,
    Map<String, double> nutrients,
    Map<String, double> groups,
    Recipe recipe,
  ) {
    final out = <String>[];
    for (final item in focus.take(3)) {
      final amount = _amountFor(item.code, nutrients, groups);
      if (amount <= 0) continue;
      final unit = item.unit;
      final value = amount >= 10 ? amount.round().toString() : amount.toStringAsFixed(1);
      out.add('${item.label} $value $unit');
    }
    final sodium = nutrients[NutrientCode.sodium] ?? 0;
    if (sodium > 800) out.add('钠偏高，汤/酱别全吃');
    if (out.isEmpty) out.add('结构均衡的一份');
    return out;
  }
}
