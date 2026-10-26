import 'json_utils.dart';

class FoodContainer {
  final String id;
  final String name;
  final double capacityMl;
  final double tareG;
  final double fillRatio;
  final String shape;
  final double densityHint;
  final bool builtin;
  final int updatedAt;

  const FoodContainer({
    required this.id,
    required this.name,
    required this.capacityMl,
    this.tareG = 0,
    this.fillRatio = 0.8,
    this.shape = 'bowl',
    this.densityHint = 1.0,
    this.builtin = false,
    this.updatedAt = 0,
  });

  double estimateGrams({double? fillRatioOverride, double? densityOverride}) {
    final fill = fillRatioOverride ?? fillRatio;
    final density = densityOverride ?? densityHint;
    return capacityMl * fill * density;
  }

  FoodContainer copyWith({
    String? name,
    double? capacityMl,
    double? tareG,
    double? fillRatio,
    String? shape,
    double? densityHint,
    int? updatedAt,
  }) {
    return FoodContainer(
      id: id,
      name: name ?? this.name,
      capacityMl: capacityMl ?? this.capacityMl,
      tareG: tareG ?? this.tareG,
      fillRatio: fillRatio ?? this.fillRatio,
      shape: shape ?? this.shape,
      densityHint: densityHint ?? this.densityHint,
      builtin: builtin,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'capacityMl': capacityMl,
        'tareG': tareG,
        'fillRatio': fillRatio,
        'shape': shape,
        'densityHint': densityHint,
        'builtin': builtin,
        'updatedAt': updatedAt,
      };

  factory FoodContainer.fromJson(Map<String, Object?> json) => FoodContainer(
        id: asString(json['id']) ?? '',
        name: asString(json['name']) ?? '容器',
        capacityMl: asDouble(json['capacityMl']) ?? 300,
        tareG: asDouble(json['tareG']) ?? 0,
        fillRatio: asDouble(json['fillRatio']) ?? 0.8,
        shape: asString(json['shape']) ?? 'bowl',
        densityHint: asDouble(json['densityHint']) ?? 1.0,
        builtin: asBool(json['builtin']),
        updatedAt: asInt(json['updatedAt']) ?? 0,
      );
}

class ReferenceObject {
  final String id;
  final String name;
  final String category;
  final double lengthMm;
  final double widthMm;
  final double heightMm;
  final double weightG;
  final bool builtin;
  final String hint;

  const ReferenceObject({
    required this.id,
    required this.name,
    required this.category,
    this.lengthMm = 0,
    this.widthMm = 0,
    this.heightMm = 0,
    this.weightG = 0,
    this.builtin = false,
    this.hint = '',
  });

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'lengthMm': lengthMm,
        'widthMm': widthMm,
        'heightMm': heightMm,
        'weightG': weightG,
        'builtin': builtin,
        'hint': hint,
      };

  factory ReferenceObject.fromJson(Map<String, Object?> json) => ReferenceObject(
        id: asString(json['id']) ?? '',
        name: asString(json['name']) ?? '参照物',
        category: asString(json['category']) ?? 'hand',
        lengthMm: asDouble(json['lengthMm']) ?? 0,
        widthMm: asDouble(json['widthMm']) ?? 0,
        heightMm: asDouble(json['heightMm']) ?? 0,
        weightG: asDouble(json['weightG']) ?? 0,
        builtin: asBool(json['builtin']),
        hint: asString(json['hint']) ?? '',
      );
}
