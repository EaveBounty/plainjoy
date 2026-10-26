import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_repository.dart';
import '../models/app_data.dart';
import '../models/container.dart';
import '../models/entry.dart';
import '../models/enums.dart';
import '../models/food.dart';
import '../models/plan.dart';
import '../models/preference.dart';
import '../models/pet.dart';
import '../models/profile.dart';
import '../models/settings.dart';

final repositoryProvider = Provider<AppRepository>((ref) {
  throw UnimplementedError('repositoryProvider must be overridden in main()');
});

final appStateProvider = AsyncNotifierProvider<AppStateNotifier, AppData>(
  AppStateNotifier.new,
);

class AppStateNotifier extends AsyncNotifier<AppData> {
  AppRepository get _repo => ref.read(repositoryProvider);

  @override
  Future<AppData> build() async {
    await _repo.seedIfNeeded();
    return _repo.loadAll();
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_repo.loadAll);
  }

  Future<void> _mutate(Future<void> Function(AppRepository repo) action) async {
    final repo = _repo;
    await action(repo);
    state = AsyncData(await repo.loadAll());
  }

  // ---------- settings ----------
  Future<void> updateSettings(AppSettings Function(AppSettings current) update) async {
    final current = state.value?.settings ?? const AppSettings();
    final next = update(current);
    await _mutate((repo) => repo.saveSettings(next));
  }

  Future<void> setTheme(ThemeVariant theme) =>
      updateSettings((s) => s.copyWith(theme: theme));

  Future<void> setPrecision(PrecisionTier precision) =>
      updateSettings((s) => s.copyWith(precision: precision));

  Future<void> completeOnboarding({required ThemeVariant theme, required PrecisionTier precision}) =>
      updateSettings((s) => s.copyWith(
            theme: theme,
            precision: precision,
            onboardingDone: true,
          ));

  Future<void> setAi({
    bool? enabled,
    String? apiKey,
    String? baseUrl,
    String? model,
    bool? localOnly,
  }) =>
      updateSettings((s) => s.copyWith(
            aiEnabled: enabled ?? s.aiEnabled,
            aiApiKey: apiKey ?? s.aiApiKey,
            aiBaseUrl: baseUrl ?? s.aiBaseUrl,
            aiModel: model ?? s.aiModel,
            localOnly: localOnly ?? s.localOnly,
          ));

  Future<void> setReduceMotion(bool value) =>
      updateSettings((s) => s.copyWith(reduceMotion: value));

  // ---------- profile ----------
  Future<void> saveProfile(HealthProfile profile) =>
      _mutate((repo) => repo.saveProfile(profile.copyWith(
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          )));

  // ---------- entries ----------
  Future<void> saveEntry(FoodEntry entry) =>
      _mutate((repo) => repo.saveEntry(entry));

  Future<void> deleteEntry(String id) =>
      _mutate((repo) => repo.deleteEntry(id));

  // ---------- preferences ----------
  Future<void> savePreference(Preference preference) =>
      _mutate((repo) => repo.savePreference(preference));

  Future<void> deletePreference(String id) =>
      _mutate((repo) => repo.deletePreference(id));

  Future<void> upsertPreference({
    required String label,
    required PreferenceEntityType type,
    String? entityId,
    int stars = 3,
    bool avoid = false,
    bool allergy = false,
    List<String> tags = const [],
    String source = 'explicit',
  }) async {
    final profile = state.value?.profile;
    if (profile == null) return;
    final existing = state.value!.preferences
        .where((e) =>
            e.profileId == profile.id &&
            e.entityType == type &&
            (e.entityId == (entityId ?? label) || e.label == label))
        .firstOrNull;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (existing != null) {
      final evidence = existing.evidenceCount + (source == 'explicit' ? 0 : 1);
      final adjustedStars = source == 'explicit'
          ? stars
          : (existing.stars + stars) ~/ 2;
      await savePreference(existing.copyWith(
        stars: adjustedStars.clamp(1, 5),
        avoid: avoid || existing.avoid,
        allergy: allergy || existing.allergy,
        evidenceCount: evidence,
        tags: {...existing.tags, ...tags}.toList(),
        source: source,
        updatedAt: now,
      ));
    } else {
      await savePreference(Preference(
        id: _repo.newId(),
        profileId: profile.id,
        entityType: type,
        entityId: entityId ?? label,
        label: label,
        stars: stars.clamp(1, 5),
        avoid: avoid,
        allergy: allergy,
        tags: tags,
        source: source,
        updatedAt: now,
      ));
    }
  }

  // ---------- containers ----------
  Future<void> saveContainer(FoodContainer container) =>
      _mutate((repo) => repo.saveContainer(container));

  // ---------- plans ----------
  Future<void> savePlan(MealPlan plan) =>
      _mutate((repo) => repo.savePlan(plan));

  // ---------- pet ----------
  Future<void> savePet(Pet pet) =>
      _mutate((repo) => repo.savePet(pet.copyWith(
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          )));

  Future<void> addCoins(int amount) async {
    final pet = state.value?.activePet;
    if (pet == null) return;
    final nextXp = pet.xp + amount;
    final nextLevel = 1 + nextXp ~/ 120;
    final next = pet.copyWith(
      coins: (pet.coins + amount).clamp(0, 99999),
      xp: nextXp,
      level: nextLevel,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await savePet(next);
  }

  Future<bool> unlockPet(PetSpecies species, String name) async {
    final data = state.value;
    final pet = data?.activePet;
    if (data == null || pet == null) return false;
    if (data.pets.any((e) => e.species == species)) return false;
    if (pet.coins < species.price) return false;
    final newPet = Pet(
      id: _repo.newId(),
      profileId: pet.profileId,
      species: species,
      name: name,
      bornAt: DateTime.now().millisecondsSinceEpoch,
      coins: pet.coins - species.price,
      xp: 0,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _mutate((repo) => repo.savePet(newPet));
    return true;
  }

  Future<void> switchPet(String petId) async {
    final data = state.value;
    if (data == null) return;
    final pet = data.pets.where((e) => e.id == petId).firstOrNull;
    if (pet == null) return;
    await savePet(pet.copyWith(updatedAt: DateTime.now().millisecondsSinceEpoch));
  }

  Future<void> savePetSnapshot(PetStateSnapshot snapshot) =>
      _mutate((repo) => repo.savePetSnapshot(snapshot));

  // ---------- backup ----------
  Future<String> exportJson() => _repo.exportJson();

  Future<void> importJson(String raw) async {
    await _repo.importJson(raw);
    await reload();
  }
}

final dataProvider = Provider<AppData?>((ref) {
  return ref.watch(appStateProvider).value;
});

final settingsProvider = Provider<AppSettings>((ref) {
  return ref.watch(appStateProvider).value?.settings ?? const AppSettings();
});

final profileProvider = Provider<HealthProfile?>((ref) {
  return ref.watch(appStateProvider).value?.profile;
});

final foodsProvider = Provider<List<Food>>((ref) {
  return ref.watch(appStateProvider).value?.foods ?? const [];
});

final recipesProvider = Provider<List<Recipe>>((ref) {
  return ref.watch(appStateProvider).value?.recipes ?? const [];
});

final activePetProvider = Provider<Pet?>((ref) {
  return ref.watch(appStateProvider).value?.activePet;
});
