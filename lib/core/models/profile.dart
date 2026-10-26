import 'enums.dart';
import 'json_utils.dart';

class HealthProfile {
  final String id;
  final String nickname;
  final int? birthYear;
  final Sex sex;
  final double? heightCm;
  final double? weightKg;
  final ActivityLevel activity;
  final Goal goal;
  final Set<Condition> conditions;
  final Set<String> allergies;
  final bool pregnant;
  final bool lactating;
  final bool ckdDialysis;
  final String dietaryPattern;
  final double? targetKcalOverride;
  final double? targetProteinOverride;
  final double? targetSodiumOverride;
  final int dayStartHour;
  final Set<String> equipment;
  final int updatedAt;

  const HealthProfile({
    required this.id,
    required this.nickname,
    this.birthYear,
    required this.sex,
    this.heightCm,
    this.weightKg,
    required this.activity,
    required this.goal,
    this.conditions = const {},
    this.allergies = const {},
    this.pregnant = false,
    this.lactating = false,
    this.ckdDialysis = false,
    this.dietaryPattern = 'omnivore',
    this.targetKcalOverride,
    this.targetProteinOverride,
    this.targetSodiumOverride,
    this.dayStartHour = 4,
    this.equipment = const {'induction', 'riceCooker'},
    this.updatedAt = 0,
  });

  int? get age {
    final y = birthYear;
    if (y == null) return null;
    return DateTime.now().year - y;
  }

  bool get isVegetarian =>
      conditions.contains(Condition.vegetarian) ||
      dietaryPattern == 'vegetarian' ||
      dietaryPattern == 'vegan';

  bool get isVegan => dietaryPattern == 'vegan';

  bool has(Condition condition) => conditions.contains(condition);

  HealthProfile copyWith({
    String? nickname,
    int? birthYear,
    Sex? sex,
    double? heightCm,
    double? weightKg,
    ActivityLevel? activity,
    Goal? goal,
    Set<Condition>? conditions,
    Set<String>? allergies,
    bool? pregnant,
    bool? lactating,
    bool? ckdDialysis,
    String? dietaryPattern,
    double? targetKcalOverride,
    double? targetProteinOverride,
    double? targetSodiumOverride,
    int? dayStartHour,
    Set<String>? equipment,
    int? updatedAt,
  }) {
    return HealthProfile(
      id: id,
      nickname: nickname ?? this.nickname,
      birthYear: birthYear ?? this.birthYear,
      sex: sex ?? this.sex,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      activity: activity ?? this.activity,
      goal: goal ?? this.goal,
      conditions: conditions ?? this.conditions,
      allergies: allergies ?? this.allergies,
      pregnant: pregnant ?? this.pregnant,
      lactating: lactating ?? this.lactating,
      ckdDialysis: ckdDialysis ?? this.ckdDialysis,
      dietaryPattern: dietaryPattern ?? this.dietaryPattern,
      targetKcalOverride: targetKcalOverride ?? this.targetKcalOverride,
      targetProteinOverride: targetProteinOverride ?? this.targetProteinOverride,
      targetSodiumOverride: targetSodiumOverride ?? this.targetSodiumOverride,
      dayStartHour: dayStartHour ?? this.dayStartHour,
      equipment: equipment ?? this.equipment,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'nickname': nickname,
        'birthYear': birthYear,
        'sex': sex.name,
        'heightCm': heightCm,
        'weightKg': weightKg,
        'activity': activity.name,
        'goal': goal.name,
        'conditions': conditions.map((e) => e.name).toList(),
        'allergies': allergies.toList(),
        'pregnant': pregnant,
        'lactating': lactating,
        'ckdDialysis': ckdDialysis,
        'dietaryPattern': dietaryPattern,
        'targetKcalOverride': targetKcalOverride,
        'targetProteinOverride': targetProteinOverride,
        'targetSodiumOverride': targetSodiumOverride,
        'dayStartHour': dayStartHour,
        'equipment': equipment.toList(),
        'updatedAt': updatedAt,
      };

  factory HealthProfile.fromJson(Map<String, Object?> json) => HealthProfile(
        id: asString(json['id']) ?? '',
        nickname: asString(json['nickname']) ?? '我',
        birthYear: asInt(json['birthYear']),
        sex: Sex.values.firstWhere(
          (e) => e.name == asString(json['sex']),
          orElse: () => Sex.preferNot,
        ),
        heightCm: asDouble(json['heightCm']),
        weightKg: asDouble(json['weightKg']),
        activity: ActivityLevel.values.firstWhere(
          (e) => e.name == asString(json['activity']),
          orElse: () => ActivityLevel.light,
        ),
        goal: Goal.values.firstWhere(
          (e) => e.name == asString(json['goal']),
          orElse: () => Goal.maintain,
        ),
        conditions: (asStringList(json['conditions']))
            .map((e) => Condition.values.where((c) => c.name == e))
            .expand((e) => e)
            .toSet(),
        allergies: asStringList(json['allergies']).toSet(),
        pregnant: asBool(json['pregnant']),
        lactating: asBool(json['lactating']),
        ckdDialysis: asBool(json['ckdDialysis']),
        dietaryPattern: asString(json['dietaryPattern']) ?? 'omnivore',
        targetKcalOverride: asDouble(json['targetKcalOverride']),
        targetProteinOverride: asDouble(json['targetProteinOverride']),
        targetSodiumOverride: asDouble(json['targetSodiumOverride']),
        dayStartHour: asInt(json['dayStartHour']) ?? 4,
        equipment: asStringList(json['equipment']).toSet(),
        updatedAt: asInt(json['updatedAt']) ?? 0,
      );
}
