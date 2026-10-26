#!/usr/bin/env python3
# 生成 v1 种子食物库与食谱库。
# 数值为常见食物每 100g 的近似值，来源标注为 cn_food_ref / usda_ref，
# 上线前必须用授权数据替换或逐条复核。不要把它当成临床数据。
import json, os

NOW = 1760000000000
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'seed')
os.makedirs(OUT, exist_ok=True)

NUT_KEYS = [
    'energy_kcal','protein_g','fat_g','carb_g','fiber_g','sodium_mg','potassium_mg',
    'calcium_mg','iron_mg','zinc_mg','selenium_ug','va_ug','vc_mg','vd_ug','vb1_mg',
    'vb2_mg','vb6_mg','vb12_ug','folate_ug','sugar_g','sfa_g','tfa_g','omega3_g',
    'water_ml','upf_pct','alcohol_g'
]

def F(fid, name, cat, *, kcal=0, protein=0, fat=0, carb=0, fiber=0, sodium=0,
      potassium=0, calcium=0, iron=0, zinc=0, selenium=0, va=0, vc=0, vd=0,
      vb1=0, vb2=0, vb6=0, vb12=0, folate=0, sugar=0, sfa=0, tfa=0, omega3=0,
      water=0, upf=0, alcohol=0, groups=None, aliases=None, tags=None,
      serving=None, serving_label=None, source='cn_food_ref', composite=False,
      verified=False):
    nut = {
        'energy_kcal': kcal, 'protein_g': protein, 'fat_g': fat, 'carb_g': carb,
        'fiber_g': fiber, 'sodium_mg': sodium, 'potassium_mg': potassium,
        'calcium_mg': calcium, 'iron_mg': iron, 'zinc_mg': zinc,
        'selenium_ug': selenium, 'va_ug': va, 'vc_mg': vc, 'vd_ug': vd,
        'vb1_mg': vb1, 'vb2_mg': vb2, 'vb6_mg': vb6, 'vb12_ug': vb12,
        'folate_ug': folate, 'sugar_g': sugar, 'sfa_g': sfa, 'tfa_g': tfa,
        'omega3_g': omega3, 'water_ml': water, 'upf_pct': upf, 'alcohol_g': alcohol,
    }
    nut = {k: round(v, 3) for k, v in nut.items() if v}
    return {
        'id': fid, 'name': name, 'category': cat, 'source': source,
        'sourceRef': 'v1-seed-approx', 'nutrientsPer100g': nut,
        'groupsPer100g': groups or {},
        'defaultServingGrams': serving, 'defaultServingLabel': serving_label,
        'isVerified': verified, 'aliases': aliases or [], 'tags': tags or [],
        'isComposite': composite, 'createdAt': NOW, 'updatedAt': NOW,
    }

foods = []

# ---------- 主食 ----------
foods += [
F('rice_cooked','米饭','staple',kcal=116,protein=2.6,fat=.3,carb=25.9,fiber=.3,sodium=2.5,potassium=30,calcium=7,iron=.2,zinc=.6,selenium=2.5,vb1=.02,vb2=.01,folate=3,water=70,groups={'refined_grain':100},aliases=['白米饭','大米饭'],serving=150,serving_label='一碗'),
F('brown_rice','糙米饭','staple',kcal=112,protein=2.6,fat=.9,carb=23,fiber=1.8,sodium=5,potassium=79,calcium=10,iron=.5,zinc=.8,vb1=.1,folate=10,groups={'whole_grain':100},aliases=['杂粮饭','糙米'],serving=150,serving_label='一碗'),
F('congee','白粥','staple',kcal=46,protein=1.1,fat=.1,carb=9.9,fiber=.1,sodium=2,water=89,groups={'refined_grain':30},aliases=['稀饭','大米粥'],serving=300,serving_label='一碗'),
F('steamed_bun','馒头','staple',kcal=223,protein=7,fat=1.1,carb=47,fiber=1.3,sodium=165,calcium=20,iron=1,groups={'refined_grain':100},aliases=['白馒头'],serving=80,serving_label='一个'),
F('whole_wheat_bun','全麦馒头','staple',kcal=210,protein=8,fat=1.5,carb=42,fiber=4,sodium=180,groups={'whole_grain':70,'refined_grain':30},serving=80,serving_label='一个'),
F('noodles_cooked','面条（熟）','staple',kcal=110,protein=4.5,fat=.5,carb=22,fiber=1.2,sodium=150,groups={'refined_grain':100},aliases=['挂面','汤面'],serving=200,serving_label='一碗'),
F('instant_noodles','方便面','staple',kcal=472,protein=9.5,fat=21,carb=61,fiber=2,sodium=1140,sugar=2,sfa=9,upf=100,groups={'refined_grain':100},tags=['high_sodium','upf'],serving=100,serving_label='一包'),
F('oats','燕麦片','staple',kcal=389,protein=16.9,fat=6.9,carb=66.3,fiber=10.6,sodium=2,calcium=54,iron=4.7,zinc=4,vb1=.76,folate=56,groups={'whole_grain':100},aliases=['燕麦'],serving=40,serving_label='一份'),
F('corn','玉米','staple',kcal=112,protein=4,fat=1.2,carb=22.8,fiber=2.9,sodium=1,potassium=218,vc=6.8,groups={'whole_grain':100},aliases=['甜玉米','玉米棒'],serving=150,serving_label='一根'),
F('sweet_potato','红薯','staple',kcal=86,protein=1.6,fat=.1,carb=20.1,fiber=3,sodium=55,potassium=337,va=709,vc=2.4,groups={'tuber':100},aliases=['地瓜','番薯'],serving=150,serving_label='一个'),
F('potato','土豆','staple',kcal=77,protein=2,fat=.1,carb=17.5,fiber=2.2,sodium=6,potassium=421,vc=19.7,groups={'tuber':100},aliases=['马铃薯'],serving=150,serving_label='一个'),
F('quinoa','藜麦','staple',kcal=368,protein=14,fat=6,carb=64,fiber=7,sodium=5,calcium=47,iron=4.6,zinc=3.1,folate=184,groups={'whole_grain':100},serving=50,serving_label='一份'),
F('rice_noodles','米粉（熟）','staple',kcal=109,protein=1.8,fat=.2,carb=25,fiber=.4,sodium=10,groups={'refined_grain':100},aliases=['米线'],serving=200,serving_label='一碗'),
F('dumplings','饺子','staple',kcal=220,protein=8,fat=8,carb=28,fiber=1.5,sodium=500,groups={'refined_grain':50,'animal_protein':30,'vegetable':20},serving=200,serving_label='10 个'),
F('fried_rice','蛋炒饭','staple',kcal=180,protein=5,fat=6,carb=26,fiber=1,sodium=500,groups={'refined_grain':70,'animal_protein':15,'vegetable':15},serving=250,serving_label='一盘'),
]

# ---------- 蔬菜 ----------
foods += [
F('broccoli','西兰花','vegetable',kcal=34,protein=2.8,fat=.4,carb=6.6,fiber=2.6,sodium=33,potassium=316,calcium=47,iron=.7,vc=89,va=31,folate=63,groups={'vegetable':100},aliases=['绿花菜'],serving=100,serving_label='一拳'),
F('spinach','菠菜','vegetable',kcal=23,protein=2.9,fat=.4,carb=3.6,fiber=2.2,sodium=79,potassium=558,calcium=99,iron=2.7,vc=28,va=469,folate=194,groups={'vegetable':100},serving=100,serving_label='一拳'),
F('bok_choy','小白菜','vegetable',kcal=13,protein=1.5,fat=.2,carb=2.2,fiber=1,sodium=65,calcium=105,iron=.8,vc=45,va=223,folate=66,groups={'vegetable':100},aliases=['青菜'],serving=100,serving_label='一拳'),
F('lettuce','生菜','vegetable',kcal=15,protein=1.4,fat=.2,carb=2.9,fiber=1.3,sodium=28,calcium=36,iron=.9,vc=9,va=370,folate=38,groups={'vegetable':100},serving=100,serving_label='一碗'),
F('tomato','番茄','vegetable',kcal=18,protein=.9,fat=.2,carb=3.9,fiber=1.2,sodium=5,potassium=237,calcium=10,iron=.3,vc=14,va=42,folate=15,groups={'vegetable':100},aliases=['西红柿'],serving=150,serving_label='一个'),
F('cucumber','黄瓜','vegetable',kcal=15,protein=.7,fat=.1,carb=3.6,fiber=.5,sodium=2,calcium=16,vc=2.8,groups={'vegetable':100},serving=150,serving_label='一根'),
F('carrot','胡萝卜','vegetable',kcal=41,protein=.9,fat=.2,carb=9.6,fiber=2.8,sodium=69,potassium=320,calcium=33,iron=.3,vc=5.9,va=835,folate=19,groups={'vegetable':100},serving=100,serving_label='一根'),
F('pumpkin','南瓜','vegetable',kcal=26,protein=1,fat=.1,carb=6.5,fiber=.5,sodium=1,calcium=21,vc=9,va=426,groups={'vegetable':100},serving=150,serving_label='一碗'),
F('eggplant','茄子','vegetable',kcal=25,protein=1,fat=.2,carb=5.9,fiber=3,sodium=2,calcium=9,vc=2.2,groups={'vegetable':100},serving=150,serving_label='一根'),
F('green_pepper','青椒','vegetable',kcal=20,protein=.9,fat=.2,carb=4.6,fiber=1.7,sodium=3,calcium=10,vc=80,va=18,folate=10,groups={'vegetable':100},aliases=['柿子椒'],serving=100,serving_label='一个'),
F('mushroom','口蘑','vegetable',kcal=22,protein=3.1,fat=.3,carb=3.3,fiber=1,sodium=5,calcium=3,iron=.5,zinc=.5,selenium=2.5,vb2=.4,groups={'vegetable':100},aliases=['蘑菇'],serving=100,serving_label='一碗'),
F('shiitake','香菇','vegetable',kcal=34,protein=2.2,fat=.5,carb=6.8,fiber=2.5,sodium=9,calcium=2,iron=.3,zinc=.7,selenium=5.5,groups={'vegetable':100},serving=100,serving_label='一碗'),
F('wood_ear','木耳','vegetable',kcal=27,protein=1.5,fat=.2,carb=6,fiber=2.6,sodium=9,calcium=34,iron=5.5,groups={'vegetable':100},aliases=['黑木耳'],serving=50,serving_label='一小碗'),
F('kelp','海带','vegetable',kcal=13,protein=1.2,fat=.1,carb=2.1,fiber=.5,sodium=233,calcium=168,iron=.8,groups={'vegetable':100},serving=50,serving_label='一小碗'),
F('seaweed','紫菜','vegetable',kcal=35,protein=5.8,fat=.4,carb=5.4,fiber=1.3,sodium=48,calcium=264,iron=2.4,va=228,vc=3,groups={'vegetable':100},serving=10,serving_label='一小把'),
F('asparagus','芦笋','vegetable',kcal=20,protein=2.2,fat=.1,carb=3.9,fiber=2.1,sodium=2,calcium=24,iron=.6,vc=5.6,folate=52,groups={'vegetable':100},serving=100,serving_label='一把'),
F('cabbage','圆白菜','vegetable',kcal=25,protein=1.3,fat=.1,carb=5.8,fiber=2.5,sodium=18,calcium=40,iron=.5,vc=36.6,folate=43,groups={'vegetable':100},aliases=['卷心菜','包菜'],serving=150,serving_label='一碗'),
F('cauliflower','菜花','vegetable',kcal=25,protein=1.9,fat=.3,carb=5,fiber=2,sodium=30,calcium=22,iron=.4,vc=48.2,folate=57,groups={'vegetable':100},aliases=['花椰菜'],serving=150,serving_label='一碗'),
F('bean_sprouts','豆芽','vegetable',kcal=30,protein=3,fat=.2,carb=5.9,fiber=1.8,sodium=6,calcium=21,iron=.9,vc=13,folate=60,groups={'vegetable':100},serving=100,serving_label='一碗'),
F('snow_peas','荷兰豆','vegetable',kcal=42,protein=2.8,fat=.2,carb=7.6,fiber=2.6,sodium=4,calcium=43,iron=2.1,vc=60,folate=42,groups={'vegetable':100},serving=100,serving_label='一碗'),
]

# ---------- 水果 ----------
foods += [
F('apple','苹果','fruit',kcal=52,protein=.3,fat=.2,carb=13.8,fiber=2.4,sodium=1,potassium=107,vc=4.6,groups={'fruit':100},serving=200,serving_label='一个'),
F('banana','香蕉','fruit',kcal=89,protein=1.1,fat=.3,carb=22.8,fiber=2.6,sodium=1,potassium=358,vc=8.7,vb6=.4,groups={'fruit':100},serving=120,serving_label='一根'),
F('orange','橙子','fruit',kcal=47,protein=.9,fat=.1,carb=11.8,fiber=2.4,sodium=0,potassium=181,vc=53.2,folate=30,groups={'fruit':100},serving=200,serving_label='一个'),
F('kiwi','猕猴桃','fruit',kcal=61,protein=1.1,fat=.5,carb=14.7,fiber=3,sodium=3,potassium=312,vc=92.7,folate=25,groups={'fruit':100},aliases=['奇异果'],serving=100,serving_label='一个'),
F('strawberry','草莓','fruit',kcal=32,protein=.7,fat=.3,carb=7.7,fiber=2,sodium=1,vc=58.8,folate=24,groups={'fruit':100},serving=150,serving_label='一碗'),
F('blueberry','蓝莓','fruit',kcal=57,protein=.7,fat=.3,carb=14.5,fiber=2.4,sodium=1,vc=9.7,groups={'fruit':100},serving=100,serving_label='一小碗'),
F('grapes','葡萄','fruit',kcal=69,protein=.7,fat=.2,carb=18.1,fiber=.9,sodium=2,vc=3.2,groups={'fruit':100},serving=150,serving_label='一串'),
F('pear','梨','fruit',kcal=57,protein=.4,fat=.1,carb=15.2,fiber=3.1,sodium=1,vc=4.3,groups={'fruit':100},serving=200,serving_label='一个'),
F('watermelon','西瓜','fruit',kcal=30,protein=.6,fat=.2,carb=7.6,fiber=.4,sodium=1,vc=8.1,groups={'fruit':100},serving=300,serving_label='一块'),
F('mango','芒果','fruit',kcal=60,protein=.8,fat=.4,carb=15,fiber=1.6,sodium=1,vc=36.4,va=54,groups={'fruit':100},serving=150,serving_label='一个'),
]

# ---------- 蛋白质 ----------
foods += [
F('chicken_breast','鸡胸肉','meat',kcal=133,protein=24,fat=3.5,sodium=60,iron=.7,zinc=1,selenium=25,vb6=.6,vb12=.3,groups={'animal_protein':100},serving=100,serving_label='一掌心'),
F('chicken_thigh','鸡腿肉','meat',kcal=209,protein=18,fat=15,sodium=80,iron=.9,zinc=1.3,selenium=20,vb12=.5,groups={'animal_protein':100},serving=100,serving_label='一掌心'),
F('pork_lean','瘦猪肉','meat',kcal=143,protein=20.3,fat=6.2,sodium=57,iron=1.5,zinc=2.9,selenium=15,vb1=.5,vb12=.4,groups={'animal_protein':100},aliases=['猪瘦肉'],serving=100,serving_label='一掌心'),
F('pork_belly','五花肉','meat',kcal=395,protein=14,fat=37,sodium=60,iron=1,zinc=1.5,groups={'animal_protein':100},serving=80,serving_label='一小块'),
F('beef_lean','瘦牛肉','meat',kcal=250,protein=26,fat=15,sodium=72,iron=2.6,zinc=4.8,selenium=20,vb12=1.5,groups={'animal_protein':100},serving=100,serving_label='一掌心'),
F('lamb','羊肉','meat',kcal=203,protein=19,fat=14,sodium=80,iron=2.3,zinc=3.2,vb12=1.2,groups={'animal_protein':100},serving=100,serving_label='一掌心'),
F('egg','鸡蛋','egg',kcal=144,protein=13.3,fat=8.8,carb=2.8,sodium=131,calcium=56,iron=1.8,zinc=1.1,selenium=15,va=234,vd=2,vb2=.5,vb12=.6,folate=47,groups={'animal_protein':100},serving=50,serving_label='一个'),
F('duck_egg','鸭蛋','egg',kcal=180,protein=12.6,fat=13,sodium=106,calcium=62,iron=2.9,va=261,vb12=.7,groups={'animal_protein':100},serving=60,serving_label='一个'),
F('salmon','三文鱼','fish',kcal=208,protein=20,fat=13,sodium=59,calcium=9,iron=.3,zinc=.4,selenium=36,va=12,vd=11,vb12=3.2,omega3=2.3,groups={'fish':100},aliases=['鲑鱼'],serving=100,serving_label='一掌心'),
F('cod','鳕鱼','fish',kcal=82,protein=18,fat=.7,sodium=54,calcium=16,iron=.4,zinc=.4,selenium=33,vb12=.9,omega3=.2,groups={'fish':100},serving=150,serving_label='一块'),
F('shrimp','虾仁','fish',kcal=99,protein=24,fat=.3,sodium=111,calcium=70,iron=.5,zinc=1.5,selenium=38,vb12=1.1,groups={'fish':100},aliases=['虾'],serving=100,serving_label='一掌心'),
F('tuna','金枪鱼','fish',kcal=132,protein=28,fat=1,sodium=47,iron=1.3,zinc=.7,selenium=90,vb12=2.2,omega3=.3,groups={'fish':100},serving=100,serving_label='一掌心'),
F('tofu','北豆腐','bean',kcal=82,protein=8.1,fat=3.7,carb=4.2,fiber=.4,sodium=7,calcium=164,iron=1.9,zinc=.8,selenium=2.5,folate=15,groups={'soy_nut':40},aliases=['老豆腐','豆腐'],serving=150,serving_label='半块'),
F('tempeh','天贝','bean',kcal=192,protein=20.3,fat=10.8,carb=7.6,fiber=5,sodium=9,calcium=111,iron=2.7,zinc=1.1,groups={'soy_nut':50},serving=100,serving_label='一份'),
F('soybeans','黄豆','bean',kcal=390,protein=35,fat=16,carb=34,fiber=15.5,sodium=2,calcium=191,iron=8.2,zinc=3.3,folate=375,groups={'soy_nut':100},aliases=['大豆'],serving=30,serving_label='一小把'),
]

# ---------- 奶 ----------
foods += [
F('milk','牛奶','dairy',kcal=54,protein=3,fat=3.2,carb=3.4,sodium=37,calcium=104,va=24,vd=1.3,vb2=.2,vb12=.4,groups={'dairy':100},serving=250,serving_label='一杯'),
F('yogurt','无糖酸奶','dairy',kcal=72,protein=2.5,fat=2.7,carb=9.3,sugar=7,sodium=39,calcium=118,va=14,vb12=.4,groups={'dairy':100},serving=200,serving_label='一杯'),
F('cheese','奶酪','dairy',kcal=350,protein=25,fat=27,carb=3,sodium=600,calcium=700,va=200,vb12=.8,groups={'dairy':10},serving=20,serving_label='一片'),
F('lactose_free_milk','无乳糖奶','dairy',kcal=50,protein=3.3,fat=3,carb=3,sodium=40,calcium=120,vd=1.3,vb12=.5,groups={'dairy':100},serving=250,serving_label='一杯'),
F('soy_milk','无糖豆浆','dairy',kcal=33,protein=3,fat=1.6,carb=1.7,sodium=3,calcium=10,groups={'soy_nut':10},serving=250,serving_label='一杯'),
]

# ---------- 坚果 ----------
foods += [
F('peanuts','花生','nut',kcal=567,protein=25.8,fat=49,carb=16,fiber=8.5,sodium=18,calcium=92,iron=4.6,zinc=3.3,folate=240,groups={'soy_nut':100},serving=15,serving_label='一小把'),
F('almonds','巴旦木','nut',kcal=579,protein=21,fat=50,carb=22,fiber=12.5,sodium=1,calcium=269,iron=3.7,zinc=3.1,vb2=1.1,groups={'soy_nut':100},aliases=['杏仁'],serving=10,serving_label='一小把'),
F('walnuts','核桃','nut',kcal=654,protein=15,fat=65,carb=14,fiber=6.7,sodium=2,calcium=98,iron=2.9,zinc=3.1,omega3=9,groups={'soy_nut':100},serving=10,serving_label='两个'),
F('cashews','腰果','nut',kcal=553,protein=18,fat=44,carb=30,fiber=3.3,sodium=12,calcium=37,iron=6.7,zinc=5.8,groups={'soy_nut':100},serving=10,serving_label='一小把'),
F('sesame_paste','芝麻酱','nut',kcal=630,protein=19,fat=52,carb=22,fiber=6,sodium=40,calcium=1000,iron=10,zinc=5,groups={'soy_nut':100},serving=10,serving_label='一勺'),
]

# ---------- 调味品 ----------
foods += [
F('soy_sauce','酱油','condiment',kcal=53,protein=8,fat=.1,carb=4.9,sodium=5757,sugar=2,groups={},tags=['high_sodium'],serving=10,serving_label='一勺'),
F('oyster_sauce','蚝油','condiment',kcal=51,protein=1.5,fat=.1,carb=11,sodium=2730,sugar=5,groups={},tags=['high_sodium'],serving=10,serving_label='一勺'),
F('doubanjiang','豆瓣酱','condiment',kcal=178,protein=10,fat=8,carb=15,fiber=2,sodium=6000,groups={},tags=['high_sodium'],serving=10,serving_label='一勺'),
F('salt','盐','condiment',kcal=0,sodium=39300,groups={},tags=['high_sodium'],serving=1,serving_label='一克'),
F('msg','味精','condiment',kcal=0,sodium=12000,groups={},tags=['high_sodium'],serving=1,serving_label='一克'),
F('cooking_oil','食用油','condiment',kcal=899,fat=100,sfa=15,groups={},tags=['oil'],serving=10,serving_label='一勺'),
F('sugar','白砂糖','condiment',kcal=400,carb=100,sugar=100,groups={},serving=5,serving_label='一小勺'),
F('mayonnaise','蛋黄酱','condiment',kcal=680,protein=1,fat=75,carb=1,sodium=600,sugar=2,sfa=12,upf=100,groups={},serving=10,serving_label='一勺'),
]

# ---------- 饮料/零食 ----------
foods += [
F('cola','可乐','drink',kcal=42,carb=10.6,sugar=10.6,sodium=4,upf=100,groups={},serving=330,serving_label='一罐'),
F('milk_tea','奶茶','drink',kcal=60,protein=1,fat=2,carb=9,sugar=8,sodium=30,upf=60,groups={},serving=500,serving_label='一杯'),
F('orange_juice','橙汁','drink',kcal=45,carb=10.4,sugar=8.4,vc=50,sodium=1,groups={},serving=250,serving_label='一杯'),
F('beer','啤酒','drink',kcal=43,protein=.5,carb=3.6,alcohol=3.9,sodium=4,upf=30,groups={},serving=330,serving_label='一罐'),
F('latte','拿铁','drink',kcal=55,protein=3,fat=3,carb=4.5,sugar=4,sodium=40,calcium=100,upf=20,groups={'dairy':60},serving=300,serving_label='一杯'),
F('potato_chips','薯片','snack',kcal=536,protein=7,fat=35,carb=53,fiber=4,sodium=525,upf=100,groups={},tags=['upf'],serving=50,serving_label='一小包'),
F('chocolate','巧克力','snack',kcal=546,protein=4.9,fat=31,carb=61,fiber=3.4,sugar=48,sodium=24,sfa=18,upf=80,groups={},serving=20,serving_label='两块'),
F('ice_cream','冰淇淋','snack',kcal=207,protein=3.5,fat=11,carb=24,sugar=21,sodium=80,calcium=126,upf=80,groups={'dairy':20},serving=100,serving_label='一个'),
F('protein_powder','蛋白粉','supplement',kcal=380,protein=80,fat=5,carb=8,sodium=200,calcium=500,upf=100,groups={},tags=['supplement'],serving=30,serving_label='一勺'),
F('water','白水','drink',kcal=0,water=100,groups={},serving=250,serving_label='一杯'),
]

# ---------- 复合菜 ----------
foods += [
F('kung_pao_chicken','宫保鸡丁','dish',kcal=180,protein=12,fat=10,carb=8,fiber=1.5,sodium=600,sugar=4,groups={'animal_protein':50,'soy_nut':10,'vegetable':20,'refined_grain':10},composite=True,serving=200,serving_label='一盘'),
F('mapo_tofu','麻婆豆腐','dish',kcal=130,protein=8,fat=8,carb=6,fiber=1,sodium=700,groups={'soy_nut':50,'animal_protein':20,'vegetable':10},composite=True,serving=200,serving_label='一盘'),
F('tomato_egg','番茄炒蛋','dish',kcal=90,protein=5,fat=6,carb=4,fiber=1,sodium=400,sugar=2,groups={'animal_protein':40,'vegetable':50},composite=True,serving=200,serving_label='一盘'),
F('stir_fry_greens','清炒时蔬','dish',kcal=60,protein=2,fat=4,carb=4,fiber=2,sodium=500,groups={'vegetable':90},composite=True,serving=200,serving_label='一盘'),
F('braised_beef_noodles','红烧牛肉面','dish',kcal=120,protein=7,fat=4,carb=16,fiber=1,sodium=700,groups={'refined_grain':50,'animal_protein':30,'vegetable':10},composite=True,serving=500,serving_label='一碗'),
F('hot_pot','火锅','dish',kcal=80,protein=6,fat=5,carb=4,fiber=1,sodium=700,groups={'animal_protein':30,'vegetable':40,'soy_nut':10},composite=True,serving=500,serving_label='一人份'),
F('malatang','麻辣烫','dish',kcal=110,protein=6,fat=7,carb=7,fiber=1.5,sodium=900,groups={'animal_protein':30,'vegetable':40,'refined_grain':20},composite=True,serving=500,serving_label='一碗'),
F('chicken_salad','鸡胸沙拉','dish',kcal=90,protein=10,fat=4,carb=5,fiber=2,sodium=300,groups={'animal_protein':50,'vegetable':50},composite=True,serving=300,serving_label='一碗'),
F('sandwich','三明治','dish',kcal=240,protein=10,fat=8,carb=32,fiber=3,sodium=500,groups={'refined_grain':60,'animal_protein':30,'vegetable':10},composite=True,serving=180,serving_label='一个'),
F('congee_pickles','白粥配咸菜','dish',kcal=50,protein=1.5,fat=.5,carb=9,fiber=.5,sodium=600,groups={'refined_grain':40,'vegetable':10},composite=True,serving=350,serving_label='一碗'),
F('sweet_sour_pork','糖醋里脊','dish',kcal=250,protein=12,fat=15,carb=18,fiber=.5,sodium=500,sugar=10,groups={'animal_protein':60,'refined_grain':20},composite=True,serving=200,serving_label='一盘'),
F('fish_soup','鱼汤','dish',kcal=45,protein=5,fat=2,carb=1,sodium=400,groups={'fish':40},composite=True,serving=300,serving_label='一碗'),
F('veg_soup','蔬菜汤','dish',kcal=25,protein=1,fat=1,carb=3,fiber=1,sodium=350,groups={'vegetable':60},composite=True,serving=300,serving_label='一碗'),
F('takeout_box','外卖便当','dish',kcal=150,protein=8,fat=8,carb=15,fiber=1,sodium=800,groups={'animal_protein':30,'vegetable':30,'refined_grain':40},composite=True,serving=500,serving_label='一份'),
]

# ---------- 食谱 ----------
def R(rid, name, cat, ings, equipment, minutes, cost, steps, tags, desc='', takeout=False, nocook=False):
    return {
        'id': rid, 'name': name, 'category': cat, 'description': desc,
        'ingredients': [{'foodId': f, 'grams': g} for f, g in ings],
        'equipment': equipment, 'minutes': minutes, 'costYuan': cost,
        'difficulty': 'easy', 'steps': steps, 'tasteTags': tags,
        'isTakeout': takeout, 'isNoCook': nocook, 'servings': 1,
    }

recipes = [
R('r_oats_bowl','牛奶燕麦香蕉碗','breakfast',
  [('oats',50),('milk',250),('banana',100),('almonds',10)],
  ['microwave'],5,8,['燕麦加牛奶，微波 2 分钟','铺香蕉片和坚果'],['清淡','甜'],'5 分钟早餐，纤维和钙都够。'),
R('r_whole_sandwich','全麦鸡蛋三明治','breakfast',
  [('whole_wheat_bun',80),('egg',50),('lettuce',30),('tomato',50),('cheese',10)],
  ['induction'],10,10,['鸡蛋煎熟','全麦馒头切开，夹生菜番茄和蛋'],['咸','便携'],'通勤可带走。'),
R('r_microwave_egg','微波蒸蛋','breakfast',
  [('egg',100),('water',50),('soy_sauce',5),('sesame_paste',5)],
  ['microwave'],8,5,['鸡蛋打散加温水','盖保鲜膜微波 2 分钟','淋酱油和芝麻酱'],['软','咸'],'没有灶也能做。'),
R('r_tomato_egg','番茄炒蛋','lunch',
  [('tomato',150),('egg',100),('cooking_oil',8),('salt',1)],
  ['induction'],15,8,['鸡蛋炒凝固盛出','番茄炒软，倒回鸡蛋，调味'],['家常','咸'],'最稳的新手菜。'),
R('r_broccoli_shrimp','西兰花炒虾仁','lunch',
  [('broccoli',150),('shrimp',100),('cooking_oil',8),('salt',1)],
  ['induction'],15,18,['西兰花焯水','虾仁炒变色，加西兰花翻炒'],['清淡','高蛋白'],'蛋白质和 VC 都高。'),
R('r_mapo_tofu','麻婆豆腐','dinner',
  [('tofu',200),('pork_lean',50),('doubanjiang',10),('cooking_oil',8)],
  ['induction'],20,12,['豆腐切块焯水','肉末炒香，加豆瓣酱','下豆腐小火煮 5 分钟'],['辣','下饭'],'钠偏高，汤别喝。'),
R('r_kung_pao','宫保鸡丁','dinner',
  [('chicken_breast',120),('peanuts',15),('cucumber',50),('cooking_oil',10),('doubanjiang',5)],
  ['induction'],20,15,['鸡丁滑炒','加黄瓜和花生','豆瓣酱调味'],['辣','下饭'],'花生提供好脂肪，注意豆瓣酱钠。'),
R('r_steamed_fish','清蒸鳕鱼','dinner',
  [('cod',150),('soy_sauce',8),('cooking_oil',5)],
  ['induction'],20,25,['鳕鱼蒸 8 分钟','淋酱油，浇热油'],['清淡','高蛋白'],'低钠高蛋白，适合高血压。'),
R('r_salmon_rice','三文鱼糙米饭','dinner',
  [('salmon',100),('brown_rice',150),('broccoli',100)],
  ['induction','riceCooker'],25,35,['糙米饭提前煮好','三文鱼煎或烤','西兰花焯水'],['清淡','高蛋白'],'Omega-3 和纤维组合。'),
R('r_chicken_salad','鸡胸沙拉','lunch',
  [('chicken_breast',100),('lettuce',80),('tomato',80),('cucumber',50),('cooking_oil',5)],
  ['induction'],15,18,['鸡胸煎熟切片','蔬菜洗净','油醋汁拌匀'],['清淡','高蛋白'],'外卖也能点，酱料另放。'),
R('r_beef_noodles','牛肉面','dinner',
  [('beef_lean',80),('noodles_cooked',200),('bok_choy',80),('soy_sauce',5)],
  ['induction'],25,20,['牛肉焯水后炖 15 分钟','下面条和青菜','酱油调味'],['咸','热食'],'汤别全喝，钠主要在汤里。'),
R('r_fried_rice','蔬菜蛋炒饭','lunch',
  [('rice_cooked',200),('egg',50),('carrot',30),('snow_peas',30),('cooking_oil',8)],
  ['induction'],15,10,['鸡蛋炒散','下米饭和蔬菜翻炒','少盐调味'],['家常','快手'],'剩饭的好去处。'),
R('r_congee_egg','白粥配鸡蛋','breakfast',
  [('congee',300),('cabbage',30),('egg',50)],
  ['riceCooker'],10,5,['粥煮好','鸡蛋煮熟','配一小碟蔬菜'],['清淡','软'],'胃口差时用。'),
R('r_sweet_potato_milk','红薯牛奶','breakfast',
  [('sweet_potato',200),('milk',200)],
  ['microwave'],20,8,['红薯蒸/微波熟','配牛奶'],['甜','饱腹'],'纤维和钙。'),
R('r_yogurt_fruit','酸奶水果燕麦杯','snack',
  [('yogurt',200),('blueberry',50),('strawberry',50),('oats',20)],
  [],5,12,['酸奶铺底','加水果和燕麦'],['甜','免煮'],'免煮，适合办公室。',nocook=True),
R('r_tofu_veg_soup','豆腐蔬菜汤','dinner',
  [('tofu',100),('spinach',80),('kelp',20),('salt',1)],
  ['induction'],15,8,['水开下豆腐和海带','最后放菠菜','少盐'],['清淡','汤'],'补钙和碘。'),
R('r_tomato_fish_soup','番茄鱼汤','dinner',
  [('cod',100),('tomato',100),('cooking_oil',5),('salt',1)],
  ['induction'],20,20,['番茄炒出汁','加水煮开','下鱼片煮熟'],['酸','汤'],'酸口开胃。'),
R('r_mushroom_chicken','香菇滑鸡','dinner',
  [('chicken_thigh',120),('shiitake',80),('cooking_oil',8),('soy_sauce',5)],
  ['induction'],25,15,['鸡腿肉切块','香菇泡发','一起焖 15 分钟'],['咸','下饭'],'香菇提鲜，少放盐。'),
R('r_potato_beef','土豆炖牛肉','dinner',
  [('beef_lean',100),('potato',150),('carrot',50),('cooking_oil',8)],
  ['induction'],35,25,['牛肉焯水','和土豆胡萝卜一起炖 25 分钟'],['咸','饱腹'],'周末备餐友好。'),
R('r_veg_stirfry','清炒圆白菜','lunch',
  [('cabbage',150),('green_pepper',50),('cooking_oil',8),('salt',1)],
  ['induction'],10,6,['蔬菜切好','大火快炒','少盐'],['清淡','快手'],'10 分钟补蔬菜。'),
R('r_microwave_rice_veg','微波炉米饭蔬菜','lunch',
  [('rice_cooked',150),('broccoli',100),('tofu',100)],
  ['microwave'],8,8,['全部放碗里','加少量水，微波 3 分钟','淋一点酱油'],['清淡','免灶'],'只有微波炉也能吃好。'),
R('r_convenience_combo','便利店组合','lunch',
  [('whole_wheat_bun',80),('chicken_breast',100),('milk',250),('apple',100)],
  [],2,15,['买现成的','组合即可'],['免煮','便携'],'没有厨房时的最低限度。',nocook=True),
R('r_takeout_malatang','麻辣烫（外卖）','dinner',
  [('malatang',500)],
  [],0,25,['选清汤/少辣','多加蔬菜和豆制品','汤别喝'],['辣','外卖'],'外卖场景，钠按高值估算。',takeout=True),
R('r_takeout_beef_noodles','红烧牛肉面（外卖）','dinner',
  [('braised_beef_noodles',500)],
  [],0,25,['选小份','加一份青菜','汤喝一半以内'],['咸','外卖'],'外卖场景。',takeout=True),
R('r_milk_tea_snack','奶茶 + 巧克力','snack',
  [('milk_tea',500),('chocolate',20)],
  [],0,18,['三分糖或不加糖'],['甜','外卖'],'偶尔可以，别当日常。',takeout=True),
R('r_night_snack','酸奶坚果香蕉','snack',
  [('yogurt',150),('walnuts',10),('banana',100)],
  [],2,8,['组合即可'],['甜','免煮'],'加班后的稳选择。',nocook=True),
R('r_spinach_egg_soup','菠菜蛋花汤','dinner',
  [('spinach',100),('egg',50),('salt',1)],
  ['induction'],10,6,['水开下菠菜','淋蛋液','少盐'],['清淡','汤'],'补铁和叶酸。'),
R('r_shrimp_fried_rice','虾仁炒饭','lunch',
  [('rice_cooked',200),('shrimp',80),('egg',50),('snow_peas',30),('cooking_oil',8)],
  ['induction'],18,20,['虾仁炒熟','下米饭和蛋','加荷兰豆'],['咸','快手'],'高蛋白炒饭。'),
R('r_soy_stew','番茄黄豆炖土豆','dinner',
  [('soybeans',50),('tomato',100),('potato',100),('cooking_oil',5)],
  ['induction'],30,10,['黄豆提前泡','番茄炒出汁','加土豆和黄豆炖 20 分钟'],['酸','素食'],'素食蛋白组合。'),
R('r_cold_noodles','麻酱凉面','lunch',
  [('noodles_cooked',200),('cucumber',80),('egg',50),('sesame_paste',10),('soy_sauce',5)],
  ['induction'],10,10,['面条过凉水','黄瓜切丝','芝麻酱加酱油调开'],['香','快手'],'夏天适用，芝麻酱补钙。'),
]

# ---------- 常见简称别名（提升本地解析命中率） ----------
alias_overrides = {
    'beef_lean': ['牛肉', '牛腩'],
    'pork_lean': ['猪肉', '瘦肉', '里脊'],
    'chicken_breast': ['鸡肉', '鸡胸', '鸡胸肉'],
    'chicken_thigh': ['鸡腿'],
    'cod': ['鳕鱼'],
    'salmon': ['三文鱼', '鲑鱼'],
    'rice_cooked': ['米饭', '白饭', '大米饭'],
    'noodles_cooked': ['面条', '面', '挂面'],
    'egg': ['蛋', '鸡蛋', '水煮蛋'],
    'milk': ['奶', '牛奶', '纯牛奶'],
    'yogurt': ['酸奶'],
    'apple': ['苹果'],
    'banana': ['香蕉'],
    'broccoli': ['西兰花', '绿花菜'],
    'tomato': ['番茄', '西红柿'],
    'tofu': ['豆腐', '北豆腐', '老豆腐'],
    'potato': ['土豆', '马铃薯'],
    'sweet_potato': ['红薯', '地瓜'],
    'oats': ['燕麦', '燕麦片'],
    'soy_milk': ['豆浆'],
    'peanuts': ['花生', '花生米'],
    'almonds': ['杏仁', '巴旦木'],
    'walnuts': ['核桃'],
    'soy_sauce': ['酱油', '生抽', '老抽'],
    'oyster_sauce': ['蚝油'],
    'doubanjiang': ['豆瓣酱'],
    'cooking_oil': ['油', '食用油', '植物油'],
    'sugar': ['糖', '白砂糖'],
}
for f in foods:
    extra = alias_overrides.get(f['id'], [])
    if extra:
        f['aliases'] = sorted(set(f.get('aliases', []) + extra))

# ---------- 容器/参照物 ----------
containers = [
  {'id':'c_bowl_small','name':'小饭碗','capacityMl':250,'tareG':120,'fillRatio':0.8,'shape':'bowl','densityHint':0.85,'builtin':True,'updatedAt':NOW},
  {'id':'c_bowl_large','name':'大汤碗','capacityMl':600,'tareG':250,'fillRatio':0.75,'shape':'bowl','densityHint':0.75,'builtin':True,'updatedAt':NOW},
  {'id':'c_cup','name':'马克杯','capacityMl':350,'tareG':180,'fillRatio':0.85,'shape':'cup','densityHint':1.0,'builtin':True,'updatedAt':NOW},
  {'id':'c_takeout','name':'外卖盒','capacityMl':750,'tareG':30,'fillRatio':0.7,'shape':'box','densityHint':0.7,'builtin':True,'updatedAt':NOW},
  {'id':'c_spoon','name':'汤勺','capacityMl':15,'tareG':20,'fillRatio':0.9,'shape':'spoon','densityHint':1.0,'builtin':True,'updatedAt':NOW},
  {'id':'c_plate','name':'圆盘','capacityMl':500,'tareG':300,'fillRatio':0.4,'shape':'plate','densityHint':0.6,'builtin':True,'updatedAt':NOW},
]
refs = [
  {'id':'ref_palm','name':'手掌','category':'hand','lengthMm':100,'widthMm':80,'heightMm':20,'weightG':0,'builtin':True,'hint':'一掌心肉/鱼约 75–100 g'},
  {'id':'ref_fist','name':'拳头','category':'hand','lengthMm':90,'widthMm':80,'heightMm':90,'weightG':0,'builtin':True,'hint':'一拳蔬菜约 100–150 g，一拳米饭约 150 g'},
  {'id':'ref_thumb','name':'拇指','category':'hand','lengthMm':50,'widthMm':25,'heightMm':25,'weightG':0,'builtin':True,'hint':'一拇指油脂约 10 g'},
  {'id':'ref_cards','name':'扑克牌','category':'object','lengthMm':88,'widthMm':63,'heightMm':2,'weightG':0,'builtin':True,'hint':'一副扑克牌大小的肉约 75 g'},
  {'id':'ref_phone','name':'手机','category':'object','lengthMm':150,'widthMm':72,'heightMm':8,'weightG':180,'builtin':True,'hint':'手机大小的薄片食物约 100 g'},
  {'id':'ref_coin','name':'一元硬币','category':'object','lengthMm':25,'widthMm':25,'heightMm':2,'weightG':6,'builtin':True,'hint':'硬币大小的一勺酱约 5 g'},
  {'id':'ref_bowl','name':'一次性饭碗','category':'object','lengthMm':110,'widthMm':110,'heightMm':55,'weightG':5,'builtin':True,'hint':'装满约 250 ml'},
]

with open(os.path.join(OUT,'foods.json'),'w',encoding='utf-8') as f:
    json.dump(foods,f,ensure_ascii=False,indent=1)
with open(os.path.join(OUT,'recipes.json'),'w',encoding='utf-8') as f:
    json.dump(recipes,f,ensure_ascii=False,indent=1)
with open(os.path.join(OUT,'containers.json'),'w',encoding='utf-8') as f:
    json.dump(containers,f,ensure_ascii=False,indent=1)
with open(os.path.join(OUT,'reference_objects.json'),'w',encoding='utf-8') as f:
    json.dump(refs,f,ensure_ascii=False,indent=1)

print(f'foods={len(foods)} recipes={len(recipes)} containers={len(containers)} refs={len(refs)}')
