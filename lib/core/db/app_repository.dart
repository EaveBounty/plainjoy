import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:sembast/sembast.dart';
import 'package:uuid/uuid.dart';

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
import 'app_database.dart';

class SeedBundle {
  final List<Food> foods;
  final List<Recipe> recipes;
  final List<FoodContainer> containers;
  final List<ReferenceObject> referenceObjects;

  const SeedBundle({
    this.foods = const [],
    this.recipes = const [],
    this.containers = const [],
    this.referenceObjects = const [],
  });
}

class SeedLoader {
  static const currentVersion = 4;

  static Future<SeedBundle>? _cache;

  /// 食物库三级合并：
  /// 1. 手工种子（102 条，含菜品与食谱原料，id 稳定）
  /// 2. 调味品明细（22 条，盐/酱油/味精的钠与碘）
  /// 3. 本地全量成分表（assets/private/cn_food_full.json，缺失时自动跳过）
  ///
  /// 同名只保留优先级最高的一条，避免「米饭」出现三次。
  static Future<SeedBundle> load() => _cache ??= _load();

  static Future<SeedBundle> _load() async {
    final seed = await _readList('assets/seed/foods.json')
        .then((list) => list.map((e) => Food.fromJson(e)).toList());
    final condiments = await _readList('assets/seed/condiments.json')
        .then((list) => list.map((e) => Food.fromJson(e)).toList());
    final full = await _readList('assets/private/cn_food_full.json')
        .then((list) => list.map((e) => Food.fromJson(e)).toList());

    // 种子与调味品全部保留（食谱按 id 引用，不能因同名被丢掉）；
    // 全量成分表只跳过与它们同名的条目。
    final foods = <Food>[...seed, ...condiments];
    final seen = <String>{for (final food in foods) _nameKey(food.name)};
    for (final food in full) {
      if (seen.add(_nameKey(food.name))) foods.add(food);
    }

    final recipes = await _readList('assets/seed/recipes.json')
        .then((list) => list.map((e) => Recipe.fromJson(e)).toList());
    final containers = await _readList('assets/seed/containers.json')
        .then((list) => list.map((e) => FoodContainer.fromJson(e)).toList());
    final refs = await _readList('assets/seed/reference_objects.json')
        .then((list) => list.map((e) => ReferenceObject.fromJson(e)).toList());
    return SeedBundle(
      foods: foods,
      recipes: recipes,
      containers: containers,
      referenceObjects: refs,
    );
  }

  static String _nameKey(String name) => name.replaceAll(RegExp(r'\s+'), '').toLowerCase();

  static Future<List<Map<String, Object?>>> _readList(String asset) async {
    try {
      final raw = await rootBundle.loadString(asset);
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.whereType<Map>().map((e) {
          return e.map((key, value) => MapEntry(key.toString(), value));
        }).toList();
      }
      return const [];
    } catch (_) {
      return const [];
    }
  }
}

class AppRepository {
  final AppDatabase database;
  final Uuid _uuid = const Uuid();

  AppRepository(this.database);

  Database get _db => database.db;

  Future<AppData> loadAll() async {
    final settingsMap = await database.settings.record('app').get(_db);
    final profiles = await database.profiles.find(_db);
    final entries = await database.entries.find(_db);
    final foods = await database.foods.find(_db);
    final recipes = await database.recipes.find(_db);
    final containers = await database.containers.find(_db);
    final refs = await database.referenceObjects.find(_db);
    final preferences = await database.preferences.find(_db);
    final plans = await database.plans.find(_db);
    final pets = await database.pets.find(_db);
    final petSnapshots = await database.petSnapshots.find(_db);

    final profileList = profiles
        .map((e) => HealthProfile.fromJson(e.value))
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    final entryList = entries
        .map((e) => FoodEntry.fromJson(e.value))
        .where((e) => e.deletedAt == null)
        .toList()
      ..sort((a, b) => b.eatenAtMs.compareTo(a.eatenAtMs));

    final bundle = await SeedLoader.load();
    final byId = <String, Food>{
      for (final food in bundle.foods) food.id: food,
    };
    for (final record in foods) {
      final food = Food.fromJson(record.value);
      if (food.deletedAt != null) continue;
      byId[food.id] = food; // 用户自定义/编辑过的食物优先
    }
    final foodList = byId.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final recipeList = recipes.map((e) => Recipe.fromJson(e.value)).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final containerList = containers.map((e) => FoodContainer.fromJson(e.value)).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final refList = refs.map((e) => ReferenceObject.fromJson(e.value)).toList();

    final preferenceList = preferences.map((e) => Preference.fromJson(e.value)).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    final planList = plans.map((e) => MealPlan.fromJson(e.value)).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    final petList = pets.map((e) => Pet.fromJson(e.value)).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    final snapshotList = petSnapshots.map((e) => PetStateSnapshot.fromJson(e.value)).toList()
      ..sort((a, b) => b.localDate.compareTo(a.localDate));

    return AppData(
      foods: foodList,
      entries: entryList,
      recipes: recipeList,
      containers: containerList,
      referenceObjects: refList,
      preferences: preferenceList,
      plans: planList,
      pets: petList,
      petSnapshots: snapshotList,
      profile: profileList.isEmpty ? null : profileList.first,
      settings: settingsMap == null
          ? const AppSettings()
          : AppSettings.fromJson(settingsMap),
    );
  }

  Future<void> seedIfNeeded() async {
    final existingSettings = await database.settings.record('app').get(_db);
    final settings = existingSettings == null
        ? const AppSettings()
        : AppSettings.fromJson(existingSettings);
    if (settings.seedVersion >= SeedLoader.currentVersion) return;

    final bundle = await SeedLoader.load();
    final now = DateTime.now().millisecondsSinceEpoch;

    await _db.transaction((txn) async {
      // 食物库不再逐条写入 Sembast：全量数据 1600+ 条，写入会拖慢冷启动。
      // 种子/全量食物每次启动从 asset 合并进内存；数据库只存用户改动过的条目。
      for (final recipe in bundle.recipes) {
        final existing = await database.recipes.record(recipe.id).get(txn);
        if (existing == null) {
          await database.recipes.record(recipe.id).put(txn, recipe.toJson());
        }
      }
      for (final container in bundle.containers) {
        final existing = await database.containers.record(container.id).get(txn);
        if (existing == null) {
          await database.containers.record(container.id).put(txn, container.toJson());
        }
      }
      for (final ref in bundle.referenceObjects) {
        final existing = await database.referenceObjects.record(ref.id).get(txn);
        if (existing == null) {
          await database.referenceObjects.record(ref.id).put(txn, ref.toJson());
        }
      }

      final profile = await database.profiles.record('default').get(txn);
      if (profile == null) {
        final defaultProfile = HealthProfile(
          id: 'default',
          nickname: '我',
          sex: Sex.preferNot,
          activity: ActivityLevel.light,
          goal: Goal.maintain,
          updatedAt: now,
        );
        await database.profiles.record('default').put(txn, defaultProfile.toJson());
      }

      final defaultPets = <Pet>[
        Pet(
          id: 'pet_default',
          profileId: 'default',
          species: PetSpecies.calicoCat,
          name: '小欢',
          bornAt: now,
          updatedAt: now,
        ),
        Pet(
          id: 'pet_default_dog',
          profileId: 'default',
          species: PetSpecies.tuxedoDog,
          name: '阿黄',
          bornAt: now,
          updatedAt: now - 1,
        ),
      ];
      for (final defaultPet in defaultPets) {
        final pet = await database.pets.record(defaultPet.id).get(txn);
        if (pet == null) {
          await database.pets.record(defaultPet.id).put(txn, defaultPet.toJson());
        }
      }

      final updatedSettings = settings.copyWith(seedVersion: SeedLoader.currentVersion);
      await database.settings.record('app').put(txn, updatedSettings.toJson());
    });
  }

  Future<void> saveSettings(AppSettings settings) async {
    await database.settings.record('app').put(_db, settings.toJson());
  }

  Future<void> saveProfile(HealthProfile profile) async {
    await database.profiles.record(profile.id).put(_db, profile.toJson());
  }

  Future<void> saveFood(Food food) async {
    await database.foods.record(food.id).put(_db, food.toJson());
  }

  Future<void> saveEntry(FoodEntry entry) async {
    await database.entries.record(entry.id).put(_db, entry.toJson());
  }

  Future<void> deleteEntry(String id) async {
    await database.entries.record(id).delete(_db);
  }

  Future<void> savePreference(Preference preference) async {
    await database.preferences.record(preference.id).put(_db, preference.toJson());
  }

  Future<void> deletePreference(String id) async {
    await database.preferences.record(id).delete(_db);
  }

  Future<void> saveContainer(FoodContainer container) async {
    await database.containers.record(container.id).put(_db, container.toJson());
  }

  Future<void> savePlan(MealPlan plan) async {
    await database.plans.record(plan.id).put(_db, plan.toJson());
  }

  Future<void> savePet(Pet pet) async {
    await database.pets.record(pet.id).put(_db, pet.toJson());
  }

  Future<void> savePetSnapshot(PetStateSnapshot snapshot) async {
    await database.petSnapshots.record(snapshot.id).put(_db, snapshot.toJson());
  }

  String newId() => _uuid.v7();

  Future<String> exportJson() async {
    final data = <String, Object?>{
      'app': 'plainjoy',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'settings': _settingsForExport(await database.settings.record('app').get(_db)),
      'profiles': (await database.profiles.find(_db)).map((e) => e.value).toList(),
      'foods': (await database.foods.find(_db)).map((e) => e.value).toList(),
      'entries': (await database.entries.find(_db)).map((e) => e.value).toList(),
      'recipes': (await database.recipes.find(_db)).map((e) => e.value).toList(),
      'containers': (await database.containers.find(_db)).map((e) => e.value).toList(),
      'reference_objects': (await database.referenceObjects.find(_db)).map((e) => e.value).toList(),
      'preferences': (await database.preferences.find(_db)).map((e) => e.value).toList(),
      'plans': (await database.plans.find(_db)).map((e) => e.value).toList(),
      'pets': (await database.pets.find(_db)).map((e) => e.value).toList(),
      'pet_snapshots': (await database.petSnapshots.find(_db)).map((e) => e.value).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  Map<String, Object?>? _settingsForExport(Map<String, Object?>? settings) {
    if (settings == null) return null;
    final copy = Map<String, Object?>.from(settings);
    copy.remove('aiApiKey');
    return copy;
  }

  Future<void> importJson(String raw) async {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) throw const FormatException('备份格式不正确');
    final map = decoded.map((key, value) => MapEntry(key.toString(), value));
    if (map['app'] != 'plainjoy') throw const FormatException('不是有味清欢的备份文件');

    final stores = <StoreRef<String, Map<String, Object?>>, Object?>{
      database.settings: map['settings'],
      database.profiles: map['profiles'],
      database.foods: map['foods'],
      database.entries: map['entries'],
      database.recipes: map['recipes'],
      database.containers: map['containers'],
      database.referenceObjects: map['reference_objects'],
      database.preferences: map['preferences'],
      database.plans: map['plans'],
      database.pets: map['pets'],
      database.petSnapshots: map['pet_snapshots'],
    };

    final currentSettings = await database.settings.record('app').get(_db);
    final currentKey = currentSettings?['aiApiKey']?.toString() ?? '';
    await _db.transaction((txn) async {
      for (final entry in stores.entries) {
        final store = entry.key;
        final value = entry.value;
        await store.delete(txn);
        if (store == database.settings && value is Map) {
          final settings = value.map((k, v) => MapEntry(k.toString(), v));
          final importedKey = settings['aiApiKey']?.toString() ?? '';
          if (importedKey.isEmpty && currentKey.isNotEmpty) {
            settings['aiApiKey'] = currentKey;
          }
          await store.record('app').put(txn, settings);
        } else if (value is List) {
          for (final item in value) {
            if (item is! Map) continue;
            final m = item.map((k, v) => MapEntry(k.toString(), v));
            final id = m['id']?.toString();
            if (id == null) continue;
            await store.record(id).put(txn, m);
          }
        }
      }
    });
  }
}
