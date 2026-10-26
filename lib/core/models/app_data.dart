import 'container.dart';
import 'enums.dart';
import 'entry.dart';
import 'food.dart';
import 'plan.dart';
import 'preference.dart';
import 'pet.dart';
import 'profile.dart';
import 'settings.dart';

class AppData {
  final List<Food> foods;
  final List<FoodEntry> entries;
  final List<Recipe> recipes;
  final List<FoodContainer> containers;
  final List<ReferenceObject> referenceObjects;
  final List<Preference> preferences;
  final List<MealPlan> plans;
  final List<Pet> pets;
  final List<PetStateSnapshot> petSnapshots;
  final HealthProfile? profile;
  final AppSettings settings;

  const AppData({
    this.foods = const [],
    this.entries = const [],
    this.recipes = const [],
    this.containers = const [],
    this.referenceObjects = const [],
    this.preferences = const [],
    this.plans = const [],
    this.pets = const [],
    this.petSnapshots = const [],
    this.profile,
    this.settings = const AppSettings(),
  });

  Map<String, Food> get foodById => {for (final food in foods) food.id: food};
  Map<String, Recipe> get recipeById => {for (final recipe in recipes) recipe.id: recipe};

  List<FoodEntry> entriesForDate(String date) =>
      entries.where((e) => e.localDate == date && e.deletedAt == null).toList()
        ..sort((a, b) => a.eatenAtMs.compareTo(b.eatenAtMs));

  List<FoodEntry> entriesBetween(String startDate, String endDate) => entries
      .where((e) =>
          e.deletedAt == null &&
          e.localDate.compareTo(startDate) >= 0 &&
          e.localDate.compareTo(endDate) <= 0)
      .toList()
    ..sort((a, b) => a.eatenAtMs.compareTo(b.eatenAtMs));

  Pet? get activePet => pets.isEmpty ? null : pets.first;

  List<Preference> get activePreferences => profile == null
      ? preferences
      : preferences.where((e) => e.profileId == profile!.id).toList();

  MealPlan? get activePlan {
    final active = plans.where((e) => e.status == PlanStatus.active).toList();
    if (active.isNotEmpty) return active.first;
    return plans.isEmpty ? null : plans.first;
  }

  AppData copyWith({
    List<Food>? foods,
    List<FoodEntry>? entries,
    List<Recipe>? recipes,
    List<FoodContainer>? containers,
    List<ReferenceObject>? referenceObjects,
    List<Preference>? preferences,
    List<MealPlan>? plans,
    List<Pet>? pets,
    List<PetStateSnapshot>? petSnapshots,
    HealthProfile? profile,
    AppSettings? settings,
  }) {
    return AppData(
      foods: foods ?? this.foods,
      entries: entries ?? this.entries,
      recipes: recipes ?? this.recipes,
      containers: containers ?? this.containers,
      referenceObjects: referenceObjects ?? this.referenceObjects,
      preferences: preferences ?? this.preferences,
      plans: plans ?? this.plans,
      pets: pets ?? this.pets,
      petSnapshots: petSnapshots ?? this.petSnapshots,
      profile: profile ?? this.profile,
      settings: settings ?? this.settings,
    );
  }
}
