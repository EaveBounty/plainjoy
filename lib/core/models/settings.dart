import 'enums.dart';
import 'json_utils.dart';

class AppSettings {
  final ThemeVariant theme;
  final PrecisionTier precision;
  final bool onboardingDone;
  final bool aiEnabled;
  final String aiBaseUrl;
  final String aiModel;
  final String aiApiKey;
  final bool localOnly;
  final int dayStartHour;
  final bool reduceMotion;
  final int seedVersion;
  final String? lastName;

  const AppSettings({
    this.theme = ThemeVariant.editorial,
    this.precision = PrecisionTier.quick,
    this.onboardingDone = false,
    this.aiEnabled = false,
    this.aiBaseUrl = 'https://api.deepseek.com',
    this.aiModel = 'deepseek-flash',
    this.aiApiKey = '',
    this.localOnly = true,
    this.dayStartHour = 4,
    this.reduceMotion = false,
    this.seedVersion = 0,
    this.lastName,
  });

  bool get hasAiKey => aiApiKey.trim().isNotEmpty;

  AppSettings copyWith({
    ThemeVariant? theme,
    PrecisionTier? precision,
    bool? onboardingDone,
    bool? aiEnabled,
    String? aiBaseUrl,
    String? aiModel,
    String? aiApiKey,
    bool? localOnly,
    int? dayStartHour,
    bool? reduceMotion,
    int? seedVersion,
    String? lastName,
  }) {
    return AppSettings(
      theme: theme ?? this.theme,
      precision: precision ?? this.precision,
      onboardingDone: onboardingDone ?? this.onboardingDone,
      aiEnabled: aiEnabled ?? this.aiEnabled,
      aiBaseUrl: aiBaseUrl ?? this.aiBaseUrl,
      aiModel: aiModel ?? this.aiModel,
      aiApiKey: aiApiKey ?? this.aiApiKey,
      localOnly: localOnly ?? this.localOnly,
      dayStartHour: dayStartHour ?? this.dayStartHour,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      seedVersion: seedVersion ?? this.seedVersion,
      lastName: lastName ?? this.lastName,
    );
  }

  Map<String, Object?> toJson() => {
        'theme': theme.name,
        'precision': precision.name,
        'onboardingDone': onboardingDone,
        'aiEnabled': aiEnabled,
        'aiBaseUrl': aiBaseUrl,
        'aiModel': aiModel,
        'aiApiKey': aiApiKey,
        'localOnly': localOnly,
        'dayStartHour': dayStartHour,
        'reduceMotion': reduceMotion,
        'seedVersion': seedVersion,
        'lastName': lastName,
      };

  factory AppSettings.fromJson(Map<String, Object?> json) => AppSettings(
        theme: ThemeVariant.values.firstWhere(
          (e) => e.name == asString(json['theme']),
          orElse: () => ThemeVariant.editorial,
        ),
        precision: PrecisionTier.values.firstWhere(
          (e) => e.name == asString(json['precision']),
          orElse: () => PrecisionTier.quick,
        ),
        onboardingDone: asBool(json['onboardingDone']),
        aiEnabled: asBool(json['aiEnabled']),
        aiBaseUrl: asString(json['aiBaseUrl']) ?? 'https://api.deepseek.com',
        aiModel: asString(json['aiModel']) ?? 'deepseek-flash',
        aiApiKey: asString(json['aiApiKey']) ?? '',
        localOnly: asBool(json['localOnly'], fallback: true),
        dayStartHour: asInt(json['dayStartHour']) ?? 4,
        reduceMotion: asBool(json['reduceMotion']),
        seedVersion: asInt(json['seedVersion']) ?? 0,
        lastName: asString(json['lastName']),
      );
}
