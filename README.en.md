[中文](README.md) ｜ **English** ｜ [Landing page](https://eavebounty.github.io/plainjoy/en/)

# Plainjoy · 有味清欢 (Youwei Qinghuan)

Plainjoy is a local-first Android nutrition tracker and diet logger: estimate portions without a scale, adjust targets by condition, and patch the next meal.

> Eat slowly. Stop at enough.

A **local-first** Android nutrition logger and next-meal planner. No 21-meal plans, no scale:
log a meal by photo or one sentence, then patch 1–5 upcoming meals around your condition and gaps,
and review 16 adequacy items plus the state of one cat.

- Package: `com.eavebounty.plainjoy`
- Version: `0.2.0+2`
- Platform: **Android first**; Web / Linux / Windows are secondary
- Language: Simplified Chinese UI
- Licence: PolyForm Noncommercial License 1.0.0 (**not OSI open source**; commercial use requires a licence)

![Plainjoy splash screen](docs/assets/shots/splash.webp)
![Plainjoy onboarding screen](docs/assets/shots/onboarding.webp)
![Plainjoy home and pet screen](docs/assets/shots/home.webp)

---

## Download

- [v0.2.0 Android APK](https://github.com/EaveBounty/plainjoy/releases/tag/v0.2.0): `arm64-v8a` recommended; `armeabi-v7a` for older 32-bit devices, `x86_64` for emulators
- Minimum Android 7.0; the public APK ships only the 102-food seed set, not the full composition table
- Verify with `SHA256SUMS.txt` attached to the release

---

## 1. What problem it solves

Mainstream diet apps assume you can weigh food, log twenty fields a day, and that your only goal is
weight loss. Plainjoy assumes the opposite:

| Reality | Design response |
|---|---|
| You do not know what 150 g of rice looks like | Container calibration, visual references, portion ranges; 10-second tier at ±35–45% |
| One bad estimate makes you quit | A single meal cannot overturn the verdict; the 7-day structure decides. Ranges first, no false precision |
| You have hypertension, CKD, gout or pregnancy | Conditions change targets, scoring weights and advice order — not a generic paragraph |
| Takeaway cannot be decomposed | Log the dish first; log condiments separately to capture hidden sodium |
| Full-week plans are unsustainable | Patch only 1–5 upcoming meals, keep your existing eating pattern |
| Logging is boring | Four-axis pet (vitality / coat / mood / hydration), weekly report, no death or punishment |

### Core loop

```
Log (photo / text / search)
  → 16-item score (food groups 40 / nutrients 32 / limits 28, Monte-Carlo interval)
  → one action that matters most (weighted by condition)
  → next-meal "patch meal" (deterministic solver; the LLM only narrates)
  → feed the pet / weekly report
```

---

## 2. Features

### 2.1 Logging and portions

- One-sentence text parsing on local rules (works without an API key)
- Photo recognition via DeepSeek Vision, strict JSON; local table first, AI only as a labelled fallback
- Search: 102 seed foods + 22 condiments + optional local full table
- Three precision tiers (10 s / 60 s / 3 min); containers, references, leftover deduction
- Every entry stores a nutrient snapshot, so later data changes cannot rewrite history

### 2.2 Personalised nutrition

`lib/core/health/condition_policy.dart` maps a condition to three things:

1. **Target overrides** (sodium, protein, potassium, phosphorus, iodine, folate, iron, calcium, water)
2. **Score weight multipliers** (e.g. hypertension: sodium ×1.8, vegetables ×1.25)
3. **Contraindications and referral prompts**

Supported: hypertension, diabetes, pre-diabetes, gout/hyperuricaemia, chronic kidney disease
(with a dialysis switch), anaemia, lactose intolerance, vegetarian, pregnancy, breastfeeding.
When conditions stack, ceilings become the stricter value, floors the higher value; if a floor
exceeds a ceiling, the ceiling wins and the conflict is stated.

Scoring is **coverage-aware**: if a nutrient covers less than 60% of the day's energy, the item is
shown as “insufficient data” and removed from the denominator. Missing data is never treated as zero.

### 2.3 Recipe detail and sodium ledger

- 30 home recipes, each with estimated seasonings (salt, light/dark soy sauce, oyster sauce, MSG, sugar, vinegar, sesame paste)
- Expand a recipe to see a **sodium ledger**: total sodium, salt equivalent, top four sources, ±15% range
- Condiments split by type: iodised / non-iodised / low-sodium salt (potassium warning), light soy, dark soy, oyster sauce, MSG, chicken essence, doubanjiang, sweet bean sauce, ketchup, sesame paste, cooking wine, vinegar, fermented tofu, pickles, salted egg, hotpot base, mayonnaise
- Key conversions: 1 g salt ≈ 393.7 mg sodium; 1 g MSG ≈ 123 mg sodium; light soy 6.6 g sodium/100 g, dark soy 7.0 g/100 g

### 2.4 Nutrition dashboard and scoring

- Day / week / month totals with p10–p90 intervals; 320 Monte-Carlo runs
- 16 items: 6 food groups, 7 nutrients, 3 limits (plus potassium/phosphorus for CKD)
- Gate caps: weak food structure, high sodium, out-of-control limits, ultra-processed energy share
- Weekly report: trend, gaps, one thing worth changing

### 2.5 Pet

- Four axes: vitality / coat / mood / hydration; 7-day rolling; constant body shape; never dies or gets ill
- Two skins, one skeleton: editorial (paper, serif) and picture-book (cream, lilac, hard shadow)
- Single currency “paw print”; pets and scripts purchasable; no gacha

### 2.6 Data and privacy

- Sembast local database; no account, no upload
- JSON export/import (**API key excluded**)
- Android `allowBackup=false`; cloud backup and device transfer exclude the database
- AI only runs after you enter a key and explicitly enable it; requests contain the current input and food names, never the health profile

---

## 3. Quick start

### Requirements

- Flutter 3.44.3 / Dart 3.12.2 (do not upgrade blindly: `freezed 4` and friends require Dart 3.13)
- Android SDK; JDK 17
- Python 3.11+ only for asset generation / data import

### Run

```bash
flutter pub get
flutter run -d <device>
```

### Build Android

```bash
flutter build apk --release --split-per-abi
# build/app/outputs/flutter-apk/app-*-release.apk
```

Release signing reads `android/key.properties` (gitignored):

```properties
storePassword=...
keyPassword=...
keyAlias=plainjoy
storeFile=../keystore/plainjoy-release.jks
```

**Back up the keystore and passwords offline.** Losing them prevents any future in-place upgrade.

### Build web

```bash
# Online: CanvasKit fetches CJK fallback fonts from the CDN
flutter build web --release

# Fully offline: bundle your own CJK font, otherwise Chinese renders as tofu (known limitation)
flutter build web --release --no-web-resources-cdn
```

### Checks

```bash
flutter analyze     # 0 issues
flutter test        # 16/16
```

---

## 4. Data and copyright (important)

### What the public repo contains

- `assets/seed/foods.json`: 102 **independent approximations** (not a derivative of any copyrighted database)
- `assets/seed/condiments.json`: 22 label-range estimates
- `assets/seed/recipes.json`: 30 recipes
- `assets/data/cn_food_manifest.json`: field-coverage statistics only

### What it does not contain

`assets/private/cn_food_full.json` is a local index converted from the general nutrition table of
*China Food Composition Tables (6th edition)*. It is **gitignored and never distributed**.

- Present locally: the app merges 1,677 entries
- Absent after cloning: the app falls back to the 102 seed foods without failing
- **Never** upload that file, or any APK/AAB/web build containing it, to GitHub Releases, Actions artifacts, Pages or an app store

It is not “open data”; prepare it from a lawful source after obtaining permission. See [`docs/DATA.md`](docs/DATA.md).

### Import and audit

```bash
python tool/import_cfct.py --input-dir /path/to/merged_json_dir
```

The importer normalises units, keeps missing values missing, corrects 140 rows where kJ had been
placed in the kcal column, and labels every estimated field. Iodine, vitamin D, B12, folate and
purine remain unknown rather than fabricated.

---

## 5. Repository layout

```
lib/
  app.dart                      startup gate + theme
  core/
    ai/ai_service.dart          DeepSeek JSON parsing + local match + range checks
    db/app_repository.dart      Sembast, seed merge, import/export
    health/condition_policy.dart condition → targets / weights / cautions
    health/advice_engine.dart    today's intake → actionable advice
    health/health_rules.dart     static rule cards
    scoring/                    16-item score, coverage, Monte-Carlo
    plan/plan_engine.dart       gap-driven patch meals
    portion/                    containers / references / ranges
    state/                      Riverpod state
  features/
    splash/                     30° triangle splash
    onboarding/                 first-run: why / skin / precision
    home/ record/ nutrition/ plan/ pet/ profile/ settings/
assets/
  seed/                         publishable seed data
  private/                      local full table (gitignored)
  brand/                        splash artwork (WebP)
  icon/                         pixel cat icon
docs/
  index.html                    Chinese landing page
  en/index.html                 English landing page
  PRODUCT_DESIGN.md             product baseline
  PLAN.md                       milestones and risks
  DATA.md                       provenance, coverage, legal boundary
  PERSONALIZATION.md            condition mapping and evidence
  REVIEW.md                     multi-review findings and fixes
tool/                           data/brand generators
```

---

## 6. Comparison: Plainjoy vs calorie-counting apps

| Dimension | Plainjoy | Calorie-counting apps (common pattern) |
|---|---|---|
| Weighing | Not required; containers, references and leftovers, stored as ranges | Often gram-only, requiring a scale or package label |
| Condition-aware targets | 10 conditions change targets and score weights | Usually one calorie quota; conditions are just tips |
| Data location | Local Sembast, no account; AI optional and scoped to the current input | Commonly account + cloud sync |
| Planning granularity | Patch the next 1–5 meals | Often a full-week menu or a daily quota |

The right column summarises common design assumptions, not any specific product.

## 7. FAQ

### How do I log meals without weighing anything?

Calibrate one bowl and one spoon, then record low/medium/high and leftovers. Portions are stored as ranges and a meal takes about 10 seconds. One estimate cannot overturn the verdict because scoring reads the 7-day structure.

### How can I estimate food weight without a scale?

Three anchors: your containers, visual references (palm, egg, bank card, fist), and package net weight. Store a range such as “rice 120–160 g” instead of a false single point.

### What should I look for in a hypertension diet app?

A sodium ceiling in the targets (≤2,000 mg, ideally 1,500), separate logging for hidden sodium in soy sauces, oyster sauce and MSG, and score weights that change with the condition. Plainjoy does all three and converts sodium to grams of salt.

### What matters in a kidney-disease diet app?

Protein by body weight and dialysis status (commonly 0.6–0.8 g/kg non-dialysis, 1.0–1.2 g/kg on dialysis), K/P ceilings from lab results, and caution with potassium-containing salt substitutes. Plainjoy offers a dialysis switch and K/P ceilings, but only as a logging aid.

### Which local-first diet tracker apps do not upload health data?

Plainjoy is one: data lives in local Sembast with no account, Android auto-backup is off, and AI is optional and scoped to the current input. For any other tool, check its privacy policy, backup behaviour and AI request scope.

### How accurate is photo nutrition recognition?

The photo only identifies the dish and a portion range; nutrients resolve against the local table first. Only missing dishes use an AI per-100 g estimate, marked `ai_estimate`. Without a key it falls back to local rules.

## 8. Known limitations

- Coverage gaps: phosphorus, potassium, iodine, vitamin D, B12, folate and purine are incomplete; the score says “insufficient data” but that does not mean intake was zero.
- Added sugar and saturated fat are estimates, not lab measurements.
- Photo recognition depends on DeepSeek Vision; without a key, only text/search works.
- The API key is currently stored in plain local settings (excluded from backups); Android Keystore migration is next.
- Offline web builds need a bundled CJK font; Android uses system fonts and is unaffected.
- Portion ranges have not been calibrated with real weighings; 50–100 measurements are planned.

---

## 9. Licence

**PolyForm Noncommercial License 1.0.0.** Personal, research and non-commercial use is free;
**any commercial use requires a separate written licence** — see [`COMMERCIAL.md`](COMMERCIAL.md).

PolyForm NC is not an OSI-approved open source licence. Do not call this project “open source”.

Required Notice: Copyright 2026 长沙市果垂素宇工程设计有限公司 (https://github.com/EaveBounty/plainjoy)

Third-party assets:

- Icon and splash artwork: generated by scripts in this repository, under the project licence
- Fonts: system Noto, not bundled
- Dart/Flutter dependencies: see `pubspec.lock`

This project is not a medical device and provides no diagnosis, prescription or treatment plan.

---

## 10. Changelog

- 2026-10-27: Chinese brand renamed to 有味清欢 (Youwei Qinghuan); Plainjoy unchanged. Splash, onboarding, settings, platform labels and docs updated.
- 2026-10-27: renamed to 清欢 / Plainjoy; 30° triangle splash and dense first-run onboarding; pixel-cat icon; local full-table import and coverage-aware scoring; condition targets/weights/advice; recipe seasonings and sodium ledger; DeepSeek JSON nutrition fallback; Android signing/backup/cleartext hardening; multi-review fixes.
- 2026-10-26: v0.1 with logging, scoring, patch meals, pet, dual themes, backup.
