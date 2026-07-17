#!/usr/bin/env bash
# gen-region 結構化測試：跑 region_generator.gd --dry-run，涵蓋 迷宮生成 + 出入口對接 +
# 連通性 assert + 自動選怪，但不寫檔（不污染 repo）。exit 0 = 全過。
# 用法：bash .claude/skills/gen-region/test.sh
cd "$(dirname "$0")/../../.." || exit 1   # → repo 根 godot-crystal-tales/
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
PROJ="$(pwd)/godot-project"
CFG="$(pwd)/.claude/skills/gen-region/examples/east_forest.json"
FILT="MCP|command handler|Command handler|WebSocket|port9080|EditorPlugin|DebugHooks"

OUT=$(timeout 120 "$GODOT" --headless -s res://scripts/map/region_generator.gd --path "$PROJ" -- "$CFG" --dry-run 2>&1)
echo "$OUT" | grep -vE "$FILT"
if echo "$OUT" | grep -q "not declared"; then
  echo "TEST FAIL：class 快取未建 —— 先跑 $GODOT --headless --import --path godot-project（到 exit 0）"; exit 1
fi
if echo "$OUT" | grep -q "連通性 assert 全過"; then
  echo "TEST PASS：迷宮生成 + 出入口對接 + 連通性 + 選怪 全過"
else
  echo "TEST FAIL：找不到連通性通過訊息"; exit 1
fi
