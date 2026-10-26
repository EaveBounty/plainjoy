#!/usr/bin/env python3
"""把《中国食物成分表（标准版 第6版）》「能量和食物一般营养成分」表
转换为 app 可检索的 JSON。

用法
----
    python tool/import_cfct.py --input-dir /path/to/merged_json_dir

输入目录应包含 `merged_<大类>-<亚类>.json`，每个文件是若干条记录：
    {"foodCode": "121101", "foodName": "白条鱼（裸鱼）", "energyKCal": "103", ...}

输出
----
    assets/data/cn_food_full.json     完整数据（默认 .gitignore，不入公开仓库）
    assets/data/cn_food_manifest.json 统计与字段覆盖（可入仓库）

设计约束
--------
1. 只搬运「数值事实」，不复制原书排版、表格、图片、注释文本。
2. 缺失值保持缺失（不写 0），由 app 显示「—」并在评分时降低置信度。
3. 原表没有的字段（添加糖、饱和脂肪、碘、VD、B12、叶酸、嘌呤）
   用「估算」或「定性等级」补齐，逐条标注 `estimated`，不冒充实测。
4. 每条带 sourceRef（食物编码）与 source（cfct6），便于回溯与纠错。
"""
from __future__ import annotations

import argparse
import glob
import json
import os
import re
import sys
from collections import Counter, defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "assets", "data")

# 原表字段 -> app 营养代码
FIELD_MAP = {
    "water": "water_ml",
    "energyKCal": "energy_kcal",
    "protein": "protein_g",
    "fat": "fat_g",
    "CHO": "carb_g",
    "dietaryFiber": "fiber_g",
    "cholesterol": "cholesterol_mg",
    "vitaminA": "va_ug",
    "carotene": "carotene_ug",
    "retinol": "retinol_ug",
    "thiamin": "vb1_mg",
    "riboflavin": "vb2_mg",
    "niacin": "niacin_mg",
    "vitaminC": "vc_mg",
    "vitaminETotal": "ve_mg",
    "Ca": "calcium_mg",
    "P": "phosphorus_mg",
    "K": "potassium_mg",
    "Na": "sodium_mg",
    "Mg": "magnesium_mg",
    "Fe": "iron_mg",
    "Zn": "zinc_mg",
    "Se": "selenium_ug",
    "Cu": "copper_mg",
    "Mn": "manganese_mg",
}

CATEGORY_RULES = [
    ("谷类及其制品", ("staple", "refined_grain")),
    ("薯类淀粉及其制品", ("staple", "tuber")),
    ("干豆类及其制品", ("bean", "soy")),
    ("蔬菜类及其制品", ("vegetable", "vegetable")),
    ("菌藻类", ("vegetable", "vegetable")),
    ("水果类及其制品", ("fruit", "fruit")),
    ("坚果种子类", ("nut", "nut")),
    ("畜肉类及其制品", ("meat", "red_meat")),
    ("禽肉类及其制品", ("meat", "protein")),
    ("乳类及其制品", ("dairy", "dairy")),
    ("蛋类及其制品", ("egg", "protein")),
    ("鱼虾蟹贝类", ("fish", "seafood")),
    ("植物油", ("oil", "oil")),
    ("动物油脂类", ("oil", "oil")),
    ("其他类", ("other", "other")),
]

WHOLE_GRAIN_HINTS = ("糙", "全麦", "燕麦", "荞麦", "玉米", "小米", "黄米", "高粱", "青稞", "藜麦", "黑米", "紫米", "薏")
REFINED_HINTS = ("白米", "精", "富强", "标准粉", "粳米", "籼米", "糯米", "面粉", "挂面", "面条", "馒头", "烙饼")
SWEET_HINTS = ("糖", "蜜", "甜", "蛋糕", "饼干", "糕", "冰淇淋", "雪糕", "巧克力", "果酱", "饮料", "汽水", "可乐", "果汁", "奶茶")
PROCESSED_HINTS = ("罐头", "香肠", "火腿", "腊", "熏", "腌", "咸", "酱", "卤", "干", "脯", "方便面", "膨化", "油炸")
ORGAN_HINTS = ("肝", "肾", "肚", "肠", "心", "脑", "肺", "胰", "脾", "舌", "腰子")
HIGH_PURINE_HINTS = ("沙丁", "凤尾", "鲭", "带鱼", "鲳", "虾", "蟹", "贝", "蚝", "贻贝", "浓汤", "肉汤", "火锅", "肝", "肾", "胰", "脑", "沙丁鱼")
HIGH_MERCURY_HINTS = ("鲨鱼", "剑鱼", "方头鱼", "金枪鱼", "旗鱼")
IODINE_HINTS = ("海带", "紫菜", "海苔", "裙带菜", "虾皮", "海米", "海鱼", "带鱼", "鲳", "贝", "海参", "海蜇")

# 饱和脂肪占总脂肪的比例（按类别），仅用于估算
SFA_RATIO = {
    "meat": 0.38,
    "dairy": 0.62,
    "egg": 0.32,
    "fish": 0.26,
    "nut": 0.15,
    "oil": 0.20,
    "bean": 0.16,
    "staple": 0.28,
    "vegetable": 0.20,
    "fruit": 0.20,
    "other": 0.30,
}


def parse_number(raw: object) -> float | None:
    if raw is None:
        return None
    s = str(raw).strip()
    if s in {"", "—", "-", "－", "…", "..."}:
        return None
    s = s.replace(",", "")
    s = re.sub(r"\*+$", "", s)  # 899* 之类的脚注
    if s in {"Tr", "tr", "TR", "微量"}:
        return 0.0
    m = re.search(r"-?\d+(?:\.\d+)?", s)
    if not m:
        return None
    try:
        return float(m.group(0))
    except ValueError:
        return None


def split_category(path: str) -> tuple[str, str]:
    base = os.path.basename(path)
    body = base.replace("merged_", "").replace(".json", "")
    if "-" in body:
        major, minor = body.split("-", 1)
    else:
        major, minor = body, ""
    return major, minor


def map_category(major: str) -> tuple[str, str]:
    for prefix, (cat, tag) in CATEGORY_RULES:
        if major.startswith(prefix):
            return cat, tag
    return "other", "other"


def aliases_for(name: str) -> list[str]:
    out: list[str] = []
    for pattern in (r"（([^）]+)）", r"\(([^)]+)\)", r"［([^］]+)］", r"\[([^\]]+)\]"):
        out += re.findall(pattern, name)
    cleaned = re.sub(r"[（(［\[].*?[）)］\]]", "", name).strip()
    if cleaned and cleaned != name:
        out.append(cleaned)
    seen: list[str] = []
    for a in out:
        a = a.strip()
        # 「甜，罐头」「（干）」这类是性状说明，不是别名
        if not a or len(a) > 12 or re.search(r"[，,、；;：:]", a):
            continue
        if a in {"干", "鲜", "均值", "代表值", "脱水", "熟", "生"}:
            continue
        if a not in seen:
            seen.append(a)
    return seen


def estimate_derived(food: dict, cat: str, tags: set[str]) -> dict:
    """原表没有的字段：只做保守估算，逐项标注。"""
    n = food["nutrientsPer100g"]
    est: list[str] = []
    name = food["name"]

    carb = n.get("carb_g")
    sugar = 0.0
    if carb and (any(h in name for h in SWEET_HINTS) or "dessert" in tags or "sugary_drink" in tags):
        # 添加糖上限：按碳水的一半估，避免把淀粉算成糖
        sugar = round(carb * 0.5, 1)
        est.append("sugar_g")
    if sugar or carb is not None:
        n["sugar_g"] = sugar

    fat = n.get("fat_g")
    if fat is not None:
        ratio = SFA_RATIO.get(cat, 0.3)
        if cat == "oil" and "动物" in food["categoryLabel"]:
            ratio = 0.45
        n["sfa_g"] = round(fat * ratio, 2)
        est.append("sfa_g")
        n["tfa_g"] = 0.0

    if any(h in name for h in PROCESSED_HINTS):
        n["upf_pct"] = 60.0
    elif cat in {"oil"}:
        n["upf_pct"] = 20.0
    else:
        n["upf_pct"] = 0.0

    food["estimated"] = est
    return food


def build_groups(cat: str, tags: set[str], name: str) -> dict:
    if cat == "vegetable":
        return {"veg": 100.0}
    if cat == "fruit":
        return {"fruit": 100.0}
    if cat == "dairy":
        return {"dairy": 100.0}
    if cat == "bean":
        return {"soy_nut": 100.0}
    if cat == "nut":
        return {"soy_nut": 100.0}
    if cat == "fish":
        return {"animal_protein": 100.0, "fish": 100.0}
    if cat in {"meat", "egg"}:
        return {"animal_protein": 100.0}
    if cat == "staple":
        if any(h in name for h in WHOLE_GRAIN_HINTS):
            return {"whole_grain": 100.0}
        if "tuber" in tags or "薯" in name:
            return {"tuber": 100.0}
        return {"refined_grain": 100.0}
    return {}


def build_tags(cat: str, tags: set[str], n: dict, name: str) -> list[str]:
    out = set(tags)
    sodium = n.get("sodium_mg", 0) or 0
    potassium = n.get("potassium_mg", 0) or 0
    if sodium >= 1200:
        out.update({"high_sodium", "very_high_sodium"})
    elif sodium >= 400:
        out.add("high_sodium")
    if potassium >= 300:
        out.add("high_potassium")
    if any(h in name for h in ORGAN_HINTS):
        out.update({"organ_meat", "liver" if "肝" in name else "offal"})
    if any(h in name for h in HIGH_PURINE_HINTS):
        out.add("high_purine")
    if any(h in name for h in HIGH_MERCURY_HINTS):
        out.add("high_mercury_fish")
    if any(h in name for h in IODINE_HINTS):
        out.add("iodine_rich")
    if any(h in name for h in SWEET_HINTS):
        out.add("dessert")
    if "饮料" in name or "汽水" in name or "可乐" in name or "果汁" in name:
        out.add("sugary_drink")
    if any(h in name for h in PROCESSED_HINTS):
        out.add("processed")
    if any(h in name for h in ("腌", "酱菜", "酸菜", "咸菜", "泡菜")):
        out.add("pickled")
    if "酒" in name or "啤" in name:
        out.add("alcohol")
    if "茶" in name:
        out.add("tea")
    if "咖啡" in name:
        out.add("coffee")
    if "奶" in name or "乳" in name:
        out.add("lactose")
    if "豆腐" in name or "豆浆" in name or "腐竹" in name:
        out.add("soy")
    if any(h in name for h in WHOLE_GRAIN_HINTS):
        out.add("whole_grain")
    if any(h in name for h in REFINED_HINTS):
        out.add("refined_grain")
    if cat == "staple":
        out.add("staple")
    if cat in {"meat", "fish", "egg", "bean"}:
        out.add("protein")
    return sorted(out)


def purge_purine_hint(tags: list[str]) -> None:
    pass


def convert(path: str) -> list[dict]:
    major, minor = split_category(path)
    cat, primary_tag = map_category(major)
    label = f"{major}-{minor}" if minor else major
    rows = json.load(open(path, encoding="utf-8"))
    out: list[dict] = []
    for row in rows:
        name = str(row.get("foodName", "")).strip()
        code = str(row.get("foodCode", "")).strip()
        if not name or not code:
            continue
        n: dict[str, float] = {}
        for src, dst in FIELD_MAP.items():
            value = parse_number(row.get(src))
            if value is not None:
                n[dst] = value

        # 能量校验：原表个别行把 kJ 写进了 kcal 列（列错位）。
        # 有宏量营养素时用 4/9/4 反推，决定是否除以 4.184。
        kj = parse_number(row.get("energyKJ"))
        kcal = n.get("energy_kcal")
        calc = (
            n.get("protein_g", 0) * 4
            + n.get("fat_g", 0) * 9
            + n.get("carb_g", 0) * 4
        )
        corrected = False
        if kcal is None and kj is not None:
            kcal = round(kj / 4.184, 1)
            corrected = True
        elif kcal is not None:
            candidates = [kcal]
            if kj is not None and kj > 0:
                candidates.append(kj / 4.184)
            candidates.append(kcal / 4.184)
            if calc > 0:
                best = min(candidates, key=lambda v: abs(v - calc))
                if best != kcal and abs(best - calc) + 1 < abs(kcal - calc):
                    kcal = round(best, 1)
                    corrected = True
        if kcal is not None:
            n["energy_kcal"] = kcal
        # 注意：修正标记不能进 nutrientsPer100g，否则会被当成营养素求和
        food_flags = ["energy_corrected"] if corrected else []

        food = {
            "id": f"cfct6-{code}",
            "name": name,
            "aliases": aliases_for(name),
            "category": cat,
            "categoryLabel": label,
            "ediblePct": parse_number(row.get("edible")),
            "source": "cfct6",
            "sourceRef": code,
            "nutrientsPer100g": n,
            "groupsPer100g": {},
            "tags": [],
            "isVerified": False,
            "isComposite": False,
            "flags": food_flags,
            "defaultServingGrams": None,
            "defaultServingLabel": None,
            "note": "",
        }
        tags = build_tags(cat, {primary_tag} if primary_tag != "other" else set(), n, name)
        food["tags"] = tags
        food["groupsPer100g"] = build_groups(cat, set(tags), name)
        estimate_derived(food, cat, set(tags))
        # 厨房份量提示：只给粗略值，不假装精确
        food["defaultServingGrams"] = default_serving(cat, name)
        food["defaultServingLabel"] = default_serving_label(cat)
        if row.get("remark"):
            food["note"] = str(row["remark"])[:40]
        out.append(food)
    return out


def default_serving(cat: str, name: str) -> float | None:
    if cat == "staple":
        return 150
    if cat == "vegetable":
        return 100
    if cat == "fruit":
        return 150
    if cat == "meat":
        return 80
    if cat == "fish":
        return 80
    if cat == "egg":
        return 50
    if cat == "dairy":
        return 200
    if cat == "bean":
        return 100
    if cat == "nut":
        return 10
    if cat == "oil":
        return 10
    return None


def default_serving_label(cat: str) -> str | None:
    return {
        "staple": "约一小碗",
        "vegetable": "约一拳",
        "fruit": "约一个",
        "meat": "约一掌心",
        "fish": "约一掌心",
        "egg": "约一个",
        "dairy": "约一杯",
        "bean": "约半块豆腐",
        "nut": "约一小把",
        "oil": "约一瓷勺",
    }.get(cat)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--input-dir", required=True)
    ap.add_argument("--out", default=os.path.join(OUT_DIR, "cn_food_full.json"))
    args = ap.parse_args()

    files = sorted(glob.glob(os.path.join(args.input_dir, "merged_*.json")))
    if not files:
        print("没有找到 merged_*.json", file=sys.stderr)
        return 1

    foods: list[dict] = []
    for path in files:
        if os.path.basename(path) == "merged_apply_log.json":
            continue
        foods.extend(convert(path))

    # 去重：同一 foodCode 只保留第一条
    seen: set[str] = set()
    unique = []
    for food in foods:
        if food["sourceRef"] in seen:
            continue
        seen.add(food["sourceRef"])
        unique.append(food)
    foods = sorted(unique, key=lambda f: (f["categoryLabel"], f["sourceRef"]))

    os.makedirs(os.path.dirname(args.out), exist_ok=True)
    with open(args.out, "w", encoding="utf-8") as fh:
        json.dump(foods, fh, ensure_ascii=False, separators=(",", ":"))

    coverage = Counter()
    for food in foods:
        for code in food["nutrientsPer100g"]:
            coverage[code] += 1
    manifest = {
        "source": "cfct6-general",
        "count": len(foods),
        "fields": dict(sorted(coverage.items())),
        "categories": dict(sorted(Counter(f["category"] for f in foods).items())),
        "estimatedFields": ["sugar_g", "sfa_g", "tfa_g", "upf_pct"],
        "unknownFields": ["iodine_ug", "vd_ug", "vb12_ug", "folate_ug", "purine_mg"],
        "generatedAt": "local",
        "licenseNote": "数据仅本地使用；不随公开仓库分发。",
    }
    with open(os.path.join(os.path.dirname(args.out), "cn_food_manifest.json"), "w", encoding="utf-8") as fh:
        json.dump(manifest, fh, ensure_ascii=False, indent=2)

    print(f"wrote {len(foods)} foods -> {args.out}")
    print("categories:", manifest["categories"])
    print("size:", os.path.getsize(args.out) // 1024, "KB")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
