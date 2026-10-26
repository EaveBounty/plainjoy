# 清欢 · 实施计划与验收 v0.1

> 目标：按「全功能一次做完」交付一个可运行的 v0.1 闭环，而不是 21 个互不相连的页面。
> 日期：2026-10-26。状态：**v0.1 核心闭环完成；Android/Linux/Web 构建通过；待 Windows/真机/数据授权**。

---

## 1. 范围定义

### 1.1 v0.1 必做（已完成）

| # | 模块 | 验收标准 | 状态 |
|---|---|---|---|
| 1 | 首启 | 2 屏、画风切换、精度选择、可跳过、不强制身高体重 | ✅ |
| 2 | 首页 | 宠物、今日分数/区间、三域、一条建议、时间线、快捷入口 | ✅ |
| 3 | 记录 | 文字/拍照/搜索；三档份量；容器/参照物；区间；删除/编辑 | ✅ |
| 4 | 营养 | 日/周/月；16 项子弹图；瀑布；钠专章；微量；趋势；热力；周报 | ✅ |
| 5 | 计划 | 条件面板；缺口驱动 1–5 餐；替换；投喂；健康规则 | ✅ |
| 6 | 档案 | 10 种情况；四类规则；可解释；免责声明 | ✅ |
| 7 | 偏好 | 5 星 + avoid/allergy + 证据计数；四类实体；筛选 | ✅ |
| 8 | 宠物 | 四轴；10 状态；双画法；商店；永不死亡 | ✅ |
| 9 | 双主题 | 首启/设置切换；语义色恒定；不重启；不重置 tab | ✅ |
| 10 | AI | BYOK DeepSeek；文字/照片；本地降级；JSON 校验 | ✅ |
| 11 | 备份 | 导出 JSON；导入覆盖；不含 API key | ✅ |
| 12 | 工程 | analyze 0 error；9 测试；Web 构建；浏览器冒烟 | ✅ |

### 1.2 v0.1 明确不做

| 不做 | 原因 |
|---|---|
| 账号 / 云同步 | 健康数据敏感；v1 先本地优先 |
| 条码扫描 | 相机/依赖成本；食物库先 curated |
| 端侧 CV | 包体/模型成本；先 BYOK |
| Rive 宠物 | 先用 CustomPainter 验证双皮管线 |
| Web 全功能对等 | IndexedDB/密钥限制；先查看+轻录入 |
| iOS/Linux 深度适配 | 人力；仅保证构建 |
| 跨周计划去重 | 需要历史窗口；v1.1 |
| 加密备份 | v1.1；先保证导得出/恢得回 |

---

## 2. 里程碑

### M0 调研与设计（完成）

- 6 份子代理调研：竞品、营养标准/评分、份量人因、宠物游戏化、Flutter 架构、数据可视化/双主题。
- 产出 `docs/PRODUCT_DESIGN.md`、`docs/research/*`。
- 关键决策：营养充足度而非减脂；区间优先；缺口驱动补丁餐；四轴宠物；双主题；BYOK。

### M1 骨架与领域层（完成）

- Flutter 3.44.3 工程，Android/Windows/Linux/Web 平台目录。
- 模型：Food/Entry/Profile/Preference/Plan/Pet/Score/Settings/AppData。
- Sembast 仓储、种子加载、设置、备份。
- 评分引擎、营养目标、健康规则、份量估算、计划求解、宠物状态、AI 服务。
- 共享组件、双主题 token、应用壳。

### M2 五条功能线（完成）

- 首启/首页/宠物/商店。
- 记录/搜索/份量/容器。
- 营养仪表盘/图表/周报/详情。
- 计划/条件/投喂。
- 档案/偏好/设置/AI/备份。
- 严格文件所有权，子代理并行；集成时修复共享层问题。

### M3 集成与验证（进行中）

- 全仓 `flutter analyze`：0 error。
- `flutter test`：9/9 通过。
- `flutter build web --release --no-web-resources-cdn`：通过。
- 浏览器冒烟：首启 → 记录 → 评分 → 计划 → 档案 → 双主题。
- ✅ Android release APK（3 ABI，16KB page 对齐）。
- ✅ Linux release。
- **待做**：Windows CI、真机触控/相机/文件选择、低端机冷启动。

### M4 数据与合规（待做）

- 食物库从 102 条扩到 300–500 条；逐条来源审计。
- 《中国食物成分表》授权/派生边界法务意见。
- 临床顾问评审：进食障碍、体重污名、慢病规则。
- 隐私政策/用户协议/免责声明定稿。

### M5 体验打磨（v1.1）

- 跨周计划去重、计划历史、剩菜复用。
- 月分与 30 天日历对齐。
- 宠物 Rive 皮肤管线；更多剧本。
- 加密备份/安全存储。
- 真机性能 profile：冷启动、图表、宠物帧率。

---

## 3. 工作分解（已完成项）

### 3.1 核心（主会话）

| 文件 | 内容 |
|---|---|
| `lib/core/models/*` | 全部模型 + JSON |
| `lib/core/db/*` | Sembast 条件工厂、仓储、种子、导出/导入 |
| `lib/core/scoring/*` | 16 项评分、守门、蒙特卡洛、周/月聚合 |
| `lib/core/portion/*` | 三档估算、容器、参照物 |
| `lib/core/health/*` | 10 种情况规则 |
| `lib/core/plan/*` | 补丁餐求解 |
| `lib/core/pet/*` | 四轴状态 |
| `lib/core/ai/*` | DeepSeek + 本地解析 |
| `lib/core/theme/*` | 28 token、双 ThemeData |
| `lib/core/state/*` | 数据、评分、宠物 providers |
| `lib/features/shell/*` | 底部导航 |

### 3.2 功能线 A：首启/首页/宠物

- `onboarding_page.dart`：两屏、实时双主题预览、跳过。
- `home_page.dart`：宠物舞台、分数卡、建议、时间线、快捷入口。
- `pet_painter.dart`：猫/狗、10 状态、双皮参数。
- `pet_stage.dart`：动画控制器、打盹、点击。
- `pet_shop_page.dart`：领养/切换。

### 3.3 功能线 B：记录/份量/容器

- `record_page.dart`：日期切换、概览、时间线、删除、编辑。
- `entry_composer.dart`：文字/拍照/搜索 → 解析 → 保存。
- `portion_sheet.dart`：L1/L2/L3。
- `food_search_page.dart`：搜索/最近/常吃。
- `container_calibration_page.dart`：容器 CRUD + 30 秒说明。
- `record_common.dart`：区间格式、历史中位数、重建条目。

### 3.4 功能线 C：营养

- `nutrition_page.dart`：日/周/月。
- `charts.dart`：环、瀑布、子弹、趋势+区间、热力、堆叠、雷达。
- `widgets.dart`：状态映射、资格门禁、钠归因、微营养、建议。
- `week_report_page.dart`、`score_detail_page.dart`。

### 3.5 功能线 D：计划

- `plan_page.dart`：摘要、空状态、分组、投喂、替换、重生成、规则卡。
- `plan_conditions_page.dart`：条件面板 + 3 秒预览。
- `plan_card.dart`、`plan_widgets.dart`。

### 3.6 功能线 E：档案/设置

- `profile_page.dart`、`health_profile_page.dart`、`preferences_page.dart`。
- `settings_page.dart`、`ai_settings_page.dart`、`backup_page.dart`。
- 设置组件、主题预览、关于弹层。

---

## 4. 验收记录

| 项 | 命令/方法 | 结果 |
|---|---|---|
| 静态检查 | `flutter analyze` | 0 error，2 info |
| 单测 | `flutter test` | 9/9 通过 |
| Web 构建 | `flutter build web --release --no-web-resources-cdn` | 通过 |
| Android 构建 | `flutter build apk --release --split-per-abi` | 3 个 APK；20.5/18.2/21.9 MB |
| Linux 构建 | `flutter build linux --release` | 通过 |
| 16KB page | `zipalign -c -P 16 -v 4` | 通过 |
| 浏览器冒烟 | Chrome + CDP，500×732 | 首启/记录/评分/计划/档案/主题全部通过 |
| 评分样例 | 牛奶 300 + 苹果 200 + 米饭 300 + 鸡胸 200 + 西兰花 200 + 米饭 200 + 苹果 200 | 70 分，区间 68–72，食物组 53/营养素 66/限制 100 |
| 计划样例 | 明天 3 餐，30 分钟/30 元/电磁炉+电饭煲 | 3 餐生成，理由/营养/步骤齐全 |
| 健康规则 | 勾选高血压 | 立即出现限制/推荐/需就医 3 条 |
| 备份 | 生成 JSON | 成功；不含 API key |

**未验证**：Windows build、真机相机/文件选择、低端机冷启动、Web 长期持久化。

---

## 5. 风险登记

| 风险 | 等级 | 当前缓解 | 下一步 |
|---|---|---|---|
| 食物成分表版权 | 高 | 只做 102 条派生；不展示原文；内部 source 字段 | 法务意见；扩到 300–500 条时逐条审计 |
| 估算误差被当成精确值 | 高 | 区间 UI、精度档、非承诺文案 | 用真实称重数据校准；上线后记 MAPE+bias |
| 进食障碍/体重污名 | 高 | 体型恒定、无死亡、无排行榜、周报为主 | 临床顾问 + 真实用户测试 |
| 医疗建议越界 | 高 | 四类规则、需就医、免责声明 | 营养师评审规则表 |
| API key 明文 | 中 | UI 提示、备份不含 key | secure storage / 加密 |
| Web 数据丢失 | 中 | 导出提醒 | OPFS 检测/警告；仅轻录入 |
| 跨周计划重复 | 中 | 单计划内去重 | 加 excludeRecipeIds/历史窗口 |
| 月分窗口 28 天 | 低 | UI 已注明 | 改为滚动 30 天或 4 周对齐 |
| Windows 未验证 | 中 | 平台目录已生成 | Windows runner/CI |
| 冷启动未实测 | 中 | 延迟初始化、轻依赖 | profile release 启动 |

---

## 6. 下一步（按优先级）

1. **Android release 构建**：`flutter build apk --release --split-per-abi`；检查 INTERNET 权限、16KB page、包体。
2. **Linux release + 真机触控/相机/文件选择**：跑一遍完整记录流程。
3. **Windows CI**：在 Windows runner 上 `flutter build windows --release`，钉 `windows-2022`。
4. **数据扩容**：102 → 300 条；补常见外卖/家常菜/调味品；逐条来源。
5. **评分校准**：用 50–100 次真实称重校准容器/参照物克重表；记录 MAPE + bias。
6. **临床/伦理评审**：宠物映射、减重/体重文案、慢病规则。
7. **v1.1**：跨周去重、安全存储、Rive、加密备份、月分对齐。

---

## 7. 变更记录

- 2026-10-26：v0.1 计划建立；M0–M2 完成；M3 集成验证：Web/Linux/Android 构建通过、16KB 对齐通过、浏览器冒烟通过；补应用图标、投喂吃播 sheet、tab 懒加载、周分基线；待 Windows/真机。
