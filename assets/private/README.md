# assets/private（本地专用，不随公开仓库分发）

`cn_food_full.json` 放在这里，已被 `.gitignore` 排除。

- 本地构建：存在该文件时，app 自动合并 1677 条成分表；
- 公开构建/克隆：文件不存在，自动退回 `assets/seed/foods.json`（102 条），不会报错；
- **禁止**把该文件、含该文件的 APK/AAB/Web 产物上传到 GitHub Release、Actions artifact 或 Pages。

生成方式：`tool/import_cfct.py --input-dir <你的合法数据源目录>`。
