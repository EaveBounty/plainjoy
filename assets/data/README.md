# assets/data

这里只放**可公开**的食物库统计：

- `cn_food_manifest.json`：条数、字段覆盖率、已知缺失字段；不含具体食物数值。

全量成分表不在这里，也不随仓库分发；本地使用时放到 `assets/private/cn_food_full.json`
（已被 `.gitignore` 排除）。生成方式见 `tool/import_cfct.py` 与 `docs/DATA.md`。
