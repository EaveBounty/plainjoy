class NutrientCode {
  static const energy = 'energy_kcal';
  static const protein = 'protein_g';
  static const fat = 'fat_g';
  static const carb = 'carb_g';
  static const fiber = 'fiber_g';
  static const sodium = 'sodium_mg';
  static const potassium = 'potassium_mg';
  static const calcium = 'calcium_mg';
  static const iron = 'iron_mg';
  static const zinc = 'zinc_mg';
  static const selenium = 'selenium_ug';
  static const vitaminA = 'va_ug';
  static const vitaminC = 'vc_mg';
  static const vitaminD = 'vd_ug';
  static const vitaminB1 = 'vb1_mg';
  static const vitaminB2 = 'vb2_mg';
  static const vitaminB6 = 'vb6_mg';
  static const vitaminB12 = 'vb12_ug';
  static const folate = 'folate_ug';
  static const sugar = 'sugar_g';
  static const sfa = 'sfa_g';
  static const tfa = 'tfa_g';
  static const omega3 = 'omega3_g';
  static const phosphorus = 'phosphorus_mg';
  static const magnesium = 'magnesium_mg';
  static const iodine = 'iodine_ug';
  static const cholesterol = 'cholesterol_mg';
  static const niacin = 'niacin_mg';
  static const vitaminE = 've_mg';
  static const copper = 'copper_mg';
  static const manganese = 'manganese_mg';
  static const water = 'water_ml';
  static const upf = 'upf_pct';
  static const alcohol = 'alcohol_g';

  static const all = <String>[
    energy,
    protein,
    fat,
    carb,
    fiber,
    sodium,
    potassium,
    calcium,
    iron,
    zinc,
    selenium,
    vitaminA,
    vitaminC,
    vitaminD,
    vitaminB1,
    vitaminB2,
    vitaminB6,
    vitaminB12,
    folate,
    sugar,
    sfa,
    tfa,
    omega3,
    phosphorus,
    magnesium,
    iodine,
    cholesterol,
    niacin,
    vitaminE,
    copper,
    manganese,
    water,
    upf,
    alcohol,
  ];
}

class NutrientMeta {
  final String code;
  final String label;
  final String unit;
  final String group;
  final int precision;

  const NutrientMeta(this.code, this.label, this.unit, this.group, this.precision);
}

const nutrientMeta = <String, NutrientMeta>{
  NutrientCode.energy: NutrientMeta(NutrientCode.energy, '能量', 'kcal', 'macro', 0),
  NutrientCode.protein: NutrientMeta(NutrientCode.protein, '蛋白质', 'g', 'macro', 1),
  NutrientCode.fat: NutrientMeta(NutrientCode.fat, '脂肪', 'g', 'macro', 1),
  NutrientCode.carb: NutrientMeta(NutrientCode.carb, '碳水', 'g', 'macro', 1),
  NutrientCode.fiber: NutrientMeta(NutrientCode.fiber, '膳食纤维', 'g', 'micro', 1),
  NutrientCode.sodium: NutrientMeta(NutrientCode.sodium, '钠', 'mg', 'limit', 0),
  NutrientCode.potassium: NutrientMeta(NutrientCode.potassium, '钾', 'mg', 'micro', 0),
  NutrientCode.calcium: NutrientMeta(NutrientCode.calcium, '钙', 'mg', 'micro', 0),
  NutrientCode.iron: NutrientMeta(NutrientCode.iron, '铁', 'mg', 'micro', 1),
  NutrientCode.zinc: NutrientMeta(NutrientCode.zinc, '锌', 'mg', 'micro', 1),
  NutrientCode.selenium: NutrientMeta(NutrientCode.selenium, '硒', 'μg', 'micro', 0),
  NutrientCode.vitaminA: NutrientMeta(NutrientCode.vitaminA, '维生素 A', 'μgRAE', 'micro', 0),
  NutrientCode.vitaminC: NutrientMeta(NutrientCode.vitaminC, '维生素 C', 'mg', 'micro', 0),
  NutrientCode.vitaminD: NutrientMeta(NutrientCode.vitaminD, '维生素 D', 'μg', 'micro', 1),
  NutrientCode.vitaminB1: NutrientMeta(NutrientCode.vitaminB1, '维生素 B1', 'mg', 'micro', 2),
  NutrientCode.vitaminB2: NutrientMeta(NutrientCode.vitaminB2, '维生素 B2', 'mg', 'micro', 2),
  NutrientCode.vitaminB6: NutrientMeta(NutrientCode.vitaminB6, '维生素 B6', 'mg', 'micro', 2),
  NutrientCode.vitaminB12: NutrientMeta(NutrientCode.vitaminB12, '维生素 B12', 'μg', 'micro', 1),
  NutrientCode.folate: NutrientMeta(NutrientCode.folate, '叶酸', 'μgDFE', 'micro', 0),
  NutrientCode.sugar: NutrientMeta(NutrientCode.sugar, '添加糖', 'g', 'limit', 1),
  NutrientCode.sfa: NutrientMeta(NutrientCode.sfa, '饱和脂肪', 'g', 'limit', 1),
  NutrientCode.tfa: NutrientMeta(NutrientCode.tfa, '反式脂肪', 'g', 'limit', 1),
  NutrientCode.omega3: NutrientMeta(NutrientCode.omega3, 'Omega-3', 'g', 'micro', 2),
  NutrientCode.phosphorus: NutrientMeta(NutrientCode.phosphorus, '磷', 'mg', 'micro', 0),
  NutrientCode.magnesium: NutrientMeta(NutrientCode.magnesium, '镁', 'mg', 'micro', 0),
  NutrientCode.iodine: NutrientMeta(NutrientCode.iodine, '碘', 'μg', 'micro', 0),
  NutrientCode.cholesterol: NutrientMeta(NutrientCode.cholesterol, '胆固醇', 'mg', 'limit', 0),
  NutrientCode.niacin: NutrientMeta(NutrientCode.niacin, '烟酸', 'mg', 'micro', 1),
  NutrientCode.vitaminE: NutrientMeta(NutrientCode.vitaminE, '维生素 E', 'mg', 'micro', 1),
  NutrientCode.copper: NutrientMeta(NutrientCode.copper, '铜', 'mg', 'micro', 2),
  NutrientCode.manganese: NutrientMeta(NutrientCode.manganese, '锰', 'mg', 'micro', 2),
  NutrientCode.water: NutrientMeta(NutrientCode.water, '水分', 'ml', 'other', 0),
  NutrientCode.upf: NutrientMeta(NutrientCode.upf, '超加工供能', '%', 'limit', 0),
  NutrientCode.alcohol: NutrientMeta(NutrientCode.alcohol, '酒精', 'g', 'other', 1),
};

class FoodGroupCode {
  static const vegetable = 'veg';
  static const fruit = 'fruit';
  static const wholeGrain = 'whole_grain';
  static const tuber = 'tuber';
  static const dairy = 'dairy';
  static const soyNut = 'soy_nut';
  static const animalProtein = 'animal_protein';
  static const fish = 'fish';
  static const refinedGrain = 'refined_grain';

  static const all = <String>[
    vegetable,
    fruit,
    wholeGrain,
    tuber,
    dairy,
    soyNut,
    animalProtein,
    fish,
    refinedGrain,
  ];
}

const foodGroupLabels = <String, String>{
  FoodGroupCode.vegetable: '蔬菜',
  FoodGroupCode.fruit: '水果',
  FoodGroupCode.wholeGrain: '全谷杂豆',
  FoodGroupCode.tuber: '薯类',
  FoodGroupCode.dairy: '奶类',
  FoodGroupCode.soyNut: '大豆坚果',
  FoodGroupCode.animalProtein: '肉蛋',
  FoodGroupCode.fish: '水产',
  FoodGroupCode.refinedGrain: '精制主食',
};
