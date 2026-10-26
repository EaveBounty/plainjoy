# 隐私政策 / Privacy Policy

生效日期：2026-10-27
适用产品：有味清欢（Plainjoy）Android 应用及其附带构建

## 1. 谁在处理你的数据

长沙市果垂素宇工程设计有限公司（EaveBounty）
联系：通过 GitHub 组织 [@EaveBounty](https://github.com/EaveBounty) 发起 Issue。

## 2. 默认情况下收集什么

**不收集账号、手机号、通讯录、位置、设备标识符。**
以下数据仅保存在你的设备本地（Sembast 数据库 `plainjoy.db`）：

- 饮食记录（食物名、份量区间、餐次、时间）
- 健康档案（出生年、性别、身高、体重、活动量、病况、孕产、过敏原）
- 偏好评分与场景标签
- 宠物状态与积分
- AI 设置（Base URL、模型名、API key）

## 3. 数据会离开设备吗

只有一种情况：**你主动填写 API key 并开启 AI 功能后使用文字/照片识别**。

- 发送内容：当次输入的文字，或当次选择的照片；以及用于匹配的食物名候选。
- **不发送**：健康档案、历史记录、宠物数据、API key 以外的设置。
- 接收方：你配置的 AI 服务商（默认 `https://api.deepseek.com`，模型 `deepseek-flash`）。其隐私政策适用。
- 我们不运营中转服务器，不记录请求日志。
- 不开启 AI 时，全部解析在本地规则与本地食物库中完成。

## 4. 系统备份

Android 已关闭自动备份（`allowBackup=false`），并在 `dataExtractionRules` 中排除数据库，
避免健康数据被云备份或设备迁移带走。

## 5. 权限

- `INTERNET` / `ACCESS_NETWORK_STATE`：仅用于你主动发起的 AI 请求。
- 相机/相册：通过系统 Photo Picker 选择照片，不申请存储权限。
- 文件选择：用于备份导入/导出，通过系统文件选择器。

## 6. 保存期限与删除

- 数据保存在设备上，直到你删除记录、清除应用数据或卸载应用。
- 备份 JSON 由你自行保存；其中不含 API key。
- 我们无法远程删除你的数据，因为服务器端不持有这些数据。

## 7. 敏感个人信息

健康档案中的病况、孕产信息属于敏感个人信息。我们建议：

- 只在需要个性化建议时填写；
- 不使用 AI 功能时，数据不离开设备；
- 共用设备时使用系统多用户/应用锁。

## 8. 未成年人

本应用不面向 14 岁以下儿童。孕期/哺乳期功能仅面向成年人。

## 9. 医疗边界

有味清欢不是医疗器械，不提供诊断、处方或治疗方案。营养数值为估算，存在误差。
肾病、孕期、痛风急性期、贫血分型等情况请以医生或注册营养师意见为准。

## 10. 变更

政策变更会更新本文件日期，并在应用「关于」页标注。

---

# Privacy Policy (English summary)

Plainjoy stores all diet, health-profile, preference and pet data locally on your device.
No account, contact list, location or advertising identifier is collected.
Data leaves the device only when you explicitly enable AI with your own API key and submit a
text or photo; the request contains that input and food-name candidates, **not** your health
profile or history. The receiving provider is the endpoint you configure (default DeepSeek).
Android auto-backup is disabled and the database is excluded from device transfer.
The app is not a medical device and does not provide diagnosis or prescriptions.

Required Notice: Copyright 2026 长沙市果垂素宇工程设计有限公司 (https://github.com/EaveBounty/plainjoy)
