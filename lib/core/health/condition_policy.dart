import '../models/enums.dart';
import '../models/nutrients.dart';
import '../models/profile.dart';

/// 证据等级：只用来提示「这条建议有多硬」，不冒充临床指南。
enum EvidenceLevel { guideline, consensus, mechanism }

extension EvidenceLevelX on EvidenceLevel {
  String get label => switch (this) {
        EvidenceLevel.guideline => '指南',
        EvidenceLevel.consensus => '共识',
        EvidenceLevel.mechanism => '机制',
      };
}

class NutrientGoal {
  final double? min;
  final double? max;
  final String reason;

  const NutrientGoal({this.min, this.max, required this.reason});
}

class ConditionPolicy {
  final Condition condition;
  final String summary;

  /// 对 16 项评分权重的乘数（只放大/缩小，不新增项目）
  final Map<String, double> weightMultipliers;

  /// 目标覆盖：营养代码 -> 目标区间
  final Map<String, NutrientGoal> goals;

  /// 需要在页面上单独提示的禁忌/注意
  final List<String> cautions;

  /// 需要额外纳入评分的限制项（目前只有 CKD 的钾/磷）
  final bool limitPotassium;
  final bool limitPhosphorus;

  /// 嘌呤/果糖等没有逐条数值，用标签做定性提醒
  final bool purineSensitive;

  const ConditionPolicy({
    required this.condition,
    required this.summary,
    this.weightMultipliers = const {},
    this.goals = const {},
    this.cautions = const [],
    this.limitPotassium = false,
    this.limitPhosphorus = false,
    this.purineSensitive = false,
  });
}

/// 病况 -> 目标/权重/提醒。
///
/// 原则：
/// 1. 只改「目标」和「权重」，不改评分算法本身；
/// 2. 数值全部给区间/上限，并附证据等级与「需医生确认」的场景；
/// 3. 肾病、孕期、痛风急性期等高风险场景，永远保留就医提示。
class ConditionPolicies {
  static const _policies = <Condition, ConditionPolicy>{
    Condition.hypertension: ConditionPolicy(
      condition: Condition.hypertension,
      summary: '钠更严，钾和蔬菜加权；酒精会抵消这部分收益。',
      weightMultipliers: {'C1': 1.8, 'A1': 1.25, 'A2': 1.1},
      goals: {
        NutrientCode.sodium: NutrientGoal(min: 1500, max: 2000, reason: '中国高血压防治指南：钠 <2000 mg/d（约 5 g 盐），理想 1500 mg'),
        NutrientCode.potassium: NutrientGoal(min: 3600, reason: '钾 3600 mg/d 与降压相关；肾功能异常者例外'),
      },
      cautions: ['正在服用 ACEI/ARB/保钾利尿剂，或血钾偏高：不要自行补钾/低钠盐。'],
    ),
    Condition.diabetes: ConditionPolicy(
      condition: Condition.diabetes,
      summary: '添加糖和精制主食加权，纤维加权；不看 GI 单指标。',
      weightMultipliers: {'C2': 1.7, 'A3': 1.3, 'B2': 1.4},
      goals: {
        NutrientCode.sugar: NutrientGoal(max: 25, reason: '添加糖 <10%E，理想 <5%E（约 25 g）'),
        NutrientCode.fiber: NutrientGoal(min: 30, reason: '膳食纤维 25–30 g/d，延缓餐后血糖'),
      },
      cautions: ['不调整胰岛素/口服药剂量；反复低血糖请就医。'],
    ),
    Condition.prediabetes: ConditionPolicy(
      condition: Condition.prediabetes,
      summary: '先减甜饮和精制主食，再谈其他。',
      weightMultipliers: {'C2': 1.5, 'A3': 1.25, 'B2': 1.25},
      goals: {
        NutrientCode.sugar: NutrientGoal(max: 25, reason: '添加糖 <5–10%E'),
        NutrientCode.fiber: NutrientGoal(min: 25, reason: '纤维 25 g/d 以上'),
      },
    ),
    Condition.gout: ConditionPolicy(
      condition: Condition.gout,
      summary: '嘌呤与果糖是重点；蛋白总量不必过低，但来源要换。',
      weightMultipliers: {'C2': 1.5, 'A6': 0.7, 'A5': 1.15},
      goals: {
        NutrientCode.sugar: NutrientGoal(max: 25, reason: '果糖（尤其甜饮）升高尿酸'),
        NutrientCode.water: NutrientGoal(min: 2500, reason: '心肾功能正常时，白水 2000–3000 ml/d'),
      },
      purineSensitive: true,
      cautions: ['急性红肿热痛期：饮食不能替代抗炎治疗，请就医。', '浓肉汤、内脏、啤酒、部分海鲜按「高嘌呤」处理。'],
    ),
    Condition.ckd: ConditionPolicy(
      condition: Condition.ckd,
      summary: '蛋白、钾、磷、钠都要个体化；默认只做保守上限。',
      weightMultipliers: {'B1': 0.9, 'A6': 0.7, 'C1': 1.6, 'C4': 1.0, 'C5': 1.0},
      goals: {
        NutrientCode.sodium: NutrientGoal(max: 2000, reason: 'CKD 通常钠 <2000 mg，具体看血压与水肿'),
        NutrientCode.potassium: NutrientGoal(max: 2500, reason: '仅作保守上限；血钾目标由肾内科决定'),
        NutrientCode.phosphorus: NutrientGoal(max: 1000, reason: 'CKD 3–5 期常需限磷 800–1000 mg'),
      },
      limitPotassium: true,
      limitPhosphorus: true,
      cautions: ['低钠盐、代盐常含钾，CKD 慎用。', '蛋白目标按体重计算：非透析 0.6–0.8 g/kg，透析 1.0–1.2 g/kg；以化验单为准。'],
    ),
    Condition.anemia: ConditionPolicy(
      condition: Condition.anemia,
      summary: '铁和维 C 一起看；先查明贫血类型。',
      weightMultipliers: {'B4': 2.0, 'B6': 1.25, 'A6': 1.1},
      goals: {
        NutrientCode.iron: NutrientGoal(min: 20, reason: '女性 RNI 20 mg/d、男性 12 mg/d；确诊缺铁性贫血后的元素铁剂量由医生开具，本 app 不给药量'),
        NutrientCode.vitaminC: NutrientGoal(min: 200, reason: '维 C 与铁同餐可提高非血红素铁吸收'),
      },
      cautions: ['地中海贫血/慢性病贫血不应盲目补铁；先查血常规、铁蛋白。'],
    ),
    Condition.lactoseIntolerance: ConditionPolicy(
      condition: Condition.lactoseIntolerance,
      summary: '奶类权重下调，钙的目标不降。',
      weightMultipliers: {'A4': 0.7, 'B3': 1.3},
      goals: {
        NutrientCode.calcium: NutrientGoal(min: 800, reason: '用无乳糖奶/酸奶/奶酪/强化豆奶/豆腐补钙'),
      },
    ),
    Condition.vegetarian: ConditionPolicy(
      condition: Condition.vegetarian,
      summary: 'B12、铁、锌、Omega-3 是结构性短板。',
      weightMultipliers: {'B7': 1.6, 'B4': 1.25, 'A5': 1.2, 'A6': 0.4},
      goals: {
        NutrientCode.vitaminB12: NutrientGoal(min: 2.4, reason: '纯素必须靠强化食品或补充剂；植物性食物几乎不含'),
        NutrientCode.iron: NutrientGoal(min: 20, reason: '非血红素铁吸收率低，需求约 1.8 倍'),
        NutrientCode.zinc: NutrientGoal(min: 12, reason: '植酸影响锌吸收'),
      },
      cautions: ['长期纯素建议每年查 B12、铁蛋白、同型半胱氨酸。'],
    ),
    Condition.pregnancy: ConditionPolicy(
      condition: Condition.pregnancy,
      summary: '叶酸、铁、碘、钙、DHA 五项优先。',
      weightMultipliers: {'B7': 1.9, 'B4': 1.3, 'B3': 1.2},
      goals: {
        NutrientCode.folate: NutrientGoal(min: 600, reason: '孕期 600 μgDFE/d（补充剂遵医嘱）'),
        NutrientCode.iron: NutrientGoal(min: 27, reason: '孕中晚期铁需求上升'),
        NutrientCode.calcium: NutrientGoal(min: 1000, reason: '孕中晚期钙 1000 mg/d'),
        NutrientCode.iodine: NutrientGoal(min: 230, reason: '孕期碘 230 μg/d；用加碘盐并每周 1–2 次海带/紫菜'),
      },
      cautions: ['酒精没有安全剂量；生食、高汞鱼、未灭菌奶避免。'],
    ),
    Condition.lactating: ConditionPolicy(
      condition: Condition.lactating,
      summary: '能量、蛋白、钙、碘、水分都要上调。',
      weightMultipliers: {'B1': 1.25, 'B3': 1.2, 'C1': 1.1},
      goals: {
        NutrientCode.protein: NutrientGoal(min: 80, reason: '哺乳期蛋白 +25 g/d'),
        NutrientCode.calcium: NutrientGoal(min: 1000, reason: '哺乳期钙 1000 mg/d'),
        NutrientCode.iodine: NutrientGoal(min: 240, reason: '哺乳期碘 240 μg/d'),
        NutrientCode.water: NutrientGoal(min: 2500, reason: '哺乳期水分需求增加'),
      },
    ),
  };

  static ConditionPolicy of(Condition condition) =>
      _policies[condition] ??
      ConditionPolicy(condition: condition, summary: '');

  static List<ConditionPolicy> forProfile(HealthProfile? profile) {
    if (profile == null) return const [];
    final out = <ConditionPolicy>[];
    for (final condition in profile.conditions) {
      final policy = _policies[condition];
      if (policy != null) out.add(policy);
    }
    if (profile.pregnant && !profile.conditions.contains(Condition.pregnancy)) {
      out.add(_policies[Condition.pregnancy]!);
    }
    if (profile.lactating && !profile.conditions.contains(Condition.lactating)) {
      out.add(_policies[Condition.lactating]!);
    }
    return out;
  }

  /// 多个病况叠加时的目标合并：
  /// 上限取最严，下限取最高；冲突时保留更保守的一条。
  static Map<String, NutrientGoal> mergeGoals(List<ConditionPolicy> policies) {
    final out = <String, NutrientGoal>{};
    for (final policy in policies) {
      for (final entry in policy.goals.entries) {
        final current = out[entry.key];
        if (current == null) {
          out[entry.key] = entry.value;
          continue;
        }
        final max = _stricterMax(current.max, entry.value.max);
        final min = _higherMin(current.min, entry.value.min);
        final conflict = min != null && max != null && min > max;
        out[entry.key] = NutrientGoal(
          // 下限高于上限时，保留更保守的上限，丢弃下限并写明冲突
          min: conflict ? null : min,
          max: max,
          reason: conflict
              ? '${current.reason}；${entry.value.reason}（上下限冲突，已按更严格的上限收紧）'
              : '${current.reason}；${entry.value.reason}',
        );
      }
    }
    return out;
  }

  static double? _stricterMax(double? a, double? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a < b ? a : b;
  }

  static double? _higherMin(double? a, double? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a > b ? a : b;
  }

  static Map<String, double> mergeWeights(List<ConditionPolicy> policies) {
    final out = <String, double>{};
    for (final policy in policies) {
      for (final entry in policy.weightMultipliers.entries) {
        out[entry.key] = (out[entry.key] ?? 1) * entry.value;
      }
    }
    return out;
  }

  static bool any(List<ConditionPolicy> policies, bool Function(ConditionPolicy) test) =>
      policies.any(test);
}
