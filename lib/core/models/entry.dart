import 'enums.dart';
import 'food.dart';
import 'json_utils.dart';
import 'nutrients.dart';

class EntryItem {
  final String id;
  final String? foodId;
  final String foodName;
  final double gramsP10;
  final double gramsP50;
  final double gramsP90;
  final EstimateMethod method;
  final double confidence;
  final String? containerId;
  final String? referenceObjectId;
  final Map<String, double> nutrientSnapshot;
  final Map<String, double> groupSnapshot;
  final int position;

  const EntryItem({
    required this.id,
    this.foodId,
    required this.foodName,
    required this.gramsP10,
    required this.gramsP50,
    required this.gramsP90,
    required this.method,
    this.confidence = 0.5,
    this.containerId,
    this.referenceObjectId,
    this.nutrientSnapshot = const {},
    this.groupSnapshot = const {},
    this.position = 0,
  });

  factory EntryItem.fromFood({
    required String id,
    required Food food,
    required double gramsP10,
    required double gramsP50,
    required double gramsP90,
    required EstimateMethod method,
    double confidence = 0.5,
    String? containerId,
    String? referenceObjectId,
    int position = 0,
  }) {
    final factor = gramsP50 / 100.0;
    final nutrients = <String, double>{
      for (final e in food.nutrientsPer100g.entries) e.key: e.value * factor,
    };
    final groups = <String, double>{
      for (final e in food.groupsPer100g.entries) e.key: e.value * factor,
    };
    return EntryItem(
      id: id,
      foodId: food.id,
      foodName: food.name,
      gramsP10: gramsP10,
      gramsP50: gramsP50,
      gramsP90: gramsP90,
      method: method,
      confidence: confidence,
      containerId: containerId,
      referenceObjectId: referenceObjectId,
      nutrientSnapshot: nutrients,
      groupSnapshot: groups,
      position: position,
    );
  }

  double nutrient(String code) => nutrientSnapshot[code] ?? 0;

  double group(String code) => groupSnapshot[code] ?? 0;

  EntryItem copyWith({
    String? foodId,
    String? foodName,
    double? gramsP10,
    double? gramsP50,
    double? gramsP90,
    EstimateMethod? method,
    double? confidence,
    Map<String, double>? nutrientSnapshot,
    Map<String, double>? groupSnapshot,
    int? position,
  }) {
    return EntryItem(
      id: id,
      foodId: foodId ?? this.foodId,
      foodName: foodName ?? this.foodName,
      gramsP10: gramsP10 ?? this.gramsP10,
      gramsP50: gramsP50 ?? this.gramsP50,
      gramsP90: gramsP90 ?? this.gramsP90,
      method: method ?? this.method,
      confidence: confidence ?? this.confidence,
      containerId: containerId,
      referenceObjectId: referenceObjectId,
      nutrientSnapshot: nutrientSnapshot ?? this.nutrientSnapshot,
      groupSnapshot: groupSnapshot ?? this.groupSnapshot,
      position: position ?? this.position,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'foodId': foodId,
        'foodName': foodName,
        'gramsP10': gramsP10,
        'gramsP50': gramsP50,
        'gramsP90': gramsP90,
        'method': method.name,
        'confidence': confidence,
        'containerId': containerId,
        'referenceObjectId': referenceObjectId,
        'nutrientSnapshot': nutrientSnapshot,
        'groupSnapshot': groupSnapshot,
        'position': position,
      };

  factory EntryItem.fromJson(Map<String, Object?> json) => EntryItem(
        id: asString(json['id']) ?? '',
        foodId: asString(json['foodId']),
        foodName: asString(json['foodName']) ?? '未命名',
        gramsP10: asDouble(json['gramsP10']) ?? 0,
        gramsP50: asDouble(json['gramsP50']) ?? 0,
        gramsP90: asDouble(json['gramsP90']) ?? 0,
        method: EstimateMethod.values.firstWhere(
          (e) => e.name == asString(json['method']),
          orElse: () => EstimateMethod.visual,
        ),
        confidence: asDouble(json['confidence']) ?? 0.5,
        containerId: asString(json['containerId']),
        referenceObjectId: asString(json['referenceObjectId']),
        nutrientSnapshot: asDoubleMap(json['nutrientSnapshot']),
        groupSnapshot: asDoubleMap(json['groupSnapshot']),
        position: asInt(json['position']) ?? 0,
      );
}

class FoodEntry {
  final String id;
  final String profileId;
  final int eatenAtMs;
  final String localDate;
  final MealSlot slot;
  final String? photoPath;
  final String? note;
  final InputMode inputMode;
  final List<EntryItem> items;
  final int createdAt;
  final int updatedAt;
  final int? deletedAt;

  const FoodEntry({
    required this.id,
    required this.profileId,
    required this.eatenAtMs,
    required this.localDate,
    required this.slot,
    this.photoPath,
    this.note,
    required this.inputMode,
    required this.items,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  double nutrient(String code) =>
      items.fold(0, (sum, item) => sum + item.nutrient(code));

  double group(String code) =>
      items.fold(0, (sum, item) => sum + item.group(code));

  Map<String, double> get totals {
    final out = <String, double>{};
    for (final code in NutrientCode.all) {
      final value = nutrient(code);
      if (value != 0) out[code] = value;
    }
    return out;
  }

  Map<String, double> get groupTotals {
    final out = <String, double>{};
    for (final code in FoodGroupCode.all) {
      final value = group(code);
      if (value != 0) out[code] = value;
    }
    return out;
  }

  FoodEntry copyWith({
    int? eatenAtMs,
    String? localDate,
    MealSlot? slot,
    String? photoPath,
    String? note,
    InputMode? inputMode,
    List<EntryItem>? items,
    int? updatedAt,
    int? deletedAt,
  }) {
    return FoodEntry(
      id: id,
      profileId: profileId,
      eatenAtMs: eatenAtMs ?? this.eatenAtMs,
      localDate: localDate ?? this.localDate,
      slot: slot ?? this.slot,
      photoPath: photoPath ?? this.photoPath,
      note: note ?? this.note,
      inputMode: inputMode ?? this.inputMode,
      items: items ?? this.items,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'profileId': profileId,
        'eatenAtMs': eatenAtMs,
        'localDate': localDate,
        'slot': slot.name,
        'photoPath': photoPath,
        'note': note,
        'inputMode': inputMode.name,
        'items': items.map((e) => e.toJson()).toList(),
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'deletedAt': deletedAt,
      };

  factory FoodEntry.fromJson(Map<String, Object?> json) => FoodEntry(
        id: asString(json['id']) ?? '',
        profileId: asString(json['profileId']) ?? '',
        eatenAtMs: asInt(json['eatenAtMs']) ?? 0,
        localDate: asString(json['localDate']) ?? '1970-01-01',
        slot: MealSlot.values.firstWhere(
          (e) => e.name == asString(json['slot']),
          orElse: () => MealSlot.snack,
        ),
        photoPath: asString(json['photoPath']),
        note: asString(json['note']),
        inputMode: InputMode.values.firstWhere(
          (e) => e.name == asString(json['inputMode']),
          orElse: () => InputMode.manual,
        ),
        items: (json['items'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => EntryItem.fromJson(jsonMap(e)))
            .toList(),
        createdAt: asInt(json['createdAt']) ?? 0,
        updatedAt: asInt(json['updatedAt']) ?? 0,
        deletedAt: asInt(json['deletedAt']),
      );
}
