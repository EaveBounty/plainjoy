import 'enums.dart';
import 'json_utils.dart';

class Pet {
  final String id;
  final String profileId;
  final PetSpecies species;
  final String name;
  final int bornAt;
  final int xp;
  final int coins;
  final int level;
  final int lastFedDayMs;
  final int updatedAt;

  const Pet({
    required this.id,
    required this.profileId,
    required this.species,
    required this.name,
    required this.bornAt,
    this.xp = 0,
    this.coins = 120,
    this.level = 1,
    this.lastFedDayMs = 0,
    this.updatedAt = 0,
  });

  int get xpToNext => level * 120;

  Pet copyWith({
    PetSpecies? species,
    String? name,
    int? xp,
    int? coins,
    int? level,
    int? lastFedDayMs,
    int? updatedAt,
  }) {
    return Pet(
      id: id,
      profileId: profileId,
      species: species ?? this.species,
      name: name ?? this.name,
      bornAt: bornAt,
      xp: xp ?? this.xp,
      coins: coins ?? this.coins,
      level: level ?? this.level,
      lastFedDayMs: lastFedDayMs ?? this.lastFedDayMs,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'profileId': profileId,
        'species': species.name,
        'name': name,
        'bornAt': bornAt,
        'xp': xp,
        'coins': coins,
        'level': level,
        'lastFedDayMs': lastFedDayMs,
        'updatedAt': updatedAt,
      };

  factory Pet.fromJson(Map<String, Object?> json) => Pet(
        id: asString(json['id']) ?? '',
        profileId: asString(json['profileId']) ?? '',
        species: PetSpecies.values.firstWhere(
          (e) => e.name == asString(json['species']),
          orElse: () => PetSpecies.calicoCat,
        ),
        name: asString(json['name']) ?? '小满',
        bornAt: asInt(json['bornAt']) ?? 0,
        xp: asInt(json['xp']) ?? 0,
        coins: asInt(json['coins']) ?? 120,
        level: asInt(json['level']) ?? 1,
        lastFedDayMs: asInt(json['lastFedDayMs']) ?? 0,
        updatedAt: asInt(json['updatedAt']) ?? 0,
      );
}

class PetAxes {
  final int vitality;
  final int coat;
  final int mood;
  final int hydration;

  const PetAxes({
    this.vitality = 60,
    this.coat = 60,
    this.mood = 60,
    this.hydration = 60,
  });

  int get lowest {
    final values = [vitality, coat, mood, hydration];
    values.sort();
    return values.first;
  }

  String get lowestKey {
    final values = {
      'vitality': vitality,
      'coat': coat,
      'mood': mood,
      'hydration': hydration,
    };
    final sorted = values.entries.toList()..sort((a, b) => a.value.compareTo(b.value));
    return sorted.first.key;
  }

  int get secondLowest {
    final values = [vitality, coat, mood, hydration]..sort();
    return values[1];
  }

  Map<String, int> toJson() => {
        'vitality': vitality,
        'coat': coat,
        'mood': mood,
        'hydration': hydration,
      };

  factory PetAxes.fromJson(Map<String, Object?> json) => PetAxes(
        vitality: asInt(json['vitality']) ?? 60,
        coat: asInt(json['coat']) ?? 60,
        mood: asInt(json['mood']) ?? 60,
        hydration: asInt(json['hydration']) ?? 60,
      );
}

class PetStateSnapshot {
  final String id;
  final String petId;
  final String localDate;
  final PetAxes axes;
  final Map<String, double> drivers;
  final String reason;
  final int capturedAt;

  const PetStateSnapshot({
    required this.id,
    required this.petId,
    required this.localDate,
    required this.axes,
    this.drivers = const {},
    this.reason = 'daily',
    required this.capturedAt,
  });

  Map<String, Object?> toJson() => {
        'id': id,
        'petId': petId,
        'localDate': localDate,
        'axes': axes.toJson(),
        'drivers': drivers,
        'reason': reason,
        'capturedAt': capturedAt,
      };

  factory PetStateSnapshot.fromJson(Map<String, Object?> json) => PetStateSnapshot(
        id: asString(json['id']) ?? '',
        petId: asString(json['petId']) ?? '',
        localDate: asString(json['localDate']) ?? '1970-01-01',
        axes: PetAxes.fromJson(jsonMap(json['axes'])),
        drivers: asDoubleMap(json['drivers']),
        reason: asString(json['reason']) ?? 'daily',
        capturedAt: asInt(json['capturedAt']) ?? 0,
      );
}
