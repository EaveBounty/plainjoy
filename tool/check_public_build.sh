#!/usr/bin/env bash
# 公开分发的硬门禁：任何受版权保护的全量数据都不得进入仓库或产物。
set -euo pipefail
cd "$(dirname "$0")/.."

fail=0
say() { printf '%s\n' "$*"; }

say "== 1. 仓库文件 =="
if git rev-parse --git-dir >/dev/null 2>&1; then
  hits=$(git ls-files | grep -E 'cn_food_full|merged_.*\.json|\.venv/|key\.properties|keystore/' || true)
  if [ -n "$hits" ]; then
    say "FAIL: 以下受保护文件已被 git 跟踪："
    say "$hits"
    fail=1
  else
    say "ok: 无受保护文件被跟踪"
  fi
else
  say "skip: 尚未 git init"
fi

say "== 2. 私有数据是否存在于源码树 =="
if [ -f assets/private/cn_food_full.json ]; then
  say "note: 本地存在全量库（本地构建可用；公开构建前必须移走）"
else
  say "ok: 无全量库"
fi

say "== 3. 构建产物 =="
shopt -s nullglob
for apk in build/app/outputs/flutter-apk/*.apk; do
  if unzip -l "$apk" | grep -q 'assets/private/cn_food_full'; then
    say "FAIL: $apk 含全量数据"
    fail=1
  else
    say "ok: $(basename "$apk") 不含全量数据"
  fi
done
for web in build/web/assets/assets/private/cn_food_full.json; do
  if [ -f "$web" ]; then
    say "FAIL: build/web 含全量数据"
    fail=1
  fi
done

if [ "$fail" -ne 0 ]; then
  say "== 结果：不通过 =="
  exit 1
fi
say "== 结果：通过 =="
