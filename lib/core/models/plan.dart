import 'enums.dart';
import 'food.dart';
import 'json_utils.dart';

class RecipeIngredient {
  final String foodId;
  final double grams;
  final String? note;

  const RecipeIngredient({required this.foodId, required this.grams, this.note});

  Map<String, Object?> toJson() => {'foodId': foodId, 'grams': grams, 'note': note};

  factory RecipeIngredient.fromJson(Map<String, Object?> json) => RecipeIngredient(
        foodId: asString(json['foodId']) ?? '',
        grams: asDouble(json['grams']) ?? 0,
        note: asString(json['note']),
      );
}

class Recipe {
  final String id;
  final String name;
  final String category;
  final String description;
  final List<RecipeIngredient> ingredients;
  final List<String> equipment;
  final int minutes;
  final double costYuan;
  final String difficulty;
  final List<String> steps;
  final List<String> tasteTags;
  final bool isTakeout;
  final bool isNoCook;
  final int servings;

  const Recipe({
    required this.id,
    required this.name,
    required this.category,
    this.description = '',
    required this.ingredients,
    this.equipment = const ['induction'],
    this.minutes = 20,
    this.costYuan = 15,
    this.difficulty = 'easy',
    this.steps = const [],
    this.tasteTags = const [],
    this.isTakeout = false,
    this.isNoCook = false,
    this.servings = 1,
  });

  Map<String, double> nutrientTotals(Map<String, Food> foods) {
    final out = <String, double>{};
    for (final ingredient in ingredients) {
      final food = foods[ingredient.foodId];
      if (food == null) continue;
      final factor = ingredient.grams / 100.0;
      for (final entry in food.nutrientsPer100g.entries) {
        out[entry.key] = (out[entry.key] ?? 0) + entry.value * factor;
      }
    }
    return out;
  }

  Map<String, double> groupTotals(Map<String, Food> foods) {
    final out = <String, double>{};
    for (final ingredient in ingredients) {
      final food = foods[ingredient.foodId];
      if (food == null) continue;
      final factor = ingredient.grams / 100.0;
      for (final entry in food.groupsPer100g.entries) {
        out[entry.key] = (out[entry.key] ?? 0) + entry.value * factor;
      }
    }
    return out;
  }

  double get totalGrams =>
      ingredients.fold(0, (sum, ingredient) => sum + ingredient.grams);

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'description': description,
        'ingredients': ingredients.map((e) => e.toJson()).toList(),
        'equipment': equipment,
        'minutes': minutes,
        'costYuan': costYuan,
        'difficulty': difficulty,
        'steps': steps,
        'tasteTags': tasteTags,
        'isTakeout': isTakeout,
        'isNoCook': isNoCook,
        'servings': servings,
      };

  factory Recipe.fromJson(Map<String, Object?> json) => Recipe(
        id: asString(json['id']) ?? '',
        name: asString(json['name']) ?? '菜谱',
        category: asString(json['category']) ?? 'dish',
        description: asString(json['description']) ?? '',
        ingredients: (json['ingredients'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => RecipeIngredient.fromJson(jsonMap(e)))
            .toList(),
        equipment: asStringList(json['equipment']),
        minutes: asInt(json['minutes']) ?? 20,
        costYuan: asDouble(json['costYuan']) ?? 15,
        difficulty: asString(json['difficulty']) ?? 'easy',
        steps: asStringList(json['steps']),
        tasteTags: asStringList(json['tasteTags']),
        isTakeout: asBool(json['isTakeout']),
        isNoCook: asBool(json['isNoCook']),
        servings: asInt(json['servings']) ?? 1,
      );
}

class PlanConstraints {
  final Set<String> equipment;
  final int maxMinutes;
  final double maxCost;
  final String tastePriority;
  final String laziness;
  final bool useLeftovers;
  final Set<String> excludeFoodIds;
  final Set<String> excludeTags;
  final Map<String, int> traitScores;

  const PlanConstraints({
    this.equipment = const {'induction', 'riceCooker'},
    this.maxMinutes = 30,
    this.maxCost = 30,
    this.tastePriority = 'balanced',
    this.laziness = 'canPrep',
    this.useLeftovers = true,
    this.excludeFoodIds = const {},
    this.excludeTags = const {},
    this.traitScores = const {},
  });

  PlanConstraints copyWith({
    Set<String>? equipment,
    int? maxMinutes,
    double? maxCost,
    String? tastePriority,
    String? laziness,
    bool? useLeftovers,
    Set<String>? excludeFoodIds,
    Set<String>? excludeTags,
    Map<String, int>? traitScores,
  }) {
    return PlanConstraints(
      equipment: equipment ?? this.equipment,
      maxMinutes: maxMinutes ?? this.maxMinutes,
      maxCost: maxCost ?? this.maxCost,
      tastePriority: tastePriority ?? this.tastePriority,
      laziness: laziness ?? this.laziness,
      useLeftovers: useLeftovers ?? this.useLeftovers,
      excludeFoodIds: excludeFoodIds ?? this.excludeFoodIds,
      excludeTags: excludeTags ?? this.excludeTags,
      traitScores: traitScores ?? this.traitScores,
    );
  }

  Map<String, Object?> toJson() => {
        'equipment': equipment.toList(),
        'maxMinutes': maxMinutes,
        'maxCost': maxCost,
        'tastePriority': tastePriority,
        'laziness': laziness,
        'useLeftovers': useLeftovers,
        'excludeFoodIds': excludeFoodIds.toList(),
        'excludeTags': excludeTags.toList(),
        'traitScores': traitScores,
      };

  factory PlanConstraints.fromJson(Map<String, Object?> json) => PlanConstraints(
        equipment: asStringList(json['equipment']).toSet(),
        maxMinutes: asInt(json['maxMinutes']) ?? 30,
        maxCost: asDouble(json['maxCost']) ?? 30,
        tastePriority: asString(json['tastePriority']) ?? 'balanced',
        laziness: asString(json['laziness']) ?? 'canPrep',
        useLeftovers: asBool(json['useLeftovers'], fallback: true),
        excludeFoodIds: asStringList(json['excludeFoodIds']).toSet(),
        excludeTags: asStringList(json['excludeTags']).toSet(),
        traitScores: asIntMap(json['traitScores']),
      );
}

class PlanMeal {
  final String id;
  final String planId;
  final String localDate;
  final MealSlot slot;
  final String recipeId;
  final String title;
  final double grams;
  final Map<String, double> nutrients;
  final Map<String, double> groups;
  final Map<String, double> expectedDelta;
  final int minutes;
  final double cost;
  final List<String> steps;
  final List<String> reasons;
  final bool done;
  final String? entryId;
  final int sortOrder;

  const PlanMeal({
    required this.id,
    required this.planId,
    required this.localDate,
    required this.slot,
    required this.recipeId,
    required this.title,
    required this.grams,
    this.nutrients = const {},
    this.groups = const {},
    this.expectedDelta = const {},
    this.minutes = 20,
    this.cost = 15,
    this.steps = const [],
    this.reasons = const [],
    this.done = false,
    this.entryId,
    this.sortOrder = 0,
  });

  double nutrient(String code) => nutrients[code] ?? 0;

  PlanMeal copyWith({
    String? localDate,
    MealSlot? slot,
    String? recipeId,
    String? title,
    double? grams,
    Map<String, double>? nutrients,
    Map<String, double>? groups,
    Map<String, double>? expectedDelta,
    int? minutes,
    double? cost,
    List<String>? steps,
    List<String>? reasons,
    bool? done,
    String? entryId,
    int? sortOrder,
  }) {
    return PlanMeal(
      id: id,
      planId: planId,
      localDate: localDate ?? this.localDate,
      slot: slot ?? this.slot,
      recipeId: recipeId ?? this.recipeId,
      title: title ?? this.title,
      grams: grams ?? this.grams,
      nutrients: nutrients ?? this.nutrients,
      groups: groups ?? this.groups,
      expectedDelta: expectedDelta ?? this.expectedDelta,
      minutes: minutes ?? this.minutes,
      cost: cost ?? this.cost,
      steps: steps ?? this.steps,
      reasons: reasons ?? this.reasons,
      done: done ?? this.done,
      entryId: entryId ?? this.entryId,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'planId': planId,
        'localDate': localDate,
        'slot': slot.name,
        'recipeId': recipeId,
        'title': title,
        'grams': grams,
        'nutrients': nutrients,
        'groups': groups,
        'expectedDelta': expectedDelta,
        'minutes': minutes,
        'cost': cost,
        'steps': steps,
        'reasons': reasons,
        'done': done,
        'entryId': entryId,
        'sortOrder': sortOrder,
      };

  factory PlanMeal.fromJson(Map<String, Object?> json) => PlanMeal(
        id: asString(json['id']) ?? '',
        planId: asString(json['planId']) ?? '',
        localDate: asString(json['localDate']) ?? '1970-01-01',
        slot: MealSlot.values.firstWhere(
          (e) => e.name == asString(json['slot']),
          orElse: () => MealSlot.dinner,
        ),
        recipeId: asString(json['recipeId']) ?? '',
        title: asString(json['title']) ?? '补丁餐',
        grams: asDouble(json['grams']) ?? 0,
        nutrients: asDoubleMap(json['nutrients']),
        groups: asDoubleMap(json['groups']),
        expectedDelta: asDoubleMap(json['expectedDelta']),
        minutes: asInt(json['minutes']) ?? 20,
        cost: asDouble(json['cost']) ?? 15,
        steps: asStringList(json['steps']),
        reasons: asStringList(json['reasons']),
        done: asBool(json['done']),
        entryId: asString(json['entryId']),
        sortOrder: asInt(json['sortOrder']) ?? 0,
      );
}

class MealPlan {
  final String id;
  final String profileId;
  final String name;
  final String startDate;
  final String endDate;
  final PlanStatus status;
  final PlanConstraints constraints;
  final List<PlanMeal> meals;
  final int createdAt;
  final int updatedAt;

  const MealPlan({
    required this.id,
    required this.profileId,
    required this.name,
    required this.startDate,
    required this.endDate,
    this.status = PlanStatus.draft,
    required this.constraints,
    this.meals = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  MealPlan copyWith({
    String? name,
    String? endDate,
    PlanStatus? status,
    PlanConstraints? constraints,
    List<PlanMeal>? meals,
    int? updatedAt,
  }) {
    return MealPlan(
      id: id,
      profileId: profileId,
      name: name ?? this.name,
      startDate: startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      constraints: constraints ?? this.constraints,
      meals: meals ?? this.meals,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'profileId': profileId,
        'name': name,
        'startDate': startDate,
        'endDate': endDate,
        'status': status.name,
        'constraints': constraints.toJson(),
        'meals': meals.map((e) => e.toJson()).toList(),
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory MealPlan.fromJson(Map<String, Object?> json) => MealPlan(
        id: asString(json['id']) ?? '',
        profileId: asString(json['profileId']) ?? '',
        name: asString(json['name']) ?? '餐食计划',
        startDate: asString(json['startDate']) ?? '1970-01-01',
        endDate: asString(json['endDate']) ?? '1970-01-01',
        status: PlanStatus.values.firstWhere(
          (e) => e.name == asString(json['status']),
          orElse: () => PlanStatus.draft,
        ),
        constraints: PlanConstraints.fromJson(jsonMap(json['constraints'])),
        meals: (json['meals'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => PlanMeal.fromJson(jsonMap(e)))
            .toList(),
        createdAt: asInt(json['createdAt']) ?? 0,
        updatedAt: asInt(json['updatedAt']) ?? 0,
      );
}
