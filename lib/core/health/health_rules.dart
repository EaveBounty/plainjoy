import '../models/enums.dart';
import '../models/profile.dart';

enum HealthRuleCategory { avoid, limit, recommend, seeDoctor }

extension HealthRuleCategoryX on HealthRuleCategory {
  String get label => switch (this) {
        HealthRuleCategory.avoid => '避免',
        HealthRuleCategory.limit => '限制',
        HealthRuleCategory.recommend => '推荐',
        HealthRuleCategory.seeDoctor => '需就医',
      };
}

class HealthRule {
  final Condition condition;
  final HealthRuleCategory category;
  final String title;
  final String detail;
  final List<String> foodTags;
  final List<String> nutrientCodes;

  const HealthRule({
    required this.condition,
    required this.category,
    required this.title,
    required this.detail,
    this.foodTags = const [],
    this.nutrientCodes = const [],
  });
}

class HealthRules {
  static List<HealthRule> forProfile(HealthProfile? profile) {
    if (profile == null) return const [];
    final out = <HealthRule>[];
    for (final condition in profile.conditions) {
      out.addAll(_rules[condition] ?? const []);
    }
    if (profile.pregnant) out.addAll(_rules[Condition.pregnancy] ?? const []);
    if (profile.lactating) out.addAll(_rules[Condition.lactating] ?? const []);
    return out;
  }

  static List<HealthRule> get all =>
      _rules.values.expand((e) => e).toList(growable: false);

  static const _rules = <Condition, List<HealthRule>>{
    Condition.hypertension: [
      HealthRule(
        condition: Condition.hypertension,
        category: HealthRuleCategory.limit,
        title: '钠 ≤ 2000 mg/天，理想 1500 mg',
        detail: '酱油、蚝油、豆瓣酱、腌菜、挂面、外卖汤汁都是隐形钠。一勺酱油约等于 1.6 g 盐。',
        foodTags: ['high_sodium', 'processed', 'pickled', 'soup'],
        nutrientCodes: ['sodium_mg'],
      ),
      HealthRule(
        condition: Condition.hypertension,
        category: HealthRuleCategory.recommend,
        title: '多钾、多蔬果',
        detail: '蔬菜 300–500 g、水果 200–350 g、豆类和薯类有助于钾摄入；肾功能异常者需先问医生。',
        foodTags: ['vegetable', 'fruit', 'bean', 'potato'],
        nutrientCodes: ['potassium_mg'],
      ),
      HealthRule(
        condition: Condition.hypertension,
        category: HealthRuleCategory.seeDoctor,
        title: '血压持续偏高请就医',
        detail: '饮食管理不能替代降压药。若收缩压 ≥180 或舒张压 ≥110，或伴胸痛/气促，请立即就医。',
      ),
    ],
    Condition.diabetes: [
      HealthRule(
        condition: Condition.diabetes,
        category: HealthRuleCategory.avoid,
        title: '避免含糖饮料和大量精制糖',
        detail: '一瓶甜饮约 30–50 g 糖；果汁、蜂蜜、糖浆同样计入添加糖。',
        foodTags: ['sugary_drink', 'dessert', 'candy'],
        nutrientCodes: ['sugar_g'],
      ),
      HealthRule(
        condition: Condition.diabetes,
        category: HealthRuleCategory.limit,
        title: '主食定量，优先全谷杂豆',
        detail: '每餐主食约 1 拳头，优先糙米、燕麦、杂豆；搭配蛋白质和蔬菜降低餐后波动。',
        foodTags: ['refined_grain', 'staple'],
        nutrientCodes: ['carb_g', 'fiber_g'],
      ),
      HealthRule(
        condition: Condition.diabetes,
        category: HealthRuleCategory.recommend,
        title: '每餐先菜后饭，保证蛋白质',
        detail: '蔬菜和蛋白质先吃，主食后吃；监测餐后血糖，个体差异很大。',
        foodTags: ['vegetable', 'protein'],
      ),
      HealthRule(
        condition: Condition.diabetes,
        category: HealthRuleCategory.seeDoctor,
        title: '用药与血糖监测需医生管理',
        detail: '本 app 不调整胰岛素或口服药剂量；出现低血糖（心慌、出汗、手抖）请立即处理并就医。',
      ),
    ],
    Condition.prediabetes: [
      HealthRule(
        condition: Condition.prediabetes,
        category: HealthRuleCategory.limit,
        title: '减少添加糖和精制主食',
        detail: '把甜饮换成白水/无糖茶，白米饭换半碗杂粮，是性价比最高的两步。',
        foodTags: ['sugary_drink', 'refined_grain'],
        nutrientCodes: ['sugar_g', 'fiber_g'],
      ),
      HealthRule(
        condition: Condition.prediabetes,
        category: HealthRuleCategory.recommend,
        title: '增加膳食纤维和日常活动',
        detail: '目标纤维 25–30 g/天；餐后散步 10–15 分钟有助于血糖。',
        nutrientCodes: ['fiber_g'],
      ),
    ],
    Condition.gout: [
      HealthRule(
        condition: Condition.gout,
        category: HealthRuleCategory.avoid,
        title: '避免动物内脏、浓肉汤、啤酒',
        detail: '这些是嘌呤/酒精的主要来源；急性发作期尤其严格。',
        foodTags: ['organ_meat', 'broth', 'beer', 'seafood'],
      ),
      HealthRule(
        condition: Condition.gout,
        category: HealthRuleCategory.limit,
        title: '限制红肉、海鲜和果糖',
        detail: '每日肉类适量；含糖饮料和蜂蜜中的果糖会升高尿酸。',
        foodTags: ['red_meat', 'seafood', 'sugary_drink'],
      ),
      HealthRule(
        condition: Condition.gout,
        category: HealthRuleCategory.recommend,
        title: '多喝水，适量奶制品',
        detail: '白水 2000–3000 ml/天（心肾功能正常时）；低脂奶有助于尿酸排泄。',
        foodTags: ['water', 'dairy'],
      ),
      HealthRule(
        condition: Condition.gout,
        category: HealthRuleCategory.seeDoctor,
        title: '急性红肿热痛请就医',
        detail: '降尿酸药和急性期用药需医生决定；不要只靠饮食硬扛。',
      ),
    ],
    Condition.ckd: [
      HealthRule(
        condition: Condition.ckd,
        category: HealthRuleCategory.seeDoctor,
        title: '肾病饮食必须个体化',
        detail: '蛋白质、钾、磷、钠的目标取决于分期和化验值；请让肾内科/营养师给出处方，本 app 只做记录辅助。',
      ),
      HealthRule(
        condition: Condition.ckd,
        category: HealthRuleCategory.limit,
        title: '不要自行高蛋白或高钾饮食',
        detail: '蛋白粉、代盐（常含钾）、大量水果都可能有害；先确认血钾和肾功能。',
        foodTags: ['protein_powder', 'salt_substitute', 'high_potassium'],
      ),
    ],
    Condition.anemia: [
      HealthRule(
        condition: Condition.anemia,
        category: HealthRuleCategory.recommend,
        title: '铁 + 维生素 C 一起吃',
        detail: '瘦红肉、动物血、肝脏（每周一次）含血红素铁；搭配彩椒/猕猴桃/橙子提高吸收。',
        foodTags: ['red_meat', 'liver', 'vitamin_c'],
        nutrientCodes: ['iron_mg', 'vc_mg'],
      ),
      HealthRule(
        condition: Condition.anemia,
        category: HealthRuleCategory.limit,
        title: '餐后少喝浓茶/咖啡',
        detail: '单宁和多酚会抑制非血红素铁吸收；与正餐间隔 1 小时以上。',
        foodTags: ['tea', 'coffee'],
      ),
      HealthRule(
        condition: Condition.anemia,
        category: HealthRuleCategory.seeDoctor,
        title: '先查明贫血原因',
        detail: '缺铁、巨幼细胞、地中海贫血、慢性病贫血处理完全不同；不要长期自行补铁。',
      ),
    ],
    Condition.lactoseIntolerance: [
      HealthRule(
        condition: Condition.lactoseIntolerance,
        category: HealthRuleCategory.limit,
        title: '奶类减量、随餐，不必完全回避',
        detail: '多数人可耐受约 250 ml 牛奶（分次随餐）；酸奶、奶酪、无乳糖奶耐受更好。出现腹胀再减量。',
        foodTags: ['lactose'],
      ),
      HealthRule(
        condition: Condition.lactoseIntolerance,
        category: HealthRuleCategory.recommend,
        title: '用无乳糖奶/强化豆奶补钙',
        detail: '目标钙 800 mg/天；豆腐、绿叶菜、芝麻酱、强化豆奶都是替代来源。',
        nutrientCodes: ['calcium_mg'],
      ),
      HealthRule(
        condition: Condition.lactoseIntolerance,
        category: HealthRuleCategory.seeDoctor,
        title: '严重腹泻/体重下降请就医',
        detail: '需排除乳蛋白过敏、感染性肠炎、IBD 等。',
      ),
    ],
    Condition.vegetarian: [
      HealthRule(
        condition: Condition.vegetarian,
        category: HealthRuleCategory.recommend,
        title: 'B12、铁、锌、Omega-3 是重点',
        detail: 'B12 主要来自动物性食物；纯素者应选择强化食品或补充剂，并定期检查。',
        nutrientCodes: ['vb12_ug', 'iron_mg', 'zinc_mg', 'omega3_g'],
      ),
      HealthRule(
        condition: Condition.vegetarian,
        category: HealthRuleCategory.recommend,
        title: '豆类 + 全谷 + 坚果组合',
        detail: '不同植物蛋白互补；每天大豆/豆制品 25–35 g，坚果 10 g。',
        foodTags: ['bean', 'whole_grain', 'nut'],
      ),
      HealthRule(
        condition: Condition.vegetarian,
        category: HealthRuleCategory.seeDoctor,
        title: '长期纯素建议定期查 B12/铁蛋白',
        detail: '缺乏可能无症状；不要等到贫血或神经症状才补。',
      ),
    ],
    Condition.pregnancy: [
      HealthRule(
        condition: Condition.pregnancy,
        category: HealthRuleCategory.avoid,
        title: '避免酒精、生食、高汞鱼',
        detail: '生鱼片、生蛋、未灭菌奶、鲨鱼/剑鱼/方头鱼等高风险；酒精没有安全剂量。',
        foodTags: ['alcohol', 'raw', 'high_mercury_fish'],
      ),
      HealthRule(
        condition: Condition.pregnancy,
        category: HealthRuleCategory.limit,
        title: '咖啡因 ≤200 mg/天',
        detail: '约等于 1 杯中杯美式；可乐、茶、巧克力也计入。',
        foodTags: ['coffee', 'tea', 'cola'],
      ),
      HealthRule(
        condition: Condition.pregnancy,
        category: HealthRuleCategory.recommend,
        title: '叶酸、铁、钙、DHA',
        detail: '叶酸 600 μgDFE/天（遵医嘱）；铁和钙需求上升；DHA 优先低汞鱼或藻油。',
        nutrientCodes: ['folate_ug', 'iron_mg', 'calcium_mg', 'omega3_g'],
      ),
      HealthRule(
        condition: Condition.pregnancy,
        category: HealthRuleCategory.seeDoctor,
        title: '孕期营养方案以产检医生为准',
        detail: '体重增长、妊娠糖尿病、贫血等需个体化；本 app 不提供诊断或处方。',
      ),
    ],
    Condition.lactating: [
      HealthRule(
        condition: Condition.lactating,
        category: HealthRuleCategory.recommend,
        title: '能量、蛋白质、钙和水分要够',
        detail: '哺乳期能量需求增加；保证优质蛋白、奶类、蔬果和水，不必过度忌口。',
        nutrientCodes: ['energy_kcal', 'protein_g', 'calcium_mg', 'water_ml'],
      ),
      HealthRule(
        condition: Condition.lactating,
        category: HealthRuleCategory.limit,
        title: '咖啡因和酒精谨慎',
        detail: '咖啡因 ≤200 mg/天；酒精建议避免，若饮酒需与哺乳间隔并咨询医生。',
        foodTags: ['coffee', 'alcohol'],
      ),
    ],
  };
}
