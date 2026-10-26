enum Sex { male, female, other, preferNot }

extension SexX on Sex {
  String get label => switch (this) {
        Sex.male => '男',
        Sex.female => '女',
        Sex.other => '其他',
        Sex.preferNot => '不透露',
      };
}

enum ActivityLevel { sedentary, light, moderate, active, veryActive }

extension ActivityLevelX on ActivityLevel {
  String get label => switch (this) {
        ActivityLevel.sedentary => '久坐',
        ActivityLevel.light => '轻体力',
        ActivityLevel.moderate => '中体力',
        ActivityLevel.active => '高体力',
        ActivityLevel.veryActive => '极高',
      };

  double get pal => switch (this) {
        ActivityLevel.sedentary => 1.2,
        ActivityLevel.light => 1.375,
        ActivityLevel.moderate => 1.55,
        ActivityLevel.active => 1.725,
        ActivityLevel.veryActive => 1.9,
      };
}

enum Goal { lose, maintain, gain }

extension GoalX on Goal {
  String get label => switch (this) {
        Goal.lose => '减脂',
        Goal.maintain => '维持',
        Goal.gain => '增肌',
      };
}

enum MealSlot { breakfast, lunch, dinner, snack }

extension MealSlotX on MealSlot {
  String get label => switch (this) {
        MealSlot.breakfast => '早餐',
        MealSlot.lunch => '午餐',
        MealSlot.dinner => '晚餐',
        MealSlot.snack => '加餐',
      };

  String get key => name;
}

enum InputMode { manual, text, photo, plan, quick }

enum EstimateMethod { weighed, container, reference, visual, ai, plan }

extension EstimateMethodX on EstimateMethod {
  String get label => switch (this) {
        EstimateMethod.weighed => '称重',
        EstimateMethod.container => '容器',
        EstimateMethod.reference => '参照物',
        EstimateMethod.visual => '目测',
        EstimateMethod.ai => 'AI 估算',
        EstimateMethod.plan => '来自计划',
      };
}

enum PrecisionTier { quick, standard, precise }

extension PrecisionTierX on PrecisionTier {
  String get label => switch (this) {
        PrecisionTier.quick => '10 秒快速',
        PrecisionTier.standard => '60 秒标准',
        PrecisionTier.precise => '3 分钟精确',
      };

  String get hint => switch (this) {
        PrecisionTier.quick => '少/中/多 + 剩饭，误差约 ±35–45%',
        PrecisionTier.standard => '照片 + 容器/参照物，误差约 ±20–25%',
        PrecisionTier.precise => '秤/量杯 + 剩饭扣除，误差约 ±8–10%',
      };

  double get relativeSpread => switch (this) {
        PrecisionTier.quick => 0.40,
        PrecisionTier.standard => 0.22,
        PrecisionTier.precise => 0.09,
      };
}

enum ThemeVariant { editorial, q }

extension ThemeVariantX on ThemeVariant {
  String get label => switch (this) {
        ThemeVariant.editorial => '报告版',
        ThemeVariant.q => '绘本版',
      };

  String get description => switch (this) {
        ThemeVariant.editorial => '克制、清晰，像一份体检报告',
        ThemeVariant.q => '软糯、有陪伴感，像一本绘本',
      };
}

enum Condition {
  hypertension,
  diabetes,
  prediabetes,
  gout,
  ckd,
  anemia,
  lactoseIntolerance,
  vegetarian,
  pregnancy,
  lactating,
}

extension ConditionX on Condition {
  String get label => switch (this) {
        Condition.hypertension => '高血压',
        Condition.diabetes => '糖尿病',
        Condition.prediabetes => '糖尿病前期',
        Condition.gout => '痛风 / 高尿酸',
        Condition.ckd => '慢性肾病',
        Condition.anemia => '贫血',
        Condition.lactoseIntolerance => '乳糖不耐',
        Condition.vegetarian => '素食',
        Condition.pregnancy => '孕期',
        Condition.lactating => '哺乳期',
      };
}

enum PreferenceEntityType { food, dish, trait, context }

extension PreferenceEntityTypeX on PreferenceEntityType {
  String get label => switch (this) {
        PreferenceEntityType.food => '食物',
        PreferenceEntityType.dish => '菜品',
        PreferenceEntityType.trait => '口味特征',
        PreferenceEntityType.context => '场景',
      };
}

enum PlanStatus { draft, active, archived }

enum PetSpecies {
  calicoCat,
  tabbyCat,
  orangeCat,
  tuxedoCat,
  shibaInu,
  corgi,
  tuxedoDog,
}

extension PetSpeciesX on PetSpecies {
  String get label => switch (this) {
        PetSpecies.calicoCat => '三花猫',
        PetSpecies.tabbyCat => '狸花猫',
        PetSpecies.orangeCat => '橘猫',
        PetSpecies.tuxedoCat => '奶牛猫',
        PetSpecies.shibaInu => '柴犬',
        PetSpecies.corgi => '柯基',
        PetSpecies.tuxedoDog => '中华田园犬',
      };

  bool get isCat => this == PetSpecies.calicoCat ||
      this == PetSpecies.tabbyCat ||
      this == PetSpecies.orangeCat ||
      this == PetSpecies.tuxedoCat;

  int get price => switch (this) {
        PetSpecies.calicoCat || PetSpecies.tuxedoDog => 0,
        PetSpecies.tabbyCat || PetSpecies.orangeCat || PetSpecies.shibaInu => 480,
        PetSpecies.tuxedoCat || PetSpecies.corgi => 1200,
      };

  String get speciesKey => isCat ? 'cat' : 'dog';
}

enum ScoreDomain { foodGroups, nutrients, limits }

extension ScoreDomainX on ScoreDomain {
  String get label => switch (this) {
        ScoreDomain.foodGroups => '食物组',
        ScoreDomain.nutrients => '营养素',
        ScoreDomain.limits => '限制项',
      };

  double get weight => switch (this) {
        ScoreDomain.foodGroups => 0.40,
        ScoreDomain.nutrients => 0.32,
        ScoreDomain.limits => 0.28,
      };
}

enum ScoreStatus { low, ok, high, veryHigh, unknown }

extension ScoreStatusX on ScoreStatus {
  String get label => switch (this) {
        ScoreStatus.low => '不足',
        ScoreStatus.ok => '达标',
        ScoreStatus.high => '偏多',
        ScoreStatus.veryHigh => '明显偏多',
        ScoreStatus.unknown => '数据不足',
      };
}

enum PetSignal { idle, hungry, thirsty, sleepy, lowEnergy, proud, celebrate }
