#!/usr/bin/env bash
# 水晶傳說工具集 — 唯一入口：啟動 hub（一個 port 整合地圖維護／立繪切圖／火柴人動畫，自動開瀏覽器）。
# 用法：
#   ./tools/start.sh                         # 預設 port 8800、載入專案 map-def、匯出到執行目錄 exports/
#   ./tools/start.sh --port 9000 --no-open
#   ./tools/start.sh --map-def <path>        # 指定要載入的 map-def.json
#   ./tools/start.sh --out <dir>             # 立繪切圖匯出根目錄
cd "$(dirname "$0")/hub" || exit 1
exec python3 serve.py "$@"
