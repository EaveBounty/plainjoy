import '../models/entry.dart';
import '../models/enums.dart';
import '../models/nutrients.dart';
import '../models/profile.dart';
import '../scoring/nutrient_targets.dart';

class HealthAdvice {
  final String title;
  final String body;
  final String evidence;
  final Condition? condition;
  final int priority;

  const HealthAdvice({
    required this.title,
    required this.body,
    required this.evidence,
    this.condition,
    this.priority = 50,
  });
}

/// 把「今天吃了什么」翻译成「下一口怎么改」。
///
/// 只输出可执行动作 + 数字来源；不输出诊断，不调整药量。
/// 病况相关建议优先于通用建议。
class AdviceEngine {
  static List<HealthAdvice> forDay({
    required HealthProfile? profile,
    required Map<String, double> totals,
    required List<FoodEntry> entries,
    Map<String, double> groupTotals = const {},
    NutrientTargets? targetsOverride,
  }) {
    final t = targetsOverride ?? NutrientTargets.fromProfile(profile);
    final out = <HealthAdvice>[];
    final sodium = totals[NutrientCode.sodium] ?? 0;
    final fiber = totals[NutrientCode.fiber] ?? 0;
    final iron = totals[NutrientCode.iron] ?? 0;
    final vc = totals[NutrientCode.vitaminC] ?? 0;
    final sugar = totals[NutrientCode.sugar] ?? 0;
    final potassium = totals[NutrientCode.potassium] ?? 0;
    final phosphorus = totals[NutrientCode.phosphorus] ?? 0;
    final names = entries.expand((e) => e.items).map((e) => e.foodName).join(' ');
    final alcohol = totals[NutrientCode.alcohol] ?? 0;

    if (profile == null) {
      return _generic(totals: totals, targets: t, names: names, groupTotals: groupTotals);
    }

    // ---- 酒精：优先级最高，孕期/哺乳零容忍 ----
    if (alcohol > 0 && (profile.pregnant || profile.lactating)) {
      out.add(HealthAdvice(
        priority: 120,
        title: '已记录酒精 ${alcohol.toStringAsFixed(0)} g',
        body: profile.pregnant
            ? '孕期没有安全饮酒阈值。请与产科医生沟通，不要用「少量红酒」自我安慰。'
            : '哺乳期建议 0；若已饮酒，与哺乳间隔 2 小时以上并咨询医生。',
        evidence: 'WHO / 中国居民膳食指南：孕期禁酒',
      ));
    } else if (alcohol >= 15 &&
        (profile.has(Condition.gout) || profile.has(Condition.hypertension))) {
      out.add(HealthAdvice(
        priority: 92,
        title: '酒精 ${alcohol.toStringAsFixed(0)} g',
        body: profile.has(Condition.gout)
            ? '啤酒和烈酒都会升尿酸；痛风期建议 0。'
            : '酒精会抵消降压收益，建议男性 ≤25 g、女性 ≤15 g，最好不喝。',
        evidence: '中国高血压防治指南 / ACR 2020',
      ));
    }

    // ---- 高血压 / 钠 ----
    if (profile.has(Condition.hypertension)) {
      if (sodium > t.sodiumOk) {
        out.add(HealthAdvice(
          condition: Condition.hypertension,
          priority: 100,
          title: '钠 ${sodium.round()} mg，约盐 ${(sodium / 393.7).toStringAsFixed(1)} g',
          body: '今天超出你的上限 ${(sodium - t.sodiumOk).round()} mg。最省力的两步：生抽改成蘸（一餐省 300–600 mg），汤只喝半碗。',
          evidence: '中国高血压防治指南：钠 <2000 mg/d，理想 1500 mg',
        ));
      } else if (sodium > 0) {
        out.add(HealthAdvice(
          condition: Condition.hypertension,
          priority: 45,
          title: '钠控制住了',
          body: '今天 ${sodium.round()} mg，低于你的 ${t.sodiumOk.round()} mg 上限。保持「蘸着吃」而不是「浇着吃」。',
          evidence: '中国高血压防治指南',
        ));
      }
    }

    // ---- 糖尿病 / 糖与纤维 ----
    if (profile.has(Condition.diabetes) || profile.has(Condition.prediabetes)) {
      if (sugar > t.sugarLimit) {
        out.add(HealthAdvice(
          condition: Condition.diabetes,
          priority: 95,
          title: '添加糖 ${sugar.toStringAsFixed(0)} g，超过 ${t.sugarLimit.toStringAsFixed(0)} g',
          body: '先查甜饮、蜂蜜、酱料三处。一瓶 500 ml 甜饮通常 40–55 g 糖；换成无糖茶，今天就能回到线内。',
          evidence: '中国 2 型糖尿病防治指南：添加糖 <10%E，理想 <5%E',
        ));
      }
      if (fiber < t.fiber) {
        out.add(HealthAdvice(
          condition: Condition.diabetes,
          priority: 80,
          title: '纤维还差 ${(t.fiber - fiber).round()} g',
          body: '半碗杂豆（约 60 g 熟重）+ 一盘绿叶菜，能补 7–9 g。先吃菜和蛋白，再吃主食。',
          evidence: '膳食纤维 25–30 g/d 改善餐后血糖',
        ));
      }
    }

    // ---- 痛风 / 高嘌呤 ----
    if (profile.has(Condition.gout)) {
      final hit = _purineHits(names);
      if (hit.isNotEmpty) {
        out.add(HealthAdvice(
          condition: Condition.gout,
          priority: 92,
          title: '今天有高嘌呤项：${hit.take(3).join('、')}',
          body: '不是一口都不能吃，而是别叠加：同一餐别再配啤酒/浓汤，多喝 300–500 ml 白水。',
          evidence: 'ACR 2020 痛风管理指南；果糖与酒精是独立风险',
        ));
      }
      if (sugar > t.sugarLimit) {
        out.add(HealthAdvice(
          condition: Condition.gout,
          priority: 70,
          title: '果糖也会升尿酸',
          body: '甜饮里的果糖比蔗糖更直接升高尿酸；无糖茶/苏打水替代。',
          evidence: '果糖代谢消耗 ATP，增加尿酸生成',
        ));
      }
    }

    // ---- CKD / 钾磷 ----
    if (profile.has(Condition.ckd)) {
      if (t.potassium != null && potassium > t.potassium!) {
        out.add(HealthAdvice(
          condition: Condition.ckd,
          priority: 100,
          title: '钾 ${potassium.round()} mg，超过保守上限 ${t.potassium!.round()} mg',
          body: '先停低钠盐/代盐（常含钾），水果分次少量，菜先焯水再炒。具体上限以最近一次血钾为准。',
          evidence: 'KDIGO CKD 营养共识：钾目标个体化',
        ));
      }
      if (t.phosphorus != null && phosphorus > t.phosphorus!) {
        out.add(HealthAdvice(
          condition: Condition.ckd,
          priority: 98,
          title: '磷 ${phosphorus.round()} mg，超过 ${t.phosphorus!.round()} mg',
          body: '少加工肉、可乐、火锅底料和奶酪；磷酸盐添加剂吸收率接近 100%，比天然磷更需要防。',
          evidence: 'KDIGO：限磷 800–1000 mg/d，优先减少添加剂磷',
        ));
      }
      out.add(const HealthAdvice(
        condition: Condition.ckd,
        priority: 60,
        title: '肾病目标必须由化验单校准',
        body: '这里的钾/磷/蛋白只是保守默认值，分期、透析、血钾不同，目标会变。请让肾内科或营养师改一次。',
        evidence: '本 app 不提供处方',
      ));
    }

    // ---- 贫血 / 铁 ----
    if (profile.has(Condition.anemia)) {
      if (iron < t.iron) {
        out.add(HealthAdvice(
          condition: Condition.anemia,
          priority: 85,
          title: '铁 ${iron.toStringAsFixed(1)} mg，还差 ${(t.iron - iron).toStringAsFixed(1)} mg',
          body: vc < 60
              ? '铁和维 C 同餐吃：50 g 瘦牛肉约 1.4 mg 铁；要靠食物补 12 mg 不现实，50–100 g 鸭血（约 15–30 mg 铁）才是够量的日常来源。'
              : '维 C 够了，但食物补铁效率有限：鸭血/肝脏每周一次，仍不足请医生评估铁剂；不要靠菠菜硬补。',
          evidence: '中国居民膳食指南；血红素铁吸收率高于非血红素铁',
        ));
      }
    }

    // ---- 素食 / B12 ----
    if (profile.isVegetarian) {
      final b12 = totals[NutrientCode.vitaminB12] ?? 0;
      out.add(HealthAdvice(
        condition: Condition.vegetarian,
        priority: b12 <= 0 ? 88 : 40,
        title: b12 <= 0 ? '今天 B12 没有可靠来源' : 'B12 有记录，继续',
        body: '植物性食物几乎不含 B12；纯素需要强化食品（B12 强化豆奶/营养酵母）或补充剂，建议每年查一次。',
        evidence: 'B12 缺乏可无贫血先出现神经症状',
      ));
    }

    // ---- 孕期 ----
    if (profile.pregnant) {
      final folate = totals[NutrientCode.folate] ?? 0;
      final iodine = totals[NutrientCode.iodine] ?? 0;
      if (folate < 600) {
        out.add(const HealthAdvice(
          condition: Condition.pregnancy,
          priority: 95,
          title: '叶酸记录偏低',
          body: '食物叶酸很难到 600 μgDFE；通常需要遵医嘱补充剂。这里只做记录，不调整剂量。',
          evidence: '孕期叶酸 600 μgDFE/d',
        ));
      }
      if (iodine < 230) {
        out.add(const HealthAdvice(
          condition: Condition.pregnancy,
          priority: 75,
          title: '碘可能不足',
          body: '用加碘盐做菜，每周 1–2 次海带/紫菜；不要额外吃海带补碘片。',
          evidence: '孕期碘 230 μg/d',
        ));
      }
    }

    // ---- 通用缺口 ----
    if (out.length < 4) {
      out.addAll(_generic(totals: totals, targets: t, names: names));
    }

    out.sort((a, b) => b.priority.compareTo(a.priority));
    return out.take(4).toList(growable: false);
  }

  static List<HealthAdvice> _generic({
    required Map<String, double> totals,
    required NutrientTargets targets,
    required String names,
    Map<String, double> groupTotals = const {},
  }) {
    final out = <HealthAdvice>[];
    final fiber = totals[NutrientCode.fiber] ?? 0;
    final protein = totals[NutrientCode.protein] ?? 0;
    final calcium = totals[NutrientCode.calcium] ?? 0;
    final veg = groupTotals[FoodGroupCode.vegetable] ?? 0;

    if (veg < 200) {
      out.add(HealthAdvice(
        priority: 70,
        title: '蔬菜 ${veg.round()} g，离 300 g 还差一拳',
        body: '深色蔬菜占一半；微波/白灼 3 分钟，比点外卖加菜更快。',
        evidence: '中国居民膳食指南 2022：蔬菜 300–500 g/d',
      ));
    }
    if (fiber < targets.fiber * 0.7) {
      out.add(HealthAdvice(
        priority: 65,
        title: '纤维 ${fiber.toStringAsFixed(0)} g',
        body: '把半碗白米饭换成杂豆/燕麦，或加一份带皮水果，通常能补 5–8 g。',
        evidence: '膳食纤维 25 g/d 以上',
      ));
    }
    if (protein < targets.protein * 0.7) {
      out.add(HealthAdvice(
        priority: 60,
        title: '蛋白质 ${protein.toStringAsFixed(0)} g',
        body: '下一餐加一掌心鱼/鸡胸/豆腐（约 20 g 蛋白），比喝蛋白粉更稳。',
        evidence: '中国居民膳食指南：鱼禽蛋瘦肉适量',
      ));
    }
    if (calcium < targets.calcium * 0.6) {
      out.add(HealthAdvice(
        priority: 55,
        title: '钙 ${calcium.round()} mg',
        body: '200 ml 奶/无糖酸奶约 220–240 mg 钙；乳糖不耐换无乳糖奶或北豆腐。',
        evidence: '成人钙 800 mg/d',
      ));
    }
    if (out.isEmpty) {
      out.add(const HealthAdvice(
        priority: 10,
        title: '今天结构不错',
        body: '别急着加补剂。把明天早餐的蛋白质和蔬菜先安排好，比今天多记一项更有用。',
        evidence: '连续性 > 单日完美',
      ));
    }
    return out;
  }

  static List<String> _purineHits(String names) {
    const words = [
      '猪肝', '鸡肝', '鹅肝', '腰花', '猪腰', '肾', '胰', '脑',
      '沙丁', '凤尾鱼', '带鱼', '虾', '蟹', '扇贝', '带子', '干贝',
      '浓汤', '高汤', '肉汤', '肉汁', '火锅', '啤酒', '鱼籽',
    ];
    return words.where(names.contains).toList();
  }
}
