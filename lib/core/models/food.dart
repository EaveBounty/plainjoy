import 'json_utils.dart';

class Food {
  final String id;
  final String name;
  final String? brand;
  final String category;
  final String? barcode;
  final String source;
  final String? sourceRef;
  final Map<String, double> nutrientsPer100g;
  final Map<String, double> groupsPer100g;
  final double? defaultServingGrams;
  final String? defaultServingLabel;
  final bool isVerified;
  final List<String> aliases;
  final List<String> tags;
  final bool isComposite;
  final String? recipeId;
  final int createdAt;
  final int updatedAt;
  final int? deletedAt;

  const Food({
    required this.id,
    required this.name,
    this.brand,
    required this.category,
    this.barcode,
    required this.source,
    this.sourceRef,
    required this.nutrientsPer100g,
    this.groupsPer100g = const {},
    this.defaultServingGrams,
    this.defaultServingLabel,
    this.isVerified = false,
    this.aliases = const [],
    this.tags = const [],
    this.isComposite = false,
    this.recipeId,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  double nutrient(String code) => nutrientsPer100g[code] ?? 0;
  double group(String code) => groupsPer100g[code] ?? 0;

  String get searchText {
    final parts = <String>[name, ?brand, ...aliases, ...tags];
    return parts.join(' ').toLowerCase();
  }

  Food copyWith({
    String? name,
    String? brand,
    String? category,
    Map<String, double>? nutrientsPer100g,
    Map<String, double>? groupsPer100g,
    double? defaultServingGrams,
    String? defaultServingLabel,
    bool? isVerified,
    List<String>? aliases,
    List<String>? tags,
    int? updatedAt,
    int? deletedAt,
  }) {
    return Food(
      id: id,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      category: category ?? this.category,
      barcode: barcode,
      source: source,
      sourceRef: sourceRef,
      nutrientsPer100g: nutrientsPer100g ?? this.nutrientsPer100g,
      groupsPer100g: groupsPer100g ?? this.groupsPer100g,
      defaultServingGrams: defaultServingGrams ?? this.defaultServingGrams,
      defaultServingLabel: defaultServingLabel ?? this.defaultServingLabel,
      isVerified: isVerified ?? this.isVerified,
      aliases: aliases ?? this.aliases,
      tags: tags ?? this.tags,
      isComposite: isComposite,
      recipeId: recipeId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'brand': brand,
        'category': category,
        'barcode': barcode,
        'source': source,
        'sourceRef': sourceRef,
        'nutrientsPer100g': nutrientsPer100g,
        'groupsPer100g': groupsPer100g,
        'defaultServingGrams': defaultServingGrams,
        'defaultServingLabel': defaultServingLabel,
        'isVerified': isVerified,
        'aliases': aliases,
        'tags': tags,
        'isComposite': isComposite,
        'recipeId': recipeId,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'deletedAt': deletedAt,
      };

  factory Food.fromJson(Map<String, Object?> json) => Food(
        id: asString(json['id']) ?? '',
        name: asString(json['name']) ?? '未命名',
        brand: asString(json['brand']),
        category: asString(json['category']) ?? 'other',
        barcode: asString(json['barcode']),
        source: asString(json['source']) ?? 'seed',
        sourceRef: asString(json['sourceRef']),
        nutrientsPer100g: asDoubleMap(json['nutrientsPer100g']),
        groupsPer100g: asDoubleMap(json['groupsPer100g']),
        defaultServingGrams: asDouble(json['defaultServingGrams']),
        defaultServingLabel: asString(json['defaultServingLabel']),
        isVerified: asBool(json['isVerified']),
        aliases: asStringList(json['aliases']),
        tags: asStringList(json['tags']),
        isComposite: asBool(json['isComposite']),
        recipeId: asString(json['recipeId']),
        createdAt: asInt(json['createdAt']) ?? 0,
        updatedAt: asInt(json['updatedAt']) ?? 0,
        deletedAt: asInt(json['deletedAt']),
      );
}

class FoodComponent {
  final String foodId;
  final double grams;

  const FoodComponent({required this.foodId, required this.grams});

  Map<String, Object?> toJson() => {'foodId': foodId, 'grams': grams};

  factory FoodComponent.fromJson(Map<String, Object?> json) => FoodComponent(
        foodId: asString(json['foodId']) ?? '',
        grams: asDouble(json['grams']) ?? 0,
      );
}
