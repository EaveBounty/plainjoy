import 'enums.dart';
import 'json_utils.dart';

class Preference {
  final String id;
  final String profileId;
  final PreferenceEntityType entityType;
  final String entityId;
  final String label;
  final int stars;
  final bool avoid;
  final bool allergy;
  final List<String> tags;
  final int evidenceCount;
  final String source;
  final int updatedAt;

  const Preference({
    required this.id,
    required this.profileId,
    required this.entityType,
    required this.entityId,
    required this.label,
    required this.stars,
    this.avoid = false,
    this.allergy = false,
    this.tags = const [],
    this.evidenceCount = 1,
    this.source = 'explicit',
    required this.updatedAt,
  });

  Preference copyWith({
    int? stars,
    bool? avoid,
    bool? allergy,
    List<String>? tags,
    int? evidenceCount,
    String? source,
    int? updatedAt,
  }) {
    return Preference(
      id: id,
      profileId: profileId,
      entityType: entityType,
      entityId: entityId,
      label: label,
      stars: stars ?? this.stars,
      avoid: avoid ?? this.avoid,
      allergy: allergy ?? this.allergy,
      tags: tags ?? this.tags,
      evidenceCount: evidenceCount ?? this.evidenceCount,
      source: source ?? this.source,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'profileId': profileId,
        'entityType': entityType.name,
        'entityId': entityId,
        'label': label,
        'stars': stars,
        'avoid': avoid,
        'allergy': allergy,
        'tags': tags,
        'evidenceCount': evidenceCount,
        'source': source,
        'updatedAt': updatedAt,
      };

  factory Preference.fromJson(Map<String, Object?> json) => Preference(
        id: asString(json['id']) ?? '',
        profileId: asString(json['profileId']) ?? '',
        entityType: PreferenceEntityType.values.firstWhere(
          (e) => e.name == asString(json['entityType']),
          orElse: () => PreferenceEntityType.food,
        ),
        entityId: asString(json['entityId']) ?? '',
        label: asString(json['label']) ?? '',
        stars: asInt(json['stars']) ?? 3,
        avoid: asBool(json['avoid']),
        allergy: asBool(json['allergy']),
        tags: asStringList(json['tags']),
        evidenceCount: asInt(json['evidenceCount']) ?? 1,
        source: asString(json['source']) ?? 'explicit',
        updatedAt: asInt(json['updatedAt']) ?? 0,
      );
}
