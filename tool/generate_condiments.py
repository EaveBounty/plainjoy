#!/usr/bin/env python3
"""生成调味品明细表：把「盐 / 生抽 / 老抽 / 味精 / 蚝油」的钠与碘拆开。

数值来源：GB 28050 营养成分标示、GB 26878 碘盐浓度、常见产品标签区间。
全部为**区间中值**，用于估算，不替代称重与标签。每 100 g 计。
"""
import json
import os

NOW = 1761600000000
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "seed", "condiments.json")


def C(cid, name, *, kcal=0, protein=0, fat=0, carb=0, fiber=0, sodium=0, potassium=0,
      calcium=0, iodine=0, sugar=0, water=0, alcohol=0, sfa=0, serving=1, label="1 g",
      aliases=None, tags=None, ref="label-approx"):
    # 能量按 Atwater 自动补，避免「有脂肪却 0 kcal」导致 %E 分母失真
    if kcal == 0 and (protein or fat or carb or alcohol):
        kcal = 4 * (protein + carb + sugar) + 9 * fat + 7 * alcohol
    nut = {
        "energy_kcal": kcal, "protein_g": protein, "fat_g": fat, "carb_g": carb,
        "sodium_mg": sodium, "potassium_mg": potassium, "calcium_mg": calcium,
        "iodine_ug": iodine, "sugar_g": sugar, "water_ml": water, "fiber_g": fiber,
        "alcohol_g": alcohol,
        "sfa_g": sfa,
    }
    nut = {k: round(v, 2) for k, v in nut.items() if v}
    return {
        "id": cid, "name": name, "category": "condiment", "source": "label_ref",
        "sourceRef": ref, "nutrientsPer100g": nut, "groupsPer100g": {},
        "defaultServingGrams": serving, "defaultServingLabel": label,
        "isVerified": False, "aliases": aliases or [], "tags": tags or ["condiment"],
        "isComposite": False, "createdAt": NOW, "updatedAt": NOW,
    }


items = [
    # 盐：钠 39.3 g/100g；碘按 GB 26878 25 mg/kg 中值，地区 18–33 mg/kg
    C("cond_salt_iodized", "精盐（加碘）", sodium=39300, iodine=2500,
      aliases=["碘盐", "加碘盐", "食盐"], tags=["condiment", "high_sodium", "iodized"],
      ref="GB26878-25mg/kg"),
    C("cond_salt_plain", "精盐（无碘）", sodium=39300, iodine=0,
      aliases=["无碘盐", "非碘盐"], tags=["condiment", "high_sodium", "non_iodized"]),
    C("cond_salt_low", "低钠盐", sodium=24000, potassium=13000, iodine=2000,
      aliases=["代盐", "低钠食盐"], tags=["condiment", "high_sodium", "high_potassium", "salt_substitute"]),
    # 酱油：生抽 6.0–7.2 g/100ml，老抽 6.5–7.8 g/100ml
    C("cond_soy_light", "生抽", sodium=6600, protein=6, sugar=5, water=70,
      aliases=["酱油", "淡酱油"], serving=12, label="1 瓷勺 ≈10 ml（≈12 g）",
      tags=["condiment", "high_sodium", "soy"]),
    C("cond_soy_dark", "老抽", sodium=7000, protein=5, sugar=15, water=65,
      aliases=["红烧酱油"], serving=12, label="1 瓷勺 ≈10 ml（≈12 g）",
      tags=["condiment", "high_sodium", "soy"]),
    C("cond_oyster", "蚝油", sodium=4500, carb=25, sugar=20, protein=4,
      aliases=["蚝油汁"], serving=10, label="1 瓷勺 ≈10 g",
      tags=["condiment", "high_sodium"]),
    # 味精：谷氨酸钠约 99%，钠 12.3 g/100g；1 g ≈ 0.31 g 盐的钠
    C("cond_msg", "味精", sodium=12300,
      aliases=["谷氨酸钠", "味素"], tags=["condiment", "high_sodium", "umami"]),
    C("cond_chicken_essence", "鸡精", sodium=20000, protein=10, sugar=10, carb=20,
      aliases=["鸡粉"], tags=["condiment", "high_sodium", "umami"]),
    C("cond_doubanjiang", "豆瓣酱", sodium=6500, protein=12, carb=15, fiber=1,
      aliases=["郫县豆瓣"], serving=10, label="1 瓷勺 ≈10 g",
      tags=["condiment", "high_sodium", "fermented"]),
    C("cond_sweet_bean", "甜面酱", sodium=3000, carb=30, sugar=25,
      tags=["condiment", "high_sodium", "fermented"]),
    C("cond_ketchup", "番茄酱", sodium=1100, carb=25, sugar=22,
      aliases=["茄汁"], tags=["condiment", "high_sodium", "sugary"]),
    C("cond_sesame", "芝麻酱", sodium=50, fat=50, calcium=1170, protein=18, sfa=7,
      aliases=["麻酱"], serving=10, label="1 瓷勺 ≈10 g", tags=["condiment", "calcium"]),
    C("cond_wine", "料酒", sodium=1000, alcohol=12, water=80,
      aliases=["黄酒"], serving=10, label="1 瓷勺 ≈10 ml",
      tags=["condiment", "alcohol"]),
    C("cond_vinegar", "陈醋", sodium=800, water=90,
      aliases=["醋", "香醋"], serving=10, label="1 瓷勺 ≈10 ml", tags=["condiment"]),
    C("cond_tofu_fermented", "腐乳", sodium=3000, protein=10, fat=10,
      aliases=["豆腐乳"], serving=10, label="1 块 ≈10 g",
      tags=["condiment", "high_sodium", "fermented", "soy"]),
    C("cond_pickled_mustard", "榨菜", sodium=4200, fiber=2, carb=5,
      serving=30, label="一小碟 ≈30 g", tags=["condiment", "high_sodium", "pickled"]),
    C("cond_salted_egg", "咸鸭蛋", sodium=2700, protein=12, fat=13,
      serving=60, label="1 个 ≈60 g", tags=["condiment", "high_sodium", "egg"]),
    C("cond_hotpot", "火锅底料", sodium=5000, fat=50, carb=10, sfa=25,
      serving=20, label="1 小块 ≈20 g", tags=["condiment", "high_sodium", "high_fat"]),
    C("cond_mayo", "沙拉酱", sodium=600, fat=50, sugar=10, sfa=8,
      serving=15, label="1 瓷勺 ≈15 g", tags=["condiment", "high_fat"]),
    C("cond_sugar", "白砂糖", carb=99.9, sugar=99.9, kcal=400,
      aliases=["糖", "白糖"], serving=5, label="1 小勺 ≈5 g",
      tags=["condiment", "sugary"]),
    C("cond_honey", "蜂蜜", carb=75, sugar=75, kcal=321,
      serving=10, label="1 小勺 ≈10 g", tags=["condiment", "sugary"]),
    C("cond_starch", "玉米淀粉", carb=85, kcal=345,
      aliases=["生粉", "淀粉"], serving=5, label="1 小勺 ≈5 g", tags=["condiment"]),
]


def main():
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as fh:
        json.dump(items, fh, ensure_ascii=False, indent=2)
    print(f"wrote {len(items)} condiments -> {OUT}")


if __name__ == "__main__":
    main()
